--------------------------------------------------------------------------------
-- 
-- Phasemeter : Phasemeter driver of the ART_CARD FGPA.
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

entity phasemeter is
    port (
        -- General signals
        CLK_CPU_I       : in    std_logic;
        RST_CPU_I       : in    std_logic;

        CLK200_I        : in    std_logic;
        RST200_I        : in    std_logic;

        ADR_I           : in    std_logic_vector(3 downto 0);
        RD_I            : in    std_logic;
        WE_I            : in    std_logic;
        DAT_I           : in    std_logic_vector(31 downto 0);
        DAT_O           : out   std_logic_vector(31 downto 0);
        IRQ1_O          : out   std_logic;

        OFFSET_PHASE_O  : out   std_logic_vector(31 downto 0);
        REQUEST_OFFSET_O: out   std_logic;
        ACK_OFFSET_I    : in    std_logic;

        PHASE_DEBUG     : out   std_logic_vector(31 downto 0);

        PPS_I           : in    std_logic;
        PPS_GNSS        : in    std_logic

    );
end entity phasemeter;

architecture A_phasemeter of phasemeter is

    constant ADDR_READ_PHASE1_C:    std_logic_vector(3 downto 0) := x"0";  -- phase between GNSS and OCXO
    constant ADDR_SET_OFFSET1_C:    std_logic_vector(3 downto 0) := x"1";  -- OFFSET between GNSS and OCXO
    constant ADDR_CTRL_REG1_C:      std_logic_vector(3 downto 0) := x"2";  -- Control Register
    constant ADDR_CLEAR_INTERRUPT_C:std_logic_vector(3 downto 0) := x"A";  -- Clear Interrupt


    constant PHASE_LIMIT_LOW:  unsigned(31 downto 0) := x"E2329B00";    --  -500 000 000 ns
    constant PHASE_LIMIT_HIGH: unsigned(31 downto 0) := x"1DCD6500";    --  +500 000 000 ns

    type phase_state_t  is (WAIT_AB, WAIT_A, WAIT_B, END_PHASE);
    signal phase_state1: phase_state_t;

    signal pps_200: std_logic;
    signal pps_200_r: std_logic;

    signal phase_cnt1 : unsigned(31 downto 0);
    signal phase_value1 : unsigned(31 downto 0);
    signal offset1 : std_logic_vector(31 downto 0);
    signal request_offset1: std_logic;
    signal request_reset1: std_logic;
    signal ack_reset1: std_logic;
    signal ack_reset1_r: std_logic;
    signal apply_reset1: std_logic;
    signal pps_gnss_200: std_logic;
    signal pps_gnss_r_200: std_logic;
    signal pulse_gnss: std_logic;
    signal pulse_pps: std_logic;
    signal irq1: std_logic;
    signal pps_cpt : unsigned(8 downto 0);

    signal req_clear_irq: std_logic;
    signal req_clear_irq_r: std_logic;
    signal ack_clear_irq: std_logic;
    signal irq_active : std_logic;
    signal irq_enable : std_logic;

    signal data_out: std_logic_vector(31 downto 0);

begin

    -- CPU Decoding
    cpu_decod: process(CLK_CPU_I,RST_CPU_I)
    begin
        if (RST_CPU_I = '1') then
            data_out <= (others => '0');
            request_reset1 <= '0';
            request_offset1 <= '0';
            req_clear_irq <= '0';
            offset1 <= (others => '0');
            irq_enable <= '0';
        elsif rising_edge(CLK_CPU_I) then
            request_reset1 <= request_reset1 and not ack_reset1;
            request_offset1 <= request_offset1 and not ACK_OFFSET_I;
            req_clear_irq <= req_clear_irq and not ack_clear_irq;
            data_out <= (others => '0');
            if (RD_I = '1') then
                case ADR_I is
                    when ADDR_READ_PHASE1_C =>
                        data_out <= std_logic_vector(phase_value1);
                    when ADDR_SET_OFFSET1_C =>
                        data_out <= offset1;
                    when ADDR_CTRL_REG1_C =>
                        data_out <= x"0000000" & "000" & irq_enable;
                    when others =>
                        null;
                end case;
            end if;
            if (WE_I = '1') then
                case  ADR_I is
                    when ADDR_READ_PHASE1_C =>
                        request_reset1 <= '1';
                    when ADDR_SET_OFFSET1_C =>
                        offset1 <= DAT_I;
                        request_offset1 <= '1';
                    when ADDR_CTRL_REG1_C => 
                        irq_enable <= DAT_I(0);
                    when ADDR_CLEAR_INTERRUPT_C =>
                        req_clear_irq <= '1';
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process cpu_decod;

    DAT_O <= data_out;
    REQUEST_OFFSET_O <= request_offset1;
    OFFSET_PHASE_O <= offset1;

    -- Change clock domain CPU to 200MHz
    dom_chg200: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            ack_reset1 <= '0';
            ack_reset1_r <= '0';
            apply_reset1 <= '0';
        elsif rising_edge(CLK200_I) then
            -- Reset FSM
            ack_reset1 <= request_reset1;
            ack_reset1_r <= ack_reset1;
            apply_reset1 <= ack_reset1 and not ack_reset1_r;

        end if;
    end process dom_chg200;

    -- Register GNSS in 200MHz
    gnss_200: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            pps_gnss_200 <= '0';
            pps_gnss_r_200 <= '0';
        elsif rising_edge(CLK200_I) then
            pps_gnss_200 <= PPS_GNSS;
            pps_gnss_r_200 <= pps_gnss_200;
            pulse_gnss <= pps_gnss_200 and not pps_gnss_r_200;
        end if;
    end process gnss_200;

    -- Internal pps alignement to the GNSS
    pps_ph: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            pps_200 <='0';
            pps_200_r <='0';
            pulse_pps <='0';
        elsif rising_edge(CLK200_I) then
            pps_200 <= PPS_I;
            pps_200_r <= pps_200;
            pulse_pps <= pps_200 and not pps_200_r;
        end if;
    end process pps_ph;

    -- Phasemeter 1 -- start with PPS OCXO to PPS GNSS
    phase1: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            phase_state1 <= WAIT_AB;
            phase_cnt1 <= (others => '0');
            phase_value1 <= (others => '0');
            irq1 <= '0';
        elsif rising_edge(CLK200_I) then
            irq1 <= '0';
            case phase_state1 is
                when WAIT_AB =>
                    phase_cnt1 <= (others => '0');
                    if (pulse_gnss = '1') then
                        phase_state1 <= WAIT_A;
                    end if;
                    if (pulse_pps = '1') then
                        phase_state1 <= WAIT_B;
                    end if;
                    if (pulse_pps = '1') and (pulse_gnss = '1') then
                        phase_state1 <= END_PHASE;
                    end if;
                when WAIT_A =>
                    phase_cnt1 <= phase_cnt1 - 5;
                    if (phase_cnt1 = PHASE_LIMIT_LOW) then
                        phase_state1 <= WAIT_AB;
                    end if;
                    if (pulse_pps = '1') then
                        phase_state1 <= END_PHASE;
                    end if;
                when WAIT_B =>
                    phase_cnt1 <= phase_cnt1 + 5;
                    if (phase_cnt1 = PHASE_LIMIT_HIGH) then
                        phase_state1 <= WAIT_AB;
                    end if;
                    if (pulse_gnss = '1') then
                        phase_state1 <= END_PHASE;
                    end if;
                when END_PHASE =>
                    irq1 <= '1';
                    phase_value1 <= phase_cnt1;
                    phase_state1 <= WAIT_AB;
                when others =>
                    phase_state1 <= WAIT_AB;
            end case;
            if (apply_reset1 = '1') then
                phase_cnt1 <= (others => '0');
                phase_state1 <= WAIT_AB;
            end if;
        end if;
    end process phase1;

    -- IRQ1 process
    irq1_p: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            irq_active <= '0';
            ack_clear_irq <= '0';
        elsif rising_edge(CLK200_I) then
            ack_clear_irq <= '0';
            req_clear_irq_r <= req_clear_irq;
            if (req_clear_irq_r = '1') then
                ack_clear_irq <= '1';
                irq_active <= '0';
            elsif (irq1 = '1') and (irq_enable = '1') then
                irq_active <= '1';
            end if;
        end if;
    end process irq1_p;

    PHASE_DEBUG <= std_logic_vector(phase_value1);

    IRQ1_O <= irq_active;

end architecture A_phasemeter;

