	unique_id u0 (
		.clkin      (_connected_to_clkin_),      //   input,   width = 1,  clkin.clk
		.reset      (_connected_to_reset_),      //   input,   width = 1,  reset.reset
		.data_valid (_connected_to_data_valid_), //  output,   width = 1, output.valid
		.chip_id    (_connected_to_chip_id_)     //  output,  width = 64,       .data
	);

