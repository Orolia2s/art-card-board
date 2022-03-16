// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// $Id: //acds/main/ip/altera_voltage_sensor/control/altera_voltage_sensor_control.sv#4 $
// $Revision: #4 $
// $Date: 2016/01/02 $
// $Author: tgngo $

`timescale 1 ns / 1 ns

module  altera_jtag_block_access 
    #( 
        parameter DEVICE_FAMILY   = "Arria 10"
    ) (
    input           clkin,
    output  [63:0]  chip_id,
    output          data_valid,
    input           reset
    );

    // JTAG handling
    wire        ntrstcore;
    wire        tckcore;
    wire        corectl_jtag;
    wire        tmscore;
    wire        tdicore;
    wire        tdocore;

    wire        enable;
    wire        id_retrieve_done;
    wire [63:0] id_fuses;
    wire        tmgr_fuse_enable;
    wire        tmgr_cfg_vid_fuses_valid;
    wire reset_sync;
    // +-------------------------------------------------------
    // | Reset trigger: synchornize reset and trigger read ID
    // +-------------------------------------------------------
    altera_smartvid_reset_synchronizer i_reset_sync_25mhz (
        .reset_in_b (!reset),
        .clk (clkin),
        .reset_out_b (reset_sync)
    );

    reg reset_trigger;
    reg rff;
    reg reset_trigger_reg;
    reg reset_trigger_pulse;
    always_ff @(posedge clkin)
        begin
            if (!reset_sync)
                {reset_trigger, rff} <= 2'b11;
            else
                {reset_trigger, rff} <= {rff, 1'b0};
    end
    always_ff @(posedge clkin)
        begin
            if (!reset_sync)
                reset_trigger_reg <= 1'b0;
            else
                reset_trigger_reg <= reset_trigger;
    end
    assign reset_trigger_pulse = !reset_trigger && reset_trigger_reg;
    assign enable = reset_trigger_pulse;
    
    reg enable_sync_int;
    reg enable_sync;
    // double sync input signals
    always @ (posedge clkin) begin
        if (!reset_sync) begin
                enable_sync_int <= 1'b0;
                enable_sync      <= 1'b0;
        end else begin
                enable_sync_int <= enable;
                enable_sync     <= enable_sync_int;
        end
    end

    // +-------------------------------------------------------
    // | Output mapping
    // +-------------------------------------------------------
    assign chip_id      = id_fuses;
    assign data_valid   = tmgr_cfg_vid_fuses_valid;

    // +-------------------------------------------------------
    // | SM control jtag reading
    // +-------------------------------------------------------
    altera_uid_ctl_tmgr task_manager (
        .vid_clk(clkin),
        .vid_rst_sync_b(reset_sync),

        // Input from VID controller configuration registers
        .cfg_vid_op_start(enable_sync),
        .fuse_tmgr_retrieve_done(id_retrieve_done),

        // Outputs
        .tmgr_fuse_enable(tmgr_fuse_enable),
        .tmgr_vid_fuses_valid(tmgr_cfg_vid_fuses_valid)
    );

    // +-------------------------------------------------------
    // | Chip ID fuses handling
    // +-------------------------------------------------------
    altera_uid_ctl_fuse fuse_handling (
        //.jtag_clk(jtag_core_clk),
        //.vid_rst_jtagclk_sync_b(vid_jtag_rst_b),
        .jtag_clk                  (clkin),
        .vid_rst_jtagclk_sync_b    (reset_sync),
        .tmgr_fuse_enable          (tmgr_fuse_enable),
        .fuse_tmgr_retrieve_done   (id_retrieve_done),
        .vid_fuses                 (id_fuses),
    
        .tdocore                   (tdocore),
        .ntrstcore                 (ntrstcore),
        .tckcore                   (tckcore),
        .corectl_jtag              (corectl_jtag),
        .tmscore                   (tmscore),
        .tdicore                   (tdicore)
    );

    // +-------------------------------------------------------
    // | JTAG Atom
    // +-------------------------------------------------------
    jtag 
    # (
        .DEVICE_FAMILY  (DEVICE_FAMILY)
        ) jtag_inst (
        .corectl                    (corectl_jtag),
        .tmscore                    (tmscore),
        .tckcore                    (tckcore),
        .tdicore                    (tdicore),
        .ntrstcore                  (ntrstcore),
        .tdocore                    (tdocore)
    );

endmodule //altchip_id


// +-------------------------------------------------------
// | Sub components
// +-------------------------------------------------------

module altera_uid_ctl_fuse (
        input           jtag_clk,
        input           vid_rst_jtagclk_sync_b,
        input           tmgr_fuse_enable,
        output          fuse_tmgr_retrieve_done,
        //output [37:0]   vid_fuses,
        output [63:0]   vid_fuses,

        //JTAG interface
        input           tdocore,
        output          ntrstcore,
        output          tckcore,
        output          corectl_jtag,
        output          tmscore,
        output          tdicore
);

reg [4:0]  state, next;
reg        first_dr_loop_done_flag;
reg        bypass_instruct_flag;
reg        tmgr_fuse_enable_sync;
reg        tmgr_fuse_enable_sync_int;
reg [5:0]  jtag_timer;
reg [9:0]  jtag_fuse_instruction;
reg [63:0]  jtag_fuse_address;
reg [63:0] vid_fuse_reg;

reg fuse_tmgr_retrieve_done_reg;
reg tmscore_reg;
reg tdicore_reg;
reg corectl_jtag_reg;
reg tckcore_en;

//timer
wire [5:0] jtag_timer_count;
wire       jtag_timer_load;
wire       jtag_timer_enable;
wire       jtag_timer_expired;

//Outputs
assign fuse_tmgr_retrieve_done = fuse_tmgr_retrieve_done_reg;
//assign vid_fuses = vid_fuse_reg[37:0];
assign vid_fuses = vid_fuse_reg;

//Outputs to JTAG interface
assign corectl_jtag = corectl_jtag_reg;
assign tmscore = tmscore_reg;
assign tdicore = tdicore_reg;
assign ntrstcore = 1'b1;

//serial tdo
wire jtag_fuse_instruction_out;
wire jtag_fuse_address_out;

//FUSE FSM States:
localparam [4:0] FUSERST        = 5'h00;
localparam [4:0] ON_FIREWALL    = 5'h01;
localparam [4:0] UNGATE_TCK     = 5'h02;
localparam [4:0] RST_TAP        = 5'h03;
localparam [4:0] RUN_IDLE       = 5'h04;
localparam [4:0] SEL_DR_1       = 5'h05;
localparam [4:0] SEL_IR         = 5'h06;
localparam [4:0] CAP_IR         = 5'h07;
localparam [4:0] SHIFT_IR       = 5'h08;
localparam [4:0] EXIT1_IR       = 5'h09;
localparam [4:0] PAUSE_IR       = 5'h0A;
localparam [4:0] EXIT2_IR       = 5'h0B;
localparam [4:0] UPDATE_IR      = 5'h0C;
localparam [4:0] IR_DONE        = 5'h0D;
localparam [4:0] SEL_DR_0       = 5'h0E;
localparam [4:0] CAP_DR         = 5'h0F;
localparam [4:0] SHIFT_DR       = 5'h10;
localparam [4:0] EXIT1_DR       = 5'h11;
localparam [4:0] PAUSE_DR       = 5'h12;
localparam [4:0] EXIT2_DR       = 5'h13;
localparam [4:0] UPDATE_DR      = 5'h14;
localparam [4:0] DONE           = 5'h15;
localparam [4:0] GATE_TCK       = 5'h16;
localparam [4:0] OFF_FIREWALL   = 5'h17;
localparam [4:0] HANDSHAKE      = 5'h18;

// double sync input signals
always @ (posedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) begin
                tmgr_fuse_enable_sync_int <= 1'b0;
                tmgr_fuse_enable_sync      <= 1'b0;
        end else begin
                tmgr_fuse_enable_sync_int <= tmgr_fuse_enable;
                tmgr_fuse_enable_sync     <= tmgr_fuse_enable_sync_int;
        end
end

// FUSE FSM arc transitions
wire arc_fuserst_on_firewall;
wire arc_on_firewall_ungate_tck;
wire arc_ungate_tck_rst_tap;
wire arc_rst_tap_run_idle;
wire arc_cap_ir_shift_ir;
wire arc_update_ir_ir_done;
wire arc_cap_dr_shift_dr;
wire arc_update_dr_ir_done;
wire arc_update_dr_run_idle;
wire arc_done_gate_tck;
wire arc_gate_tck_off_firewall;
wire arc_off_firewall_handshake;

assign arc_fuserst_on_firewall          = state == FUSERST      & next == ON_FIREWALL;
assign arc_on_firewall_ungate_tck       = state == ON_FIREWALL  & next == UNGATE_TCK ;
assign arc_ungate_tck_rst_tap           = state == UNGATE_TCK   & next == RST_TAP  ;
assign arc_rst_tap_run_idle             = state == RST_TAP      & next == RUN_IDLE ;
assign arc_cap_ir_shift_ir              = state == CAP_IR       & next == SHIFT_IR ;
assign arc_update_ir_ir_done            = state == UPDATE_IR    & next == IR_DONE  ;
assign arc_cap_dr_shift_dr              = state == CAP_DR       & next == SHIFT_DR ;
assign arc_update_dr_ir_done            = state == UPDATE_DR    & next == IR_DONE;
assign arc_update_dr_run_idle           = state == UPDATE_DR    & next == RUN_IDLE;
assign arc_done_gate_tck                = state == DONE         & next == GATE_TCK;
assign arc_gate_tck_off_firewall        = state == GATE_TCK     & next == OFF_FIREWALL;
assign arc_off_firewall_handshake       = state == OFF_FIREWALL & next == HANDSHAKE;

// FUSE FSM State Machines
always @ (posedge jtag_clk) 
        if (!vid_rst_jtagclk_sync_b)    state   <= FUSERST;
        else                            state   <= next;
        
always @* begin        
        next = state;        
        case (state)
                FUSERST:        if (tmgr_fuse_enable_sync)      next = ON_FIREWALL;
                                else                            next = FUSERST;  
                ON_FIREWALL:    if (jtag_timer_expired)         next = UNGATE_TCK;
                                else                            next = ON_FIREWALL;
                UNGATE_TCK:     if (jtag_timer_expired)         next = RST_TAP;
                                else                            next = UNGATE_TCK;
                RST_TAP:        if (jtag_timer_expired)         next = RUN_IDLE;
                                else                            next = RST_TAP;
                RUN_IDLE:       if (jtag_timer_expired)         next = SEL_DR_1;
                                else                            next = RUN_IDLE;
                SEL_DR_1:                                       next = SEL_IR;
                SEL_IR:                                         next = CAP_IR;
                CAP_IR:                                         next = SHIFT_IR;
                SHIFT_IR:       if (jtag_timer_expired)         next = EXIT1_IR;       //for the first loop, shift in fuse read command
                                else                            next = SHIFT_IR;
                EXIT1_IR:                                       next = PAUSE_IR;
                PAUSE_IR:                                       next = EXIT2_IR;
                EXIT2_IR:                                       next = UPDATE_IR;
                UPDATE_IR:                                      next = IR_DONE;
                IR_DONE:        if (jtag_timer_expired)         next = SEL_DR_0;
                                else                            next = IR_DONE;
                SEL_DR_0:                                       next = CAP_DR;
                CAP_DR:                                         next = SHIFT_DR;
                SHIFT_DR:       if (jtag_timer_expired)         next = EXIT1_DR;
                                else                            next = SHIFT_DR;
                EXIT1_DR:                                       next = PAUSE_DR;
                PAUSE_DR:                                       next = EXIT2_DR;
                EXIT2_DR:                                       next = UPDATE_DR;
                UPDATE_DR:      if      (~first_dr_loop_done_flag & ~bypass_instruct_flag ) next = IR_DONE;  //sequence to capture VID fuse values
                                else if ( first_dr_loop_done_flag & ~bypass_instruct_flag ) next = RUN_IDLE; //sequence to end fuse read command
                                else if ( first_dr_loop_done_flag & bypass_instruct_flag ) next = DONE;     //complete fuse read
                DONE:                                           next = GATE_TCK;
                GATE_TCK:       if (jtag_timer_expired)         next = OFF_FIREWALL;
                                else                            next = GATE_TCK;   
                OFF_FIREWALL:   if (jtag_timer_expired)         next = HANDSHAKE;
                                else                            next = OFF_FIREWALL;
                HANDSHAKE:      if (!tmgr_fuse_enable_sync | !vid_rst_jtagclk_sync_b)   next = FUSERST;
                                else                            next = HANDSHAKE;    
        endcase
end


// FSM state machine registered outputs

always @ (posedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) 
                corectl_jtag_reg        <= 1'b0;
        else if (arc_gate_tck_off_firewall)
                corectl_jtag_reg        <= 1'b0;
        else 
                corectl_jtag_reg        <= corectl_jtag_reg | arc_fuserst_on_firewall;
end 

// the reset of the logics are synchronous reset
always @ (posedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) begin
                fuse_tmgr_retrieve_done_reg <= 1'b0;
                first_dr_loop_done_flag <= 1'b0;
                bypass_instruct_flag    <= 1'b0;
                
        end
        else begin
                fuse_tmgr_retrieve_done_reg     <= arc_off_firewall_handshake | next == HANDSHAKE; 
                first_dr_loop_done_flag         <= arc_update_dr_ir_done | first_dr_loop_done_flag;
                bypass_instruct_flag            <= arc_update_dr_run_idle | bypass_instruct_flag;

                


        end
end

always @ (negedge jtag_clk) begin
    if (!vid_rst_jtagclk_sync_b) 
        tmscore_reg             <= 1'b0;
    else
        tmscore_reg             <= next == RST_TAP | next == SEL_DR_0 | next == SEL_DR_1 | next == SEL_IR | next == EXIT1_IR | next == EXIT2_IR | next == UPDATE_IR | next == EXIT1_DR | next == EXIT2_DR | next == UPDATE_DR;
end 

// Timer block

assign jtag_timer_count =       (~bypass_instruct_flag & arc_cap_dr_shift_dr ) ? 6'b111111 :
                                (arc_cap_ir_shift_ir) ? 6'b001001 :
                                (arc_fuserst_on_firewall | arc_on_firewall_ungate_tck | arc_ungate_tck_rst_tap | arc_done_gate_tck | arc_gate_tck_off_firewall) ? 6'b000100 :
                                6'b000010;

assign jtag_timer_enable = ~jtag_timer_expired & (state == IR_DONE | state == RUN_IDLE | state == ON_FIREWALL | state == UNGATE_TCK | state == RST_TAP | state == GATE_TCK | state == OFF_FIREWALL | state == SHIFT_IR | state == SHIFT_DR);

assign jtag_timer_load = arc_update_dr_ir_done | arc_rst_tap_run_idle | arc_update_ir_ir_done | arc_update_dr_run_idle | arc_fuserst_on_firewall | arc_on_firewall_ungate_tck | arc_ungate_tck_rst_tap | arc_done_gate_tck | arc_gate_tck_off_firewall | arc_cap_dr_shift_dr | arc_cap_ir_shift_ir;

assign jtag_timer_expired = jtag_timer == 6'b000000;

always @ (posedge jtag_clk) begin
        if (~vid_rst_jtagclk_sync_b) 
                jtag_timer <= 6'b000000;
        else begin
                if (jtag_timer_load)            jtag_timer <= jtag_timer_count;
                else if (jtag_timer_enable)     jtag_timer <= jtag_timer - 1'b1;
                else                            jtag_timer <= 6'b111111;
        end
end

//TDICORE output
always @ (posedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) begin
                jtag_fuse_address       <= 64'h0000000000000000;
                jtag_fuse_instruction   <= 10'b0000000000;
        end
        else begin
                //address 
                //if (arc_cap_dr_shift_dr) jtag_fuse_address <= 64'h0000000000000007;
                // CHip ID address
                if (arc_cap_dr_shift_dr) jtag_fuse_address <= 64'h0000000000000004;
                else                     jtag_fuse_address <= {jtag_fuse_address[62:0], 1'b0};

                if (arc_cap_ir_shift_ir) begin
                        if (bypass_instruct_flag) jtag_fuse_instruction <= 10'b1111111111;
                        else                      jtag_fuse_instruction <= 10'b0100010010;
                end else
                        jtag_fuse_instruction <= {1'b0, jtag_fuse_instruction[9:1]};
        end
end

assign jtag_fuse_address_out = jtag_fuse_address[63];
assign jtag_fuse_instruction_out = jtag_fuse_instruction[0];

always @ (negedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) tdicore_reg <= 1'b0;
        else begin
                tdicore_reg <=  !(state == SHIFT_IR | SHIFT_DR) ? 1'b0 :
                                state == SHIFT_DR               ? jtag_fuse_address_out :
                                jtag_fuse_instruction_out;
        end
end

//tdocore to vid fuse
always @ (negedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) vid_fuse_reg        <= 64'b0;
        else begin
                if ( first_dr_loop_done_flag & ~bypass_instruct_flag & ((state == SHIFT_DR & (jtag_timer != 6'b111111 | jtag_timer != 6'b111110)) | state == EXIT1_DR)) 
                        vid_fuse_reg <= {vid_fuse_reg[62:0], tdocore};
                else
                        vid_fuse_reg <= vid_fuse_reg;
        end
end

//tckcore clk enable
always @ (negedge jtag_clk) begin
        if (!vid_rst_jtagclk_sync_b) tckcore_en <= 1'b0;
        else 
                tckcore_en <= (state != FUSERST & state != ON_FIREWALL & state != HANDSHAKE & state != OFF_FIREWALL) & ~((state == UNGATE_TCK && jtag_timer > 6'b000010) | (state == GATE_TCK && jtag_timer < 6'b000011));         
end

assign tckcore = tckcore_en & jtag_clk;

endmodule


module altera_uid_ctl_tmgr ( 

  // Clock
  input wire        vid_clk,  
  
  // Reset
  input wire        vid_rst_sync_b,
  
  // Input from VID controller configuration registers
  input wire        cfg_vid_op_start,
  input wire        fuse_tmgr_retrieve_done,
  
  // Output 
  output wire       tmgr_fuse_enable,
    output wire       tmgr_vid_fuses_valid
  );
  
  reg       fuses_retrieve_done_ff0;
  reg       fuses_retrieve_done_ff1;
  reg       fuses_retrive_done_sync;
  reg       vid_fuses_valid;
  reg       fuse_enable, n_fuse_enable;
  
  reg [2:0] state, n_state;
    
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] INIT = 3'b001;
  localparam [2:0] SVS  = 3'b010;
  localparam [2:0] AVS  = 3'b011;
  
  assign tmgr_fuse_enable = fuse_enable;
  assign tmgr_vid_fuses_valid = vid_fuses_valid;
  
  always @(posedge vid_clk) begin
    if (!vid_rst_sync_b) begin
      state         <= IDLE;
      fuse_enable       <= 1'b0;
      vid_fuses_valid       <= 1'b0;
      fuses_retrieve_done_ff0   <= 1'b0;
      fuses_retrive_done_sync   <= 1'b0;
      fuses_retrieve_done_ff1   <= 1'b0;
    end
    else begin
      state             <= n_state;
      fuse_enable       <= n_fuse_enable;
        
      // generate fuses_retrieve_done_sync
      fuses_retrieve_done_ff0 <= fuse_tmgr_retrieve_done;
      fuses_retrive_done_sync <= fuses_retrieve_done_ff0;
      fuses_retrieve_done_ff1 <= fuses_retrive_done_sync;
      
      vid_fuses_valid <= (fuses_retrive_done_sync & ~fuses_retrieve_done_ff1) | vid_fuses_valid;
      
    end // end if
  end  // end always
  
  always @ (*)
  begin
    n_fuse_enable = fuse_enable;
    
    case (state)
    IDLE:   begin
              if (vid_rst_sync_b & cfg_vid_op_start & ~fuses_retrive_done_sync) begin
                n_fuse_enable = 1'b1;
                n_state = INIT;
              end
              else
                n_state = IDLE;
            end
            
    INIT:   begin
              if (fuses_retrive_done_sync) begin
                n_fuse_enable = 1'b0;
                n_state = IDLE;
              end
              else 
                n_state = INIT;
            end
           
    default:    n_state = IDLE;
    endcase
  end
   
endmodule 


// Arria 10 Jtag atom
module jtag 
# (
    parameter DEVICE_FAMILY = "Arria 10"
)
(
  input wire corectl,
  input wire tmscore,
  input wire tckcore,
  input wire tdicore,
  input wire ntrstcore,
  output wire tdocore
);

    generate
        if (DEVICE_FAMILY == "Arria 10") begin
            twentynm_jtagblock jtag
                (
                 .corectl(corectl),
                 .tmscore(tmscore),
                 .tckcore(tckcore),
                 .tdicore(tdicore),
                 .ntrstcore(ntrstcore),
                 .tdocore(tdocore)
                 );
        end else begin // Cyclone 10 GX
            cyclone10gx_jtagblock jtag
                (
                 .corectl(corectl),
                 .tmscore(tmscore),
                 .tckcore(tckcore),
                 .tdicore(tdicore),
                 .ntrstcore(ntrstcore),
                 .tdocore(tdocore)
                 );
        end
    endgenerate
  
 endmodule 


module altera_smartvid_reset_synchronizer
#(
    parameter DEPTH       = 2
)
(
    input   reset_in_b,

    input   clk,
    output  reset_out_b
);

    // -----------------------------------------------
    // Synchronizer register chain. We cannot reuse the
    // standard synchronizer in this implementation 
    // because our timing constraints are different.
    //
    // Instead of cutting the timing path to the d-input 
    // on the first flop we need to cut the aclr input.
    // 
    // We omit the "preserve" attribute on the final
    // output register, so that the synthesis tool can
    // duplicate it where needed.
    // -----------------------------------------------
    // Please check the false paths setting in altera_smartvid SDC
    
    (*preserve*) reg [DEPTH-1:0] altera_smartvid_reset_synchronizer_chain;
    reg altera_smartvid_reset_synchronizer_chain_out;

    // -----------------------------------------------
    // Assert asynchronously, deassert synchronously.
    // -----------------------------------------------
    always @(posedge clk or negedge reset_in_b) begin
        if (!reset_in_b) begin
            altera_smartvid_reset_synchronizer_chain <= {DEPTH{1'b0}};
            altera_smartvid_reset_synchronizer_chain_out <= 1'b0;
        end
        else begin
            altera_smartvid_reset_synchronizer_chain[DEPTH-2:0] <= altera_smartvid_reset_synchronizer_chain[DEPTH-1:1];
            altera_smartvid_reset_synchronizer_chain[DEPTH-1] <= 1'b1;
            altera_smartvid_reset_synchronizer_chain_out <= altera_smartvid_reset_synchronizer_chain[0];
        end
    end

    assign reset_out_b = altera_smartvid_reset_synchronizer_chain_out;

endmodule
