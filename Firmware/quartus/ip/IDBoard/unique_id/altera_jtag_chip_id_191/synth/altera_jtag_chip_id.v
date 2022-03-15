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



// synthesis VERILOG_INPUT_VERSION VERILOG_2001
`timescale 1 ns / 1 ns

module  altera_jtag_chip_id
	( 
	clkin,
	chip_id,
	data_valid,
	reset);
	
	parameter DEVICE_FAMILY   = "Arria 10";

	input	clkin;
	output	[63:0]	chip_id;
	output	data_valid;
	input	reset;
	
	altera_jtag_block_access 
	#(
        .DEVICE_FAMILY  (DEVICE_FAMILY)
    ) altchip_id_jtag_inst( 
		.clkin 			(clkin),
		.chip_id 		(chip_id),
		.data_valid 	(data_valid),
		.reset 			(reset)
	);
		
endmodule //altchip_id
//VALID FILE
