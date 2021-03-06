# TCL File Generated by Component Editor 21.1
# Tue May 25 15:06:20 CEST 2021
# DO NOT MODIFY


# 
# mRO50 "mRO50" v1.0
#  2021.05.25.15:06:20
# 
# 

# 
# request TCL package from ACDS 21.1
# 
package require -exact qsys 21.1


# 
# module mRO50
# 
set_module_property DESCRIPTION ""
set_module_property NAME mRO50
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP Orolia
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME mRO50
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property LOAD_ELABORATION_LIMIT 0


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL mro50
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE true
add_fileset_file mro50.vhd VHDL PATH mro50.vhd TOP_LEVEL_FILE
add_fileset_file uart_rx.vhd VHDL PATH uart_rx.vhd
add_fileset_file uart_tx.vhd VHDL PATH uart_tx.vhd


# 
# parameters
# 
add_parameter g_freq_in INTEGER 100000000
set_parameter_property g_freq_in DEFAULT_VALUE 100000000
set_parameter_property g_freq_in DISPLAY_NAME g_freq_in
set_parameter_property g_freq_in UNITS None
set_parameter_property g_freq_in ALLOWED_RANGES -2147483648:2147483647
set_parameter_property g_freq_in AFFECTS_GENERATION false
set_parameter_property g_freq_in HDL_PARAMETER true


# 
# display items
# 


# 
# connection point avalon_slave_0
# 
add_interface avalon_slave_0 avalon end
set_interface_property avalon_slave_0 addressGroup 0
set_interface_property avalon_slave_0 addressUnits WORDS
set_interface_property avalon_slave_0 associatedClock clock_sink
set_interface_property avalon_slave_0 associatedReset reset_sink
set_interface_property avalon_slave_0 bitsPerSymbol 8
set_interface_property avalon_slave_0 bridgedAddressOffset ""
set_interface_property avalon_slave_0 bridgesToMaster ""
set_interface_property avalon_slave_0 burstOnBurstBoundariesOnly false
set_interface_property avalon_slave_0 burstcountUnits WORDS
set_interface_property avalon_slave_0 explicitAddressSpan 0
set_interface_property avalon_slave_0 holdTime 0
set_interface_property avalon_slave_0 linewrapBursts false
set_interface_property avalon_slave_0 maximumPendingReadTransactions 0
set_interface_property avalon_slave_0 maximumPendingWriteTransactions 0
set_interface_property avalon_slave_0 minimumResponseLatency 1
set_interface_property avalon_slave_0 readLatency 0
set_interface_property avalon_slave_0 readWaitTime 1
set_interface_property avalon_slave_0 setupTime 0
set_interface_property avalon_slave_0 timingUnits Cycles
set_interface_property avalon_slave_0 transparentBridge false
set_interface_property avalon_slave_0 waitrequestAllowance 0
set_interface_property avalon_slave_0 writeWaitTime 0
set_interface_property avalon_slave_0 ENABLED true
set_interface_property avalon_slave_0 EXPORT_OF ""
set_interface_property avalon_slave_0 PORT_NAME_MAP ""
set_interface_property avalon_slave_0 CMSIS_SVD_VARIABLES ""
set_interface_property avalon_slave_0 SVD_ADDRESS_GROUP ""
set_interface_property avalon_slave_0 IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port avalon_slave_0 ADDR_I address Input 8
add_interface_port avalon_slave_0 DATA_I writedata Input 32
add_interface_port avalon_slave_0 DATA_O readdata Output 32
add_interface_port avalon_slave_0 WR_I write Input 1
add_interface_port avalon_slave_0 RD_I read Input 1
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isFlash 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avalon_slave_0 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point serial
# 
add_interface serial conduit end
set_interface_property serial associatedClock ""
set_interface_property serial associatedReset ""
set_interface_property serial ENABLED true
set_interface_property serial EXPORT_OF ""
set_interface_property serial PORT_NAME_MAP ""
set_interface_property serial CMSIS_SVD_VARIABLES ""
set_interface_property serial SVD_ADDRESS_GROUP ""
set_interface_property serial IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port serial MRO_RX mro_rx Input 1
add_interface_port serial MRO_TX mro_tx Output 1
add_interface_port serial MRO_ERROR mro_error Output 1


# 
# connection point clock_sink
# 
add_interface clock_sink clock end
set_interface_property clock_sink ENABLED true
set_interface_property clock_sink EXPORT_OF ""
set_interface_property clock_sink PORT_NAME_MAP ""
set_interface_property clock_sink CMSIS_SVD_VARIABLES ""
set_interface_property clock_sink SVD_ADDRESS_GROUP ""
set_interface_property clock_sink IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port clock_sink CLK_I clk Input 1


# 
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock_sink
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""
set_interface_property reset_sink IPXACT_REGISTER_MAP_VARIABLES ""

add_interface_port reset_sink RST_I reset Input 1

