
// synopsys translate_off
`include "timescale.v"
// synopsys translate_on


module avalon_uart_top	(
    input  avc_c1_clk,
    input  avc_c1_reset,
    input  [2:0] avs_s1_address,
    input  [31:0] avs_s1_writedata,
    input  avs_s1_write,
    input  avs_s1_read,
    input  avs_s1_chipselect,
    output  avs_s1_waitrequest_n,
    output [31:0] avs_s1_readdata,
    output avi_int_irq,
    
    // export signals UART
    input 			srx_pad_i,
    output 			stx_pad_o,
    output 			rts_pad_o,
    input 			cts_pad_i,
    output 			dtr_pad_o,
    input 			dsr_pad_i,
    input 			ri_pad_i,
    input 			dcd_pad_i

       );
   uart_top	the_uart_top(
	.wb_clk_i(avc_c1_clk),

	// Wishbone signals
	.wb_rst_i (avc_c1_reset),
    .wb_adr_i (avs_s1_address),
    .wb_dat_i (avs_s1_writedata[7:0]),
    .wb_dat_o (avs_s1_readdata),
    .wb_we_i (avs_s1_write),
    .wb_stb_i (avs_s1_chipselect),
    .wb_cyc_i (avs_s1_chipselect),
    .wb_ack_o (avs_s1_waitrequest_n),
    .wb_sel_i (4'b0),
	.int_o (avi_int_irq), // interrupt request

	// UART	signals
	// serial input/output
	.stx_pad_o (stx_pad_o),
    .srx_pad_i (srx_pad_i),

	// modem signals
	.rts_pad_o (rts_pad_o),
    .cts_pad_i (cts_pad_i),
    .dtr_pad_o (dtr_pad_o),
    .dsr_pad_i (dsr_pad_i),
    .ri_pad_i (ri_pad_i),
    .dcd_pad_i (dcd_pad_i)

	);
 
 assign avs_s1_readdata[31:8] = 24'b0;
endmodule


