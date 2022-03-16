module unique_id (
		input  wire        clkin,      //  clkin.clk
		input  wire        reset,      //  reset.reset
		output wire        data_valid, // output.valid
		output wire [63:0] chip_id     //       .data
	);
endmodule

