--------------------------------------------------------------------------------
--
-- phy2sys : phy2sys driver of the ART_CARD FGPA.
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

entity phy2sys is
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

        OFFSET_PHASE_I  : in    std_logic_vector(31 downto 0);
        REQUEST_OFFSET_I: in    std_logic;
        ACK_OFFSET_O    : out   std_logic;

        TIME_S_O        : out   std_logic_vector(31 downto 0);
        TIME_NS_O       : out   std_logic_vector(31 downto 0);

        PPS_OUT         : out   std_logic       -- one pulse at 200MHz

    );
end entity phy2sys;

architecture A_phy2sys of phy2sys is

    constant ADDR_CTRL_C:           std_logic_vector(3 downto 0) := x"0";
    constant ADDR_STATUS_C:         std_logic_vector(3 downto 0) := x"1";
    constant ADDR_VERSION_C:        std_logic_vector(3 downto 0) := x"3";
    constant ADDR_TIME_NS_C:        std_logic_vector(3 downto 0) := x"4";
    constant ADDR_TIME_SEC_C:       std_logic_vector(3 downto 0) := x"5";
    constant ADDR_ADJ_TIME_NS_C:    std_logic_vector(3 downto 0) := x"8";
    constant ADDR_ADJ_TIME_SEC_C:   std_logic_vector(3 downto 0) := x"9";

    constant PHY2SYS_VERSION_C:     std_logic_vector(31 downto 0) := x"00000007";

    constant PPS_NS_MEGA_C:  signed(31 downto 0) := x"3B9AC9FB"; --999 999 995
    constant PPS_NS1_MEGA_C: signed(31 downto 0) := x"3B9AC9F6"; --999 999 990
    --constant PPS_PER_SECOND_200: signed(31 downto 0) := x"0001FFFE"; -- for debug

    signal current_sec: unsigned(31 downto 0);
    signal current_ns : signed(31 downto 0);
    signal current_ns_add: unsigned(31 downto 0);

    signal reload_ns:   std_logic;
    signal reload_ns_r: std_logic;
    signal val_reload_ns: signed(31 downto 0);
    signal val_reload_sec: unsigned(31 downto 0);

    signal reg_status: std_logic_vector(31 downto 0);

    signal reg_read_sec: std_logic_vector(31 downto 0);
    signal reg_read_ns : std_logic_vector(31 downto 0);

    signal reg_adj_sec: std_logic_vector(31 downto 0);
    signal reg_adj_ns : std_logic_vector(31 downto 0);

    signal time_adj_done: std_logic;

    signal bit_ctrl_enable: std_logic;
    signal bit_ctrl_done: std_logic;
    signal ack_ctrl_done: std_logic;

    signal time_read_req: std_logic;
    signal time_read_req_r: std_logic;

    signal time_adj_req: std_logic;
    signal time_adj_req_r: std_logic;
    signal time_adj_req_rr: std_logic;

    signal tick_pps: std_logic;
    signal pps_cpt : unsigned(24 downto 0);
    signal pps_o:   std_logic;

    signal data_out: std_logic_vector(31 downto 0);

    signal request_offset_r: std_logic;
    signal ack_offset: std_logic;

begin

    -- CPU Decoding
    cpu_decod: process(CLK_CPU_I,RST_CPU_I)
    begin
        if (RST_CPU_I = '1') then
            data_out <= (others => '0');
            reg_status <= (others => '0');
            time_read_req <= '0';
            time_adj_req <= '0';
            bit_ctrl_enable <= '0';
            ack_ctrl_done <= '0';
        elsif rising_edge(CLK_CPU_I) then
            ack_ctrl_done <= '0';
            data_out <= (others => '0');
            if (RD_I = '1') then
                case ADR_I is
                    when ADDR_CTRL_C =>
                        data_out <= bit_ctrl_done & time_read_req & "00" & x"000000" & "00" & time_adj_req & bit_ctrl_enable;
                        ack_ctrl_done <= bit_ctrl_done;
                    when ADDR_STATUS_C =>
                        data_out <= reg_status;
                    when ADDR_VERSION_C =>
                        data_out <= PHY2SYS_VERSION_C;
                    when ADDR_TIME_NS_C =>
                        data_out <= reg_read_ns;
                    when ADDR_TIME_SEC_C =>
                        data_out <= reg_read_sec;
                    when ADDR_ADJ_TIME_NS_C =>
                        data_out <= reg_adj_ns;
                    when ADDR_ADJ_TIME_SEC_C =>
                        data_out <= reg_adj_sec;
                    when others =>
                        null;
                end case;
            end if;
            if (WE_I = '1') then
                case  ADR_I is
                    when ADDR_CTRL_C =>
                        time_read_req <= time_read_req or DAT_I(30);
                        time_adj_req <= time_adj_req or DAT_I(1);
                        bit_ctrl_enable <= DAT_I(0);
                    when ADDR_STATUS_C =>
                        reg_status <= DAT_I;
                    when ADDR_ADJ_TIME_NS_C =>
                        reg_adj_ns <= DAT_I;
                    when ADDR_ADJ_TIME_SEC_C =>
                        reg_adj_sec <= DAT_I;
                    when others =>
                        null;
                end case;
            end if;
            if (bit_ctrl_done = '1') then
                time_read_req <= '0';
            end if;
            if (time_adj_done = '1') then
                time_adj_req <= '0';
            end if;
        end if;
    end process cpu_decod;

    DAT_O <= data_out;

    process(CLK_CPU_I,RST_CPU_I)
    begin
        if (RST_CPU_I = '1') then
            time_read_req_r <= '0';
            reg_read_ns <= (others => '0');
            reg_read_sec <= (others => '0');
            bit_ctrl_done <= '0';
        elsif rising_edge(CLK_CPU_I) then
            time_read_req_r <= time_read_req;
            if (ack_ctrl_done = '1') then
                bit_ctrl_done <= '0';
            end if;
            if (time_read_req = '1') and (time_read_req_r = '0') then
                reg_read_ns <= std_logic_vector(current_ns);
                reg_read_sec <= std_logic_vector(current_sec);
                bit_ctrl_done <= '1';
            end if;
        end if;
    end process;

    -- Clock nanosecond
    clock_ns: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            current_ns <=   (others => '0');
            reload_ns_r <= '0';
            tick_pps <= '0';
        elsif rising_edge(CLK200_I) then
            reload_ns_r <= reload_ns;
            current_ns <= current_ns + 5;
            tick_pps <= '0';
            if (reload_ns = '1' and reload_ns_r = '0') then
                current_ns <= val_reload_ns;
                tick_pps <= '1';
            end if;
        end if;
    end process clock_ns;

    -- Clock second
    clock_sec: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            current_sec <=  (others => '0');
        elsif rising_edge(CLK200_I) then
            if (reload_ns = '1' and reload_ns_r = '0') then
                current_sec <= val_reload_sec;
            end if;
        end if;
    end process clock_sec;

    -- Clock
    clock_p: process(CLK200_I, RST200_I)
    begin
        if (RST200_I = '1') then
            time_adj_done <= '0';
            time_adj_req_r <= '0';
            time_adj_req_rr <= '0';
            ack_offset <= '0';
            val_reload_ns <= (others => '0');
            val_reload_sec <= (others => '0');
            reload_ns <= '0';
        elsif rising_edge(CLK200_I) then
            reload_ns <= '0';
            val_reload_ns <= (others => '0');
            val_reload_sec <= current_sec + 1;
            ack_offset <= ack_offset and REQUEST_OFFSET_I;
            time_adj_req_r <= time_adj_req;
            time_adj_req_rr <= time_adj_req_r;
            if (time_adj_req_r = '0') then
                time_adj_done <= '0';
            end if;
            -- change time immediately  from phy2sys
            if (time_adj_req_r = '1') and (time_adj_req_rr = '0') then
                val_reload_ns <= signed(reg_adj_ns);
                val_reload_sec <= unsigned(reg_adj_sec);
                time_adj_done <= '1';
                reload_ns <= '1';
            end if;
            -- Change time on Second
            if (current_ns >= PPS_NS1_MEGA_C) then
                request_offset_r <= REQUEST_OFFSET_I;
                if (REQUEST_OFFSET_I = '1') and (request_offset_r = '0') then
                    val_reload_ns <= signed(OFFSET_PHASE_I);
                    ack_offset <= '1';
                end if;
                reload_ns <= '1';
            end if;
        end if;
    end process clock_p;

    ACK_OFFSET_O <= ack_offset;
    PPS_OUT <= tick_pps;

    TIME_S_O <= std_logic_vector(current_sec);
    TIME_NS_O <= std_logic_vector(current_ns);

end architecture A_phy2sys;

