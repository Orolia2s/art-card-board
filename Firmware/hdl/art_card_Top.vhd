--------------------------------------------------------------------------------
--
-- art_card_Top : Top level of the ART_CARD FGPA.
-- Copyright (C) 2021  Spectracom SAS
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL;

entity art_card_Top is
    port
    (
        CLK_25M         : in    std_logic;
        CLK_OSC         : in    std_logic;
        PCIE_CLK_REF    : in    std_logic;
        PCIE_PIN_PERSTn : in    std_logic;
        PCIE_WAKEn      : in    std_logic;
        PCIE_TX         : out   std_logic_vector(3 downto 0);
        PCIE_RX         : in    std_logic_vector(3 downto 0);
        UART_OSC_TX     : out   std_logic;
        UART_OSC_RX     : in    std_logic;
        UART_GNSS_TX    : out   std_logic;
        UART_GNSS_RX    : in    std_logic;
        GNSS_PPS        : in    std_logic;
        LED             : out   std_logic_vector(3 downto 0);
        DAC_CLK         : out   std_logic;
        DAC_MOSI        : out   std_logic;
        DAC_CSN         : out   std_logic;
        OSC_PPS_OUT     : in    std_logic;
        OSC_PPS_IN      : out   std_logic;
        OSC_BITE        : in    std_logic;
        OSC_SDA         : inout std_logic;
        OSC_SCL         : inout std_logic;
        DCLS_IN         : in    std_logic_vector(3 downto 0);
        DCLS_OUT        : out   std_logic_vector(3 downto 0);
        SEL_IO          : out   std_logic_vector(5 downto 0);
        FREQ_IN         : in    std_logic;
        GPIO            : inout std_logic_vector(3 downto 0);
        ID              : in    std_logic_vector(3 downto 0);
        OSC_ID          : in    std_logic_vector(3 downto 0);
        EEPROM_SCL      : inout std_logic;
        EEPROM_SDA      : inout std_logic;

        GNSS_RESETn     : out   std_logic;
        GNSS_BOOT       : out   std_logic;

        EXT_IO          : inout std_logic_vector(49 downto 0);
        EXT_CI0         : in    std_logic;
        EXT_CI1         : in    std_logic;
        EXT_CO0         : out   std_logic;
        EXT_CO1         : out   std_logic
    );
end art_card_Top;

architecture rtl of art_card_Top is

    component art_card_pd is
        port (
            clk_10m_clk                 : in  std_logic;
            in_100_clk                  : in  std_logic;
            clk_50m_clk                 : out std_logic;
            clk_200m_clk                : out std_logic;
            pll_osc_200m_reset_reset    : in  std_logic;
            clk_200m_locked_export      : out std_logic;
            reset_200m_reset            : in  std_logic;
            pll_50m_reset_reset         : in  std_logic;

            -- PCIe x4
            pcie_serial_rx_in0          : in  std_logic;
            pcie_serial_rx_in1          : in  std_logic;
            pcie_serial_rx_in2          : in  std_logic;
            pcie_serial_rx_in3          : in  std_logic;
            pcie_serial_tx_out0         : out std_logic;
            pcie_serial_tx_out1         : out std_logic;
            pcie_serial_tx_out2         : out std_logic;
            pcie_serial_tx_out3         : out std_logic;
            pcie_npor_npor              : in  std_logic;
            pcie_npor_pin_perst         : in  std_logic;

            -- mRO50 Serial
            serial_mro_tx               : out std_logic;
            serial_mro_rx               : in  std_logic;
            serial_mro_error            : out std_logic;

            -- DAC for specific oscillator
            spi_dac_MISO                : in  std_logic;
            spi_dac_MOSI                : out std_logic;
            spi_dac_SCLK                : out std_logic;
            spi_dac_SS_n                : out std_logic;

            -- EEPROM I2C
            i2c_eeprom_scl_pad_i        : in  std_logic;
            i2c_eeprom_scl_pad_o        : out std_logic;
            i2c_eeprom_scl_padoen_o     : out std_logic;
            i2c_eeprom_sda_pad_i        : in  std_logic;
            i2c_eeprom_sda_pad_o        : out std_logic;
            i2c_eeprom_sda_padoen_o     : out std_logic;

            -- GNSS Serial
            gnss_uart_srx               : in  std_logic;
            gnss_uart_ctsn              : in  std_logic;
            gnss_uart_dsrn              : in  std_logic;
            gnss_uart_rin               : in  std_logic;
            gnss_uart_dcdn              : in  std_logic;
            gnss_uart_stx               : out std_logic;
            gnss_uart_dtrn              : out std_logic;
            gnss_uart_rtsn              : out std_logic;
            gnss_uart_out1n             : out std_logic;
            gnss_uart_out2n             : out std_logic;
            gnss_uart_txrdyn            : out std_logic;
            gnss_uart_rxrdyn            : out std_logic;
            gnss_uart_b_clk             : out std_logic;

            -- GNSS Spy
            gnss_spy1_srx               : in  std_logic;
            gnss_spy1_ctsn              : in  std_logic;
            gnss_spy1_dsrn              : in  std_logic;
            gnss_spy1_rin               : in  std_logic;
            gnss_spy1_dcdn              : in  std_logic;
            gnss_spy1_stx               : out std_logic;
            gnss_spy1_dtrn              : out std_logic;
            gnss_spy1_rtsn              : out std_logic;
            gnss_spy1_out1n             : out std_logic;
            gnss_spy1_out2n             : out std_logic;
            gnss_spy1_txrdyn            : out std_logic;
            gnss_spy1_rxrdyn            : out std_logic;
            gnss_spy1_b_clk             : out std_logic;
            gnss_spy2_srx               : in  std_logic;
            gnss_spy2_ctsn              : in  std_logic;
            gnss_spy2_dsrn              : in  std_logic;
            gnss_spy2_rin               : in  std_logic;
            gnss_spy2_dcdn              : in  std_logic;
            gnss_spy2_stx               : out std_logic;
            gnss_spy2_dtrn              : out std_logic;
            gnss_spy2_rtsn              : out std_logic;
            gnss_spy2_out1n             : out std_logic;
            gnss_spy2_out2n             : out std_logic;
            gnss_spy2_txrdyn            : out std_logic;
            gnss_spy2_rxrdyn            : out std_logic;
            gnss_spy2_b_clk             : out std_logic;

            mro_uart_srx                : in  std_logic;
            mro_uart_ctsn               : in  std_logic;
            mro_uart_dsrn               : in  std_logic;
            mro_uart_rin                : in  std_logic;
            mro_uart_dcdn               : in  std_logic;
            mro_uart_stx                : out std_logic;
            mro_uart_dtrn               : out std_logic;
            mro_uart_rtsn               : out std_logic;
            mro_uart_out1n              : out std_logic;
            mro_uart_out2n              : out std_logic;
            mro_uart_txrdyn             : out std_logic;
            mro_uart_rxrdyn             : out std_logic;
            mro_uart_b_clk              : out std_logic;

            -- Phy2sys
            internal_pps_out_pps_out    : out std_logic;
            ts_phy2sys_time_s_o         : out std_logic_vector(31 downto 0);
            ts_phy2sys_time_ns_o        : out std_logic_vector(31 downto 0);
            firmware_version_firmware_version : in  std_logic_vector(31 downto 0);

            -- PPS Internal
            ppsout_to_pps_out           : out std_logic;
            ppsout_tref_pps_ref         : in  std_logic;
            ts_ppsout_t_time_s_o        : in  std_logic_vector(31 downto 0);
            ts_ppsout_t_time_ns_o       : in  std_logic_vector(31 downto 0);

            -- PPS Output from Internal PPS
            ppsout_ref_pps_ref          : in  std_logic;
            ppsout_o_pps_out            : out std_logic;
            ts_pps_out_time_s_o         : in  std_logic_vector(31 downto 0);
            ts_pps_out_time_ns_o        : in  std_logic_vector(31 downto 0);

            -- PPS Output from GNSS
            ppsout_gref_pps_ref         : in  std_logic;
            ppsout_go_pps_out           : out std_logic;
            ts_ppsout_g_time_s_o        : in  std_logic_vector(31 downto 0);
            ts_ppsout_g_time_ns_o       : in  std_logic_vector(31 downto 0);

            -- PPS Input from IO0
            pps_out_io0_pps_out         : out std_logic;
            pps_ref_io0_pps_ref         : in  std_logic;
            ts_ppsout_io0_time_s_o      : in  std_logic_vector(31 downto 0);
            ts_ppsout_io0_time_ns_o     : in  std_logic_vector(31 downto 0);

            -- PPS Input from IO1
            pps_out_io1_pps_out         : out std_logic;
            pps_ref_io1_pps_ref         : in  std_logic;
            ts_ppsout_io1_time_s_o      : in  std_logic_vector(31 downto 0);
            ts_ppsout_io1_time_ns_o     : in  std_logic_vector(31 downto 0);

            -- PPS Input from IO2
            pps_out_io2_pps_out         : out std_logic;
            pps_ref_io2_pps_ref         : in  std_logic;
            ts_ppsout_io2_time_s_o      : in  std_logic_vector(31 downto 0);
            ts_ppsout_io2_time_ns_o     : in  std_logic_vector(31 downto 0);

            -- PPS Input from IO3
            pps_out_io3_pps_out         : out std_logic;
            pps_ref_io3_pps_ref         : in  std_logic;
            ts_ppsout_io3_time_s_o      : in  std_logic_vector(31 downto 0);
            ts_ppsout_io3_time_ns_o     : in  std_logic_vector(31 downto 0);

            -- ID and Switch Configuration
            firm_config_export          : out std_logic_vector(31 downto 0);
            id_pin_id_pin               : in  std_logic_vector(3 downto 0);
            id_pin_id_osc_pin           : in  std_logic_vector(3 downto 0);
            switch_pin_switch_pin       : out std_logic_vector(5 downto 0);
            switch_pin_config_io_out    : out std_logic_vector(3 downto 0);
            version_id_export           : in  std_logic_vector(31 downto 0)

        );
    end component art_card_pd;

    constant CST_FIRMWARE_VERSION:  std_logic_vector(31 downto 0) := x"00000010";

    signal eeprom_sda_out: std_logic;
    signal eeprom_scl_out: std_logic;
    signal eeprom_sda_oe: std_logic;
    signal eeprom_scl_oe: std_logic;

    signal sUART_OSC_TX: std_logic;
    signal sUART_OSC_RX: std_logic;

    signal gnss_tx:     std_logic;
    signal led_error:   std_logic;

    signal clk_200m:    std_logic;
    signal clk_50m:     std_logic;
    signal pll_locked:  std_logic;
    signal rst_200m:    std_logic;

    signal por_rst: std_logic;
    signal por_rstn: std_logic;
    signal por_rst_cnt : unsigned(8 downto 0);
    signal pcie_npor: std_logic;

    signal por_gnssn: std_logic;
    signal por_gnss_cnt : unsigned(24 downto 0);

    signal internal_ref_pps: std_logic;
    signal internal_time_s : std_logic_vector(31 downto 0);
    signal internal_time_ns : std_logic_vector(31 downto 0);
    signal pps_out: std_logic;
    signal lloop: std_logic;

    signal pps_gnss_200: std_logic;
    signal pps_gnss_r_200: std_logic;
    signal pulse_gnss: std_logic;
    signal pulse_gnss_r: std_logic_vector(2 downto 0);

    signal pps_in_200: std_logic_vector(3 downto 0);
    signal pps_in_r_200: std_logic_vector(3 downto 0);
    signal pulse_pps_in: std_logic_vector(3 downto 0);
    signal pulse_pps_in0_r: std_logic_vector(2 downto 0);
    signal pulse_pps_in1_r: std_logic_vector(2 downto 0);
    signal pulse_pps_in2_r: std_logic_vector(2 downto 0);
    signal pulse_pps_in3_r: std_logic_vector(2 downto 0);

    signal config_io_out: std_logic_vector(3 downto 0);

    signal debug_mro_rx: std_logic;
    signal debug_mro_tx: std_logic;
    signal firm_config: std_logic_vector(31 downto 0);

begin

    u0 : component art_card_pd
        port map (
            clk_10m_clk                 => CLK_OSC,
            in_100_clk                  => PCIE_CLK_REF,
            clk_50m_clk                 => clk_50m,
            clk_200m_clk                => clk_200m,
            pll_osc_200m_reset_reset    => not PCIE_PIN_PERSTn,
            pll_50m_reset_reset         => not PCIE_PIN_PERSTn,
            clk_200m_locked_export      => pll_locked,
            reset_200m_reset            => rst_200m,

            -- PCIe x4
            pcie_serial_rx_in0          => PCIE_RX(0),
            pcie_serial_rx_in1          => PCIE_RX(1),
            pcie_serial_rx_in2          => PCIE_RX(2),
            pcie_serial_rx_in3          => PCIE_RX(3),
            pcie_serial_tx_out0         => PCIE_TX(0),
            pcie_serial_tx_out1         => PCIE_TX(1),
            pcie_serial_tx_out2         => PCIE_TX(2),
            pcie_serial_tx_out3         => PCIE_TX(3),
            pcie_npor_npor              => pcie_npor,
            pcie_npor_pin_perst         => PCIE_PIN_PERSTn,
            serial_mro_tx               => sUART_OSC_TX,
            serial_mro_rx               => sUART_OSC_RX,
            serial_mro_error            => led_error,

            -- DAC for specific oscillator
            spi_dac_MISO                => '0',
            spi_dac_MOSI                => DAC_MOSI,
            spi_dac_SCLK                => DAC_CLK,
            spi_dac_SS_n                => DAC_CSN,

            -- EEPROM I2C
            i2c_eeprom_scl_pad_i        => EEPROM_SCL,
            i2c_eeprom_scl_pad_o        => eeprom_scl_out,
            i2c_eeprom_scl_padoen_o     => eeprom_scl_oe,
            i2c_eeprom_sda_pad_i        => EEPROM_SDA,
            i2c_eeprom_sda_pad_o        => eeprom_sda_out,
            i2c_eeprom_sda_padoen_o     => eeprom_sda_oe,

            -- GNSS Serial
            gnss_uart_srx               => UART_GNSS_RX,
            gnss_uart_ctsn              => '0',
            gnss_uart_dsrn              => '0',
            gnss_uart_rin               => '1',
            gnss_uart_dcdn              => '0',
            gnss_uart_stx               => gnss_tx,
            gnss_uart_dtrn              => open,
            gnss_uart_rtsn              => open,
            gnss_uart_out1n             => open,
            gnss_uart_out2n             => open,
            gnss_uart_txrdyn            => open,
            gnss_uart_rxrdyn            => open,
            gnss_uart_b_clk             => open,

            gnss_spy1_srx               => UART_GNSS_RX,
            gnss_spy1_ctsn              => '0',
            gnss_spy1_dsrn              => '0',
            gnss_spy1_rin               => '1',
            gnss_spy1_dcdn              => '0',
            gnss_spy1_stx               => open,
            gnss_spy1_dtrn              => open,
            gnss_spy1_rtsn              => open,
            gnss_spy1_out1n             => open,
            gnss_spy1_out2n             => open,
            gnss_spy1_txrdyn            => open,
            gnss_spy1_rxrdyn            => open,
            gnss_spy1_b_clk             => open,

            gnss_spy2_srx               => UART_GNSS_RX,
            gnss_spy2_ctsn              => '0',
            gnss_spy2_dsrn              => '0',
            gnss_spy2_rin               => '1',
            gnss_spy2_dcdn              => '0',
            gnss_spy2_stx               => open,
            gnss_spy2_dtrn              => open,
            gnss_spy2_rtsn              => open,
            gnss_spy2_out1n             => open,
            gnss_spy2_out2n             => open,
            gnss_spy2_txrdyn            => open,
            gnss_spy2_rxrdyn            => open,
            gnss_spy2_b_clk             => open,

            mro_uart_srx                => debug_mro_rx,
            mro_uart_ctsn               => '0',
            mro_uart_dsrn               => '0',
            mro_uart_rin                => '1',
            mro_uart_dcdn               => '0',
            mro_uart_stx                => debug_mro_tx,
            mro_uart_dtrn               => open,
            mro_uart_rtsn               => open,
            mro_uart_out1n              => open,
            mro_uart_out2n              => open,
            mro_uart_txrdyn             => open,
            mro_uart_rxrdyn             => open,
            mro_uart_b_clk              => open,

            -- Phy2sys
            internal_pps_out_pps_out    => internal_ref_pps,
            ts_phy2sys_time_s_o         => internal_time_s,
            ts_phy2sys_time_ns_o        => internal_time_ns,
            firmware_version_firmware_version => CST_FIRMWARE_VERSION,

            -- PPS Internal
            ppsout_tref_pps_ref         => internal_ref_pps,
            ppsout_to_pps_out           => open, --feature used only in software
            ts_ppsout_t_time_s_o        => internal_time_s,
            ts_ppsout_t_time_ns_o       => internal_time_ns,

            -- PPS Output Internal PPS
            ppsout_ref_pps_ref          => internal_ref_pps,
            ppsout_o_pps_out            => pps_out,
            ts_pps_out_time_s_o         => internal_time_s,
            ts_pps_out_time_ns_o        => internal_time_ns,

            -- PPS Output GNSS
            ppsout_gref_pps_ref         => pulse_gnss_r(2),
            ppsout_go_pps_out           => open,
            ts_ppsout_g_time_s_o        => internal_time_s,
            ts_ppsout_g_time_ns_o       => internal_time_ns,

            -- PPS Input from IO0
            pps_ref_io0_pps_ref         => pulse_pps_in0_r(2),
            pps_out_io0_pps_out         => open,
            ts_ppsout_io0_time_s_o      => internal_time_s,
            ts_ppsout_io0_time_ns_o     => internal_time_ns,

            -- PPS Input from IO1
            pps_ref_io1_pps_ref         => pulse_pps_in1_r(2),
            pps_out_io1_pps_out         => open,
            ts_ppsout_io1_time_s_o      => internal_time_s,
            ts_ppsout_io1_time_ns_o     => internal_time_ns,

            -- PPS Input from IO2
            pps_ref_io2_pps_ref         => pulse_pps_in2_r(2),
            pps_out_io2_pps_out         => open,
            ts_ppsout_io2_time_s_o      => internal_time_s,
            ts_ppsout_io2_time_ns_o     => internal_time_ns,

            -- PPS Input from IO3
            pps_ref_io3_pps_ref         =>  pulse_pps_in3_r(2),
            pps_out_io3_pps_out         => open,
            ts_ppsout_io3_time_s_o      => internal_time_s,
            ts_ppsout_io3_time_ns_o     => internal_time_ns,

            -- ID and Switch Configuration
            firm_config_export          => firm_config,

            id_pin_id_pin               => ID,
            id_pin_id_osc_pin           => OSC_ID,
            switch_pin_switch_pin       => SEL_IO,
            switch_pin_config_io_out    => config_io_out,
            version_id_export           => CST_FIRMWARE_VERSION

        );

    -- Power over Reset
    process(CLK_25M)
    begin
        if rising_edge(CLK_25M) then
            por_rst  <= not por_rst_cnt(8);
            por_rstn <= por_rst_cnt(8);
            if (por_rst_cnt(8) = '0') then
                por_rst_cnt <= por_rst_cnt + 1;
            end if;
        end if;
    end process;

    process(clk_200m, por_rst)
    begin
        if (por_rst = '1') then
            rst_200m <= '1';
        elsif rising_edge(clk_200m) then
            rst_200m <= not pll_locked;
        end if;
    end process;

    pcie_npor <= por_rstn;

    -- Register GNSS Pulse at 200MHz
    gnss_pulse_200: process(clk_200m, rst_200m)
    begin
        if (rst_200m = '1') then
            pps_gnss_200 <= '0';
            pps_gnss_r_200 <= '0';
        elsif rising_edge(clk_200m) then
            pps_gnss_200 <= GNSS_PPS;
            pps_gnss_r_200 <= pps_gnss_200;
            pulse_gnss <= pps_gnss_200 and not pps_gnss_r_200;
        end if;
    end process gnss_pulse_200;

    -- delay GNSS Pulse
    gnss_pulse_del: process(clk_200m, rst_200m)
    begin
        if (rst_200m = '1') then
            pulse_gnss_r <= (others => '0');
        elsif rising_edge(clk_200m) then
            pulse_gnss_r <= pulse_gnss_r(1 downto 0) & pulse_gnss;
        end if;
    end process gnss_pulse_del;

    -- Register Input PPS Pulse at 200MHz
    in_pulse_200: process(clk_200m, rst_200m)
    begin
        if (rst_200m = '1') then
            pps_in_200 <= (others => '0');
            pps_in_r_200 <= (others => '0');
        elsif rising_edge(clk_200m) then
            pps_in_200 <= DCLS_IN;
            pps_in_r_200 <= pps_in_200;
            pulse_pps_in <= pps_in_200 and not pps_in_r_200;
        end if;
    end process in_pulse_200;

    -- delay IN PPS Pulse
    pps_pulse_del: process(clk_200m, rst_200m)
    begin
        if (rst_200m = '1') then
            pulse_pps_in0_r <= (others => '0');
            pulse_pps_in1_r <= (others => '0');
            pulse_pps_in2_r <= (others => '0');
            pulse_pps_in3_r <= (others => '0');
        elsif rising_edge(clk_200m) then
            pulse_pps_in0_r <= pulse_pps_in0_r(1 downto 0) & pulse_pps_in(0);
            pulse_pps_in1_r <= pulse_pps_in1_r(1 downto 0) & pulse_pps_in(1);
            pulse_pps_in2_r <= pulse_pps_in2_r(1 downto 0) & pulse_pps_in(2);
            pulse_pps_in3_r <= pulse_pps_in3_r(1 downto 0) & pulse_pps_in(3);
        end if;
    end process pps_pulse_del;


    -- LED Assignment
    LED(0) <= GNSS_PPS;
    LED(1) <= pps_out;
    LED(2) <= not gnss_tx or not UART_GNSS_RX;
    LED(3) <= led_error;

    -- DCLS Assignment
    DCLS_OUT(0) <= pps_out when config_io_out(0) = '0' else GNSS_PPS;
    DCLS_OUT(1) <= pps_out when config_io_out(1) = '0' else GNSS_PPS;
    DCLS_OUT(2) <= pps_out when config_io_out(2) = '0' else GNSS_PPS;
    DCLS_OUT(3) <= pps_out when config_io_out(3) = '0' else GNSS_PPS;

    -- EEPROM Assignment
    EEPROM_SCL <= eeprom_scl_out when eeprom_scl_oe = '0' else 'Z';
    EEPROM_SDA <= eeprom_sda_out when eeprom_sda_oe = '0' else 'Z';

    -- Other oscillator support (not implemented)
    OSC_SCL <= 'Z';
    OSC_SDA <= 'Z';

    -- UART Assignment
    UART_OSC_TX <= not sUART_OSC_TX when firm_config(0) = '0' else not debug_mro_tx;
    sUART_OSC_RX <= not UART_OSC_RX when firm_config(0) = '0' else '0';
    debug_mro_rx <= not UART_OSC_RX when firm_config(0) = '1' else '0';

    UART_GNSS_TX <= gnss_tx;
    GNSS_BOOT <= '1';

    -- Reset GNSS
    process(CLK_25M)
    begin
        if rising_edge(CLK_25M) then
            por_gnssn <= por_gnss_cnt(24);
            if (por_gnss_cnt(24) = '0') then
                por_gnss_cnt <= por_gnss_cnt + 1;
            end if;
        end if;
    end process;

    GNSS_RESETn <= por_gnssn;


    -- Test Point
    GPIO(0) <= sUART_OSC_TX;
    GPIO(1) <= sUART_OSC_RX;
    GPIO(2) <= '0';
    GPIO(3) <= '0';


    EXT_IO <= (others => 'Z');

end rtl;
