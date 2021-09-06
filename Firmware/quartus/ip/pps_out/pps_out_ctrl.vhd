--------------------------------------------------------------------------------
--
-- pps_out_ctrl : pps_out controller of the ART_CARD FGPA.
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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity pps_out_ctrl is
    port (
        -- General signals
        CLK_CPU_I       : in    std_logic;
        RST_CPU_I       : in    std_logic;

        CLK200_I        : in    std_logic;
        RST200_I        : in    std_logic;

        ADR_I           : in    std_logic_vector(7 downto 0);
        RD_I            : in    std_logic;
        WE_I            : in    std_logic;
        DAT_I           : in    std_logic_vector(31 downto 0);
        DAT_O           : out   std_logic_vector(31 downto 0);

        TIME_S_O        : in    std_logic_vector(31 downto 0);
        TIME_NS_O       : in    std_logic_vector(31 downto 0);

        PPS_REF         : in    std_logic;
        PPS_OUT         : out   std_logic;
        IRQ_PPS_O       : out   std_logic

    );
end entity pps_out_ctrl;

architecture A_pps_out_ctrl of pps_out_ctrl is

    constant ADDR_CTRL_C:           std_logic_vector(7 downto 0) := x"00";
    constant ADDR_CLEAR_IRQ_C:      std_logic_vector(7 downto 0) := x"0C";
    constant ADDR_TS_NS_C:          std_logic_vector(7 downto 0) := x"11";
    constant ADDR_TS_S_C:           std_logic_vector(7 downto 0) := x"12";
    constant ADDR_WIDTH_C:          std_logic_vector(7 downto 0) := x"13";

    constant PPS_PER_SECOND_200: unsigned(31 downto 0) := x"3B9AC9FB"; --999 999 995    ns
    constant PPS_DELAY_200:      unsigned(31 downto 0) := x"00000023"; --000 000 035    ns
    constant HMS_PER_SECOND_200: unsigned(31 downto 0) := x"05F5E0FB"; --099 999 995    ns

    signal cpt_pps: unsigned(31 downto 0);

    signal reg_width: unsigned(31 downto 0);

    signal pps_o:   std_logic;

    signal data_out: std_logic_vector(31 downto 0);

    signal request_offset_r: std_logic;
    signal ack_offset: std_logic;

    signal req_clear_irq: std_logic;
    signal req_clear_irq_r: std_logic;
    signal ack_clear_irq: std_logic;

    signal irq_enable:  std_logic;
    signal irq_o: std_logic;

    signal ts_s: std_logic_vector(31 downto 0);
    signal ts_ns: std_logic_vector(31 downto 0);

begin

    -- CPU Decoding
    cpu_decod: process(CLK_CPU_I,RST_CPU_I)
    begin
        if (RST_CPU_I = '1') then
            data_out <= (others => '0');
            reg_width <= HMS_PER_SECOND_200;
            irq_enable <= '0';
        elsif rising_edge(CLK_CPU_I) then
            data_out <= (others => '0');
            req_clear_irq <= req_clear_irq and not ack_clear_irq;
            if (RD_I = '1') then
                case ADR_I is
                    when ADDR_CTRL_C =>
                        data_out <= x"0000000" & "000" & irq_enable;
                    when ADDR_WIDTH_C =>
                        data_out <= std_logic_vector(reg_width);
                    when ADDR_TS_S_C =>
                        data_out <= ts_s;
                    when ADDR_TS_NS_C =>
                        data_out <= ts_ns;
                    when ADDR_CLEAR_IRQ_C =>
                        data_out <= x"0000000" & "000" & irq_o;
                    when others =>
                        null;
                end case;
            end if;
            if (WE_I = '1') then
                case  ADR_I is
                    when ADDR_CTRL_C =>
                        irq_enable <= DAT_I(0);
                    when ADDR_WIDTH_C =>
                        reg_width <= unsigned(DAT_I);
                    when ADDR_CLEAR_IRQ_C =>
                        req_clear_irq <= '1';
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process cpu_decod;

    DAT_O <= data_out;

    -- Timestamp at PPS input
    pps_ts_p: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            ts_s <= (others => '0');
            ts_ns <= (others => '0');
        elsif rising_edge(CLK200_I) then
            if (PPS_REF = '1') then
                ts_s <= TIME_S_O;
                ts_ns <= TIME_NS_O;
            end if;
        end if;
    end process pps_ts_p;

    -- pps generation
    pps_out_p: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            cpt_pps <=   (others => '0');
            pps_o <= '0';
        elsif rising_edge(CLK200_I) then
            cpt_pps <= cpt_pps + 5;
            if (cpt_pps >= reg_width) then
                pps_o <= '0';
            end if;
            if (cpt_pps = PPS_PER_SECOND_200) then
                cpt_pps <= (others => '0');
                pps_o <= '1';
            end if;
            if (PPS_REF = '1') then
                cpt_pps <= PPS_DELAY_200;
                pps_o <= '1';
            end if;
        end if;
    end process pps_out_p;

    PPS_OUT <= pps_o;

    -- Generate IRQ
    irq_gen: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            irq_o <= '0';
            req_clear_irq_r <= '0';
            ack_clear_irq <= '1';
        elsif rising_edge(CLK200_I) then
            ack_clear_irq <= '0';
            req_clear_irq_r <= req_clear_irq;
            if (req_clear_irq_r = '1') then
                irq_o <= '0';
                ack_clear_irq <= '1';
            elsif (PPS_REF = '1') and (irq_enable = '1') then
                irq_o <= '1';
            end if;
        end if;
    end process irq_gen;

    IRQ_PPS_O <= irq_o;

end architecture A_pps_out_ctrl;

