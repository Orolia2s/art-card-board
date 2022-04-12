# ART_CARD BOARD CONSTRAINT TIMING FILE

# Clock constraints
create_clock -name clk_osc   -period 100.000ns [get_ports {CLK_OSC}]
create_clock -name clk_25m   -period  40.000ns [get_ports {CLK_25M}]
create_clock -name PCIE_CLK_REF -period 10.000 -waveform {0.000 5.000} PCIE_CLK_REF
create_clock -name flash_clk -period 10.000 {u0|spi_flash|spi_1|SCLK_reg}

#**************************************************************
# Create Generated Clock
#**************************************************************
create_generated_clock -name clk_200m     -source {u0|pll_osc_200m|iopll_0|altera_iopll_i|c10gx_pll|iopll_inst|refclk[0]} -divide_by 3  -multiply_by 60 -duty_cycle 50.00 {u0|pll_osc_200m|iopll_0|altera_iopll_i|c10gx_pll|iopll_inst|outclk[0]}
create_generated_clock -name clkpll_50m   -source {u0|pll_50m|pll_50m|altera_iopll_i|c10gx_pll|iopll_inst|refclk[0]}      -divide_by 12 -multiply_by 6  -duty_cycle 50.00 {u0|pll_50m|pll_50m|altera_iopll_i|c10gx_pll|iopll_inst|outclk[0]}
create_generated_clock -name clkpll_25m   -source {u0|pll_50m|pll_50m|altera_iopll_i|c10gx_pll|iopll_inst|refclk[0]}      -divide_by 24 -multiply_by 6  -duty_cycle 50.00 {u0|pll_50m|pll_50m|altera_iopll_i|c10gx_pll|iopll_inst|outclk[1]}

derive_pll_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# change domain
set_false_path -from [get_clocks {u0|pcie_endpoint|wys~CORE_CLK_OUT}] -to [get_clocks {clk_200m}]
set_false_path -from [get_clocks {u0|pcie_endpoint|wys~CORE_CLK_OUT}] -to [get_clocks {clkpll_50m}]
set_false_path -from [get_clocks {clk_200m}]   -to [get_clocks {u0|pcie_endpoint|wys~CORE_CLK_OUT}]
set_false_path -from [get_clocks {clkpll_50m}] -to [get_clocks {u0|pcie_endpoint|wys~CORE_CLK_OUT}]
set_false_path -from [get_clocks {flash_clk}]  -to [get_clocks {u0|pcie_endpoint|wys~CORE_CLK_OUT}]

# False path on output I/O
set_false_path -from * -to [get_ports {OSC_SDA OSC_SCL}]
set_false_path -from * -to [get_ports {EEPROM_SDA EEPROM_SCL}]
set_false_path -from * -to [get_ports {DAC_CLK DAC_CSN DAC_MOSI}]
set_false_path -from * -to [get_ports {UART_GNSS_TX UART_OSC_TX}]
set_false_path -from * -to [get_ports {DCLS_OUT*}]
set_false_path -from * -to [get_ports {GPIO*}]
set_false_path -from * -to [get_ports {LED*}]
set_false_path -from * -to [get_ports {SEL_IO*}]

# False path on input I/O
set_false_path -from [get_ports {ID* }] -to *
set_false_path -from [get_ports {OSC_ID* }] -to *
set_false_path -from [get_ports {GPIO* }] -to *
set_false_path -from [get_ports {DCLS_IN* }] -to *
set_false_path -from [get_ports {OSC_SDA OSC_SCL}] -to *
set_false_path -from [get_ports {EEPROM_SDA EEPROM_SCL}] -to *
set_false_path -from [get_ports {OSC_PPS_OUT OSC_BITE GNSS_PPS }] -to *
set_false_path -from [get_ports {PCIE_WAKEn }] -to *
set_false_path -from [get_ports {PCIE_PIN_PERSTn }] -to *
set_false_path -from [get_ports {UART_GNSS_RX UART_OSC_RX }] -to *

# False path on JTAG
set_false_path -from * -to [get_ports {altera_reserved_tdo}]
set_false_path -from [get_ports {altera_reserved_tdi altera_reserved_tms}] -to *
