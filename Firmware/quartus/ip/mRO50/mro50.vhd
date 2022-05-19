--------------------------------------------------------------------------------
--
-- mro50 : PCIe mRO50 driver of the ART_CARD FGPA.
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

entity mro50 is
    generic (
        g_freq_in : integer := 100000000 -- 100MHz
    );
    port (
        RST_I:      in   std_logic;
        CLK_I:      in   std_logic;
        ADDR_I:     in   std_logic_vector(7 downto 0);
        DATA_I:     in   std_logic_vector(31 downto 0);
        DATA_O:     out  std_logic_vector(31 downto 0);
        WR_I:       in   std_logic;
        RD_I:       in   std_logic;

        MRO_TX:     out  std_logic;
        MRO_RX:     in   std_logic;
        MRO_ERROR:  out  std_logic
        );
    end mro50;

architecture rtl_mro50 of mro50 is

    component uart_tx
    generic (
        g_freq_in   :   integer := 50000000
    );
    port (
        -- General signals
        CLK50_I         : in    std_logic;
        RST_I           : in    std_logic;
        -- Bitrate input
        BITRATE_I       : in    std_logic_vector(2 downto 0);
        -- Parallel data input
        DATA_VALID_I    : in    std_logic;
        DATA_I          : in    std_logic_vector(7 downto 0);
        -- control input
        CHAR_LENGTH_I   : in    std_logic_vector(1 downto 0);
        PARITY_I        : in    std_logic_vector(1 downto 0);
        -- control output
        BUSY_O          : out   std_logic;
        -- Serial data output
        TXD_O           : out   std_logic);
    end component;

    component uart_rx is
    generic (
        g_freq_in   :    integer := 50000000
    );
    port (
        -- General signals
        CLK50_I         : in    std_logic;
        RST_I           : in    std_logic;
        -- Bitrate settings
        AUTO_DETECT_I   : in    std_logic;
        BITRATE_I       : in    std_logic_vector(2 downto 0);
        -- Serial input
        RXD_I           : in    std_logic;
        -- control input
        CHAR_LENGTH_I   : in    std_logic_vector(1 downto 0);
        PARITY_I        : in    std_logic_vector(1 downto 0);
        -- parity error output
        PARITY_ERROR_O  : out   std_logic;
        -- Selected/Detected bitrate output
        BITRATE_O       : out   std_logic_vector(2 downto 0);
        -- Parallel data output signals
        DATA_VALID_O    : out   std_logic;
        DATA_O          : out   std_logic_vector(7 downto 0));
    end component;

    -- Address Decoding
    constant    CST_ADDR_OSC_CMD:       std_logic_vector(7 downto 0) := x"00";
    constant    CST_ADDR_OSC_VALUE:     std_logic_vector(7 downto 0) := x"01";
    constant    CST_ADDR_OSC_ADJUST:    std_logic_vector(7 downto 0) := x"02";
    constant    CST_ADDR_TEMPERATURE:   std_logic_vector(7 downto 0) := x"03";
    constant    CST_ADDR_MRO_A:         std_logic_vector(7 downto 0) := x"04";
    constant    CST_ADDR_MRO_B:         std_logic_vector(7 downto 0) := x"05";

    constant    CST_COUNT_1HZ: unsigned(27 downto 0) := unsigned(to_unsigned(g_freq_in/1,28));
    constant    CST_COUNT_2HZ: unsigned(27 downto 0) := unsigned(to_unsigned(g_freq_in/2,28));
    constant    CST_COUNT_30S: unsigned(4 downto 0)  := "11111";

    -- Micro code ROM
    -------------------
    TYPE t_mRO50_cmd_Rom IS ARRAY  ( Natural range <> ) OF character;

    CONSTANT a_mRO50_cmd_Rom: t_mRO50_cmd_Rom :=
    (
        -- monitor1\r               -- pos: 0
        'm','o','n','i','t','o','r','1',cr,
        -- MON_tpcbPIL_cfieldC\r    -- pos: 9
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','C',cr,
        -- FD\r                     -- pos: 29
        'F','D',cr,
        -- MON_tpcbPIL_cfieldCXXXX\r-- pos: 32
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','C', C130, C131, C132, C133, cr,
        -- FDXXXXXXXX\r             -- pos: 56
        'F','D', C130, C131, C132, C133, C134, C135, C136, C137, cr,
        -- PLL SAVE\n               -- pos: 67
        'P','L','L',' ','S','A','V','E', cr,
        -- MON_tpcbPIL_cfieldA00000000\r    --pos: 76
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','A', '0', '0', '0', '0', '0', '0', '0', '0', cr,
        -- MON_tpcbPIL_cfieldB00000000\r    --pos: 104
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','B', '0', '0', '0', '0', '0', '0', '0', '0', cr,
        -- MON_tpcbPIL_cfieldA\r    --pos: 132
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','A', cr,
        -- MON_tpcbPIL_cfieldB\r    --pos: 152
        'M','O','N','_','t','p','c','b','P','I','L','_','c','f','i','e','l','d','B', cr
        -- pos : 172
        );

    signal ptr_Rom: integer range 0 to 255;
    constant CST_PTR_READ_STATUS:   integer := 0;
    constant CST_PTR_READ_FINE:     integer := 9;
    constant CST_PTR_READ_COARSE:   integer := 29;
    constant CST_PTR_WRITE_FINE:    integer := 32;
    constant CST_PTR_WRITE_COARSE:  integer := 56;
    constant CST_PTR_PLL_SAVE:      integer := 67;
    constant CST_PTR_SET_A0:        integer := 76;
    constant CST_PTR_SET_B0:        integer := 104;
    constant CST_PTR_READ_A:        integer := 132;
    constant CST_PTR_READ_B:        integer := 152;

    constant CST_RESP_60B:          unsigned(5 downto 0) := "111100";
    constant CST_RESP_08B:          unsigned(5 downto 0) := "001000";
    constant CST_RESP_04B:          unsigned(5 downto 0) := "000100";
    constant CST_RESP_00B:          unsigned(5 downto 0) := "000000";

    constant CST_TREAT_READ_NOTHING:    std_logic_vector(3 downto 0) := x"0";
    constant CST_TREAT_READ_FINE:       std_logic_vector(3 downto 0) := x"1";
    constant CST_TREAT_READ_COARSE:     std_logic_vector(3 downto 0) := x"2";
    constant CST_TREAT_ADJ_FINE:        std_logic_vector(3 downto 0) := x"3";
    constant CST_TREAT_ADJ_COARSE:      std_logic_vector(3 downto 0) := x"4";
    constant CST_TREAT_READ_STATUS:     std_logic_vector(3 downto 0) := x"5";
    constant CST_TREAT_PLL_SAVE:        std_logic_vector(3 downto 0) := x"6";
    constant CST_TREAT_READ_A:          std_logic_vector(3 downto 0) := x"7";
    constant CST_TREAT_READ_B:          std_logic_vector(3 downto 0) := x"8";

    TYPE Sending_State_type IS (PRE_WAIT, WAITING, SENDING_DATA, WAIT_UART_START, WAIT_UART_STOP, WAIT_RESPONSE,
                                WAIT_CHAR, RECEIVE_CHAR, STORE_DATA);
    signal Sending_State : Sending_State_type;

    signal uart_busy:           std_logic;
    signal data_en_in:          std_logic;
    signal data_en_out:         std_logic;
    signal data_send:           std_logic_vector(7 downto 0);
    signal data_receive:        std_logic_vector(7 downto 0);
    signal data_reg:            std_logic_vector(3 downto 0);
    signal data_from_rom:       std_logic_vector(7 downto 0);

    signal cpt_loop:            unsigned(27 downto 0);
    signal tick_loop:           std_logic;
    signal expected_resp:       unsigned(5 downto 0);
    signal response_ok:         std_logic;
    signal treat:               std_logic_vector(3 downto 0);
    signal resp_timeout:        unsigned(27 downto 0);

    signal hex_char:            std_logic_vector(3 downto 0);
    signal char_hex:            std_logic_vector(7 downto 0);
    signal ptr_hex:             unsigned(3 downto 0);
    signal cpt_receive:         unsigned(5 downto 0);
    signal bit_freq_adj_type:   std_logic;
    signal bit_freq_adj:        std_logic;
    signal bit_freq_read_done:  std_logic;
    signal bit_freq_read_type:  std_logic;
    signal bit_freq_read:       std_logic;
    signal bit_lock:            std_logic;
    signal bit_enable:          std_logic;
    signal bit_save:            std_logic;
    signal bit_auto_read:       std_logic;
    signal bit_err_timeout:     std_logic;
    signal bit_err_size:        std_logic;
    signal bit_err_unknow:      std_logic;

    signal ack_bit_freq_read:   std_logic;
    signal ack_bit_freq_done:   std_logic;
    signal ack_bit_freq_adj:    std_logic;
    signal ack_bit_save:        std_logic;

    signal reg_osc_value:       std_logic_vector(31 downto 0);
    signal reg_osc_adjust:      std_logic_vector(31 downto 0);
    signal reg_temperature:     std_logic_vector(15 downto 0);
    signal reg_status:          std_logic_vector(15 downto 0);

    signal reg_mro_a:           std_logic_vector(31 downto 0);
    signal reg_mro_b:           std_logic_vector(31 downto 0);

    TYPE t_message IS ARRAY  ( integer range 0 to 63 ) OF std_logic_vector(3 downto 0);
    signal message: t_message;

    signal s_error: std_logic;
    signal t_error_time: std_logic;
    signal t_error_size: std_logic;
    signal t_error_unknow: std_logic;
    signal cpt_error: unsigned(23 downto 0);
    signal cpt_wait_mro: unsigned(4 downto 0);
    signal running_mro: std_logic;
    signal preinit_cnt: std_logic_vector(2 downto 0);

begin

    -- Waiting time mro (30s)
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            cpt_wait_mro <= CST_COUNT_30S;
            running_mro <= '0';
        elsif rising_edge(CLK_I) then
            if (tick_loop = '1') then
                if (cpt_wait_mro /= "00000") then
                    cpt_wait_mro <= cpt_wait_mro - 1;
                else
                    running_mro <= '1';
                end if;
            end if;
        end if;
    end process;

    -- CPU access
    -------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            DATA_O              <= (others => '0');
            reg_osc_adjust      <= (others => '0');
            bit_freq_adj_type   <= '0';
            bit_freq_adj        <= '0';
            bit_freq_read_type  <= '0';
            bit_freq_read       <= '0';
            bit_enable          <= '0';
            bit_freq_read_done  <= '0';
            bit_save            <= '0';
            bit_err_timeout     <= '0';
            bit_err_size        <= '0';
        elsif rising_edge(CLK_I) then
            DATA_O <= (others => '0');
            bit_freq_read <= bit_freq_read and not ack_bit_freq_read;
            bit_freq_adj  <= bit_freq_adj  and not ack_bit_freq_adj;
            bit_save      <= bit_save      and not ack_bit_save;
            bit_freq_read_done <= bit_freq_read_done or ack_bit_freq_done;
            bit_err_timeout    <= bit_err_timeout    or t_error_time;
            bit_err_size       <= bit_err_size       or t_error_size;
            bit_err_unknow     <= bit_err_unknow     or t_error_unknow;
            if (RD_I = '1') then
                case ADDR_I is
                    when CST_ADDR_OSC_CMD =>
                        DATA_O <= bit_auto_read &
                            bit_err_timeout &
                            bit_err_size &
                            bit_err_unknow &
                            x"00000" &
                            bit_save &
                            bit_freq_adj_type &
                            bit_freq_adj &
                            bit_freq_read_done &
                            bit_freq_read_type &
                            bit_freq_read &
                            bit_lock &
                            bit_enable;
                        bit_err_timeout <= '0';
                        bit_err_size <= '0';
                        bit_err_unknow <= '0';
                    when CST_ADDR_OSC_VALUE =>
                        DATA_O <= reg_osc_value;
                        bit_freq_read_done <= '0';
                    when CST_ADDR_OSC_ADJUST =>
                        DATA_O <= reg_osc_adjust;
                    when CST_ADDR_TEMPERATURE =>
                        DATA_O <= x"0000" & reg_temperature;
                    when CST_ADDR_MRO_A =>
                        DATA_O <= reg_mro_a;
                    when CST_ADDR_MRO_B =>
                        DATA_O <= reg_mro_b;
                    when others =>
                        null;
                end case;
            end if;
            if (WR_I = '1') then
                case ADDR_I is
                    when CST_ADDR_OSC_CMD =>
                        bit_save            <= DATA_I(7);   -- request save operation
                        bit_freq_adj_type   <= DATA_I(6);   -- select fine or coarse for the write
                        bit_freq_adj        <= DATA_I(5);   -- request write fine or coarse operation
                        bit_freq_read_type  <= DATA_I(3);   -- select fine or coarse for the read
                        bit_freq_read       <= DATA_I(2);   -- request read fine or coarse operation
                        bit_enable          <= DATA_I(0) and running_mro;   -- not used
                        bit_freq_read_done  <= '0';         -- set '0' when write on register
                    when CST_ADDR_OSC_ADJUST =>
                        reg_osc_adjust <= DATA_I;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Status update
    ----------------
    bit_lock <= reg_status(14);
    bit_auto_read <= '1' when (treat = CST_TREAT_READ_STATUS) else '0';

    -- loop request
    ---------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            cpt_loop <= (others => '0');
            tick_loop <= '0';
        elsif rising_edge(CLK_I) then
            tick_loop <= '0';
            cpt_loop <= cpt_loop + 1;
            if (cpt_loop = CST_COUNT_1HZ) then
                cpt_loop <= (others => '0');
                tick_loop <= '1';
            end if;
        end if;
    end process;

    -- Data to be sent
    data_from_rom <= std_logic_vector(to_unsigned(character'pos(a_mRO50_cmd_Rom(ptr_Rom)), 8));

    -- Transmit/Receive Finite State Machine
    ----------------------------------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            data_en_out <= '0';
            data_send <= (others => '0');
            Sending_State <= PRE_WAIT;
            ptr_Rom <= CST_PTR_READ_STATUS;
            expected_resp <= (others => '0');
            ack_bit_freq_read <= '0';
            ack_bit_freq_done <= '0';
            ack_bit_freq_adj <= '0';
            ack_bit_save <= '0';
            treat <= CST_TREAT_READ_NOTHING;
            ptr_hex <= (others => '0');

            preinit_cnt <= "000";

            cpt_receive <= (others => '0');
            reg_osc_value <= (others => '0');
            reg_temperature <= (others => '0');
            reg_status <= (others => '0');
            reg_mro_a <= (others => '1');           -- by default to xFFFFFFFF
            reg_mro_b <= (others => '1');           -- by default to xFFFFFFFF
            t_error_time <= '0';
            t_error_size <= '0';
        elsif rising_edge(CLK_I) then
            t_error_time <= '0';
            t_error_size <= '0';
            t_error_unknow <= '0';
            resp_timeout <= resp_timeout + 1;
            data_en_out <= '0';
            ack_bit_freq_read <= '0';
            ack_bit_freq_adj <= '0';
            ack_bit_freq_done <= '0';
            ack_bit_save <= '0';
            case Sending_State is
                when PRE_WAIT =>
                    ptr_Rom <= CST_PTR_READ_STATUS;
                    treat <= CST_TREAT_READ_NOTHING;
                    Sending_State <= WAITING;
                when WAITING =>
                    if (treat = CST_TREAT_READ_NOTHING) then
                        -- request adjust value read
                        if (bit_freq_read = '1') then
                            if (bit_freq_read_type = '0') then
                                expected_resp <= CST_RESP_04B;
                                ptr_Rom <= CST_PTR_READ_FINE;
                                treat <= CST_TREAT_READ_FINE;
                            else
                                expected_resp <= CST_RESP_08B;
                                ptr_Rom <= CST_PTR_READ_COARSE;
                                treat <= CST_TREAT_READ_COARSE;
                            end if;
                            Sending_State <= SENDING_DATA;
                        -- request adjust value write
                        elsif (bit_freq_adj = '1') then
                            expected_resp <= CST_RESP_00B;
                            if (bit_freq_adj_type = '0') then
                                -- send only 16 bits
                                ptr_hex <= x"4";
                                ptr_Rom <= CST_PTR_WRITE_FINE;
                                treat <= CST_TREAT_ADJ_FINE;
                            else
                                -- send 32 bits
                                ptr_hex <= x"0";
                                ptr_Rom <= CST_PTR_WRITE_COARSE;
                                treat <= CST_TREAT_ADJ_COARSE;
                            end if;
                            Sending_State <= SENDING_DATA;
                        -- request save of coarse value
                        elsif (bit_save = '1') then
                            expected_resp <= CST_RESP_00B;
                            ptr_Rom <= CST_PTR_PLL_SAVE;
                            treat <= CST_TREAT_PLL_SAVE;
                            Sending_State <= SENDING_DATA;
                        -- automatic read of status
                        elsif (tick_loop = '1') and (running_mro = '1') then
                            case preinit_cnt is
                                when "000" =>
                                    preinit_cnt <= "001";
                                    expected_resp <= CST_RESP_00B;
                                    ptr_Rom <= CST_PTR_SET_A0;
                                    treat <= CST_TREAT_READ_NOTHING;
                                    Sending_State <= SENDING_DATA;
                                when "001" =>
                                    preinit_cnt <= "010";
                                    expected_resp <= CST_RESP_00B;
                                    ptr_Rom <= CST_PTR_SET_B0;
                                    treat <= CST_TREAT_READ_NOTHING;
                                    Sending_State <= SENDING_DATA;
                                when "010" =>
                                    preinit_cnt <= "011";
                                    expected_resp <= CST_RESP_08B;
                                    ptr_Rom <= CST_PTR_READ_A;
                                    treat <= CST_TREAT_READ_A;
                                    Sending_State <= SENDING_DATA;
                                when "011" =>
                                    preinit_cnt <= "100";
                                    expected_resp <= CST_RESP_08B;
                                    ptr_Rom <= CST_PTR_READ_B;
                                    treat <= CST_TREAT_READ_B;
                                    Sending_State <= SENDING_DATA;
                                when others =>
                                    expected_resp <= CST_RESP_60B;
                                    ptr_Rom <= CST_PTR_READ_STATUS;
                                    treat <= CST_TREAT_READ_STATUS;
                                    Sending_State <= SENDING_DATA;
                            end case;
                        end if;
                    end if;
                when SENDING_DATA =>
                    data_send <= data_from_rom;
                    if (data_from_rom(7 downto 4) = x"8") then
                        ptr_hex <= ptr_hex + 1;
                        data_send <= char_hex;
                    end if;
                    data_en_out <= '1';
                    Sending_State <= WAIT_UART_START;
                when WAIT_UART_START =>
                    if (uart_busy = '1') then
                        Sending_State <= WAIT_UART_STOP;
                    end if;
                when WAIT_UART_STOP =>
                    if (uart_busy = '0') then
                        if (data_send = x"0D") then
                            ptr_Rom <= CST_PTR_READ_STATUS;
                            Sending_State <= WAIT_RESPONSE;
                        else
                            ptr_Rom <= ptr_Rom + 1;
                            Sending_State <= SENDING_DATA;
                        end if;
                    end if;
                when WAIT_RESPONSE =>
                    resp_timeout <= (others => '0');
                    cpt_receive <= (others => '0');
                    -- default waiting response
                    Sending_State <= WAIT_CHAR;
                when WAIT_CHAR =>
                    if (data_en_in = '1') then
                        -- detect end of frame on <LF>
                        if (data_receive = x"0A") then
                            -- if no response expected
                            if ((cpt_receive = "000000") and (expected_resp = CST_RESP_00B)) then
                                if (treat = CST_TREAT_ADJ_FINE) or (treat = CST_TREAT_ADJ_COARSE) then
                                    ack_bit_freq_adj <= '1';
                                end if;
                                if (treat = CST_TREAT_PLL_SAVE) then
                                    ack_bit_save <= '1';
                                end if;
                                Sending_State <= PRE_WAIT;
                                treat <= CST_TREAT_READ_NOTHING;
                            -- expected response
                            else
                                if (cpt_receive = expected_resp) then
                                    --full frame received
                                    Sending_State <= STORE_DATA;
                                else
                                    -- error
                                    t_error_size <= '1';
                                    Sending_State <= PRE_WAIT;
                                end if;
                            end if;
                        else
                        -- ignore <CR>
                            if (data_receive /= x"0D") then
                                Sending_State <= RECEIVE_CHAR;
                            end if;
                        -- detect ?
                            if (data_receive = x"3F") then
                                t_error_unknow <= '1';
                                Sending_State <= PRE_WAIT;
                            end if;
                        end if;
                    end if;
                    if (resp_timeout = CST_COUNT_2HZ) then
                        if (expected_resp = CST_RESP_00B) then
                            -- acknowledge 00 response (considering OK)
                            if (treat = CST_TREAT_ADJ_FINE) or (treat = CST_TREAT_ADJ_COARSE) then
                                ack_bit_freq_adj <= '1';
                            end if;
                            if (treat = CST_TREAT_PLL_SAVE) then
                                ack_bit_save <= '1';
                            end if;
                        else
                            t_error_time <= '1';
                        end if;
                        Sending_State <= PRE_WAIT;
                    end if;
                when RECEIVE_CHAR =>
                    message(to_integer(cpt_receive)) <= hex_char;
                    cpt_receive <= cpt_receive + 1;
                    Sending_State <= WAIT_CHAR;
                    if (cpt_receive = CST_RESP_60B) then
                        Sending_State <= PRE_WAIT;
                    end if;
                when STORE_DATA =>
                    case treat is
                        when CST_TREAT_READ_COARSE =>
                            reg_osc_value   <= message(0) & message(1) & message(2) & message(3) &
                                                message(4) & message(5) & message(6) & message(7);
                            ack_bit_freq_read <= '1';
                            ack_bit_freq_done <= '1';
                        when CST_TREAT_READ_FINE =>
                            reg_osc_value   <= x"0000" &
                                                message(0) & message(1) & message(2) & message(3);
                            ack_bit_freq_read <= '1';
                            ack_bit_freq_done <= '1';
                        when CST_TREAT_READ_STATUS =>
                            reg_temperature <= message(52) & message(53) & message(54) & message(55);
                            reg_status      <= message(56) & message(57) & message(58) & message(59);
                        when CST_TREAT_READ_A =>
                            reg_mro_a <= message(0) & message(1) & message(2) & message(3) &
                                            message(4) & message(5) & message(6) & message(7);
                        when CST_TREAT_READ_B =>
                            reg_mro_b <= message(0) & message(1) & message(2) & message(3) &
                                            message(4) & message(5) & message(6) & message(7);
                        when others =>
                            null;
                    end case;
                    treat <= CST_TREAT_READ_NOTHING;
                    Sending_State <= PRE_WAIT;
                when others =>
                    Sending_State <= PRE_WAIT;
            end case;
        end if;
    end process;

    -- Convert ASCII Char to HEX Char
    ---------------------------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            hex_char <= (others => '0');
        elsif rising_edge(CLK_I) then
            case data_receive is
                when x"30" =>
                    hex_char <= x"0";
                when x"31" =>
                    hex_char <= x"1";
                when x"32" =>
                    hex_char <= x"2";
                when x"33" =>
                    hex_char <= x"3";
                when x"34" =>
                    hex_char <= x"4";
                when x"35" =>
                    hex_char <= x"5";
                when x"36" =>
                    hex_char <= x"6";
                when x"37" =>
                    hex_char <= x"7";
                when x"38" =>
                    hex_char <= x"8";
                when x"39" =>
                    hex_char <= x"9";
                when x"41" =>
                    hex_char <= x"A";
                when x"42" =>
                    hex_char <= x"B";
                when x"43" =>
                    hex_char <= x"C";
                when x"44" =>
                    hex_char <= x"D";
                when x"45" =>
                    hex_char <= x"E";
                when x"46" =>
                    hex_char <= x"F";
                when others =>
                    hex_char <= x"0";
            end case;
        end if;
    end process;

    -- HEX Selection
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            data_reg <= (others => '0');
        elsif rising_edge(CLK_I) then
            case ptr_hex is
                when x"0" =>
                    data_reg <= reg_osc_adjust(31 downto 28);
                when x"1" =>
                    data_reg <= reg_osc_adjust(27 downto 24);
                when x"2" =>
                    data_reg <= reg_osc_adjust(23 downto 20);
                when x"3" =>
                    data_reg <= reg_osc_adjust(19 downto 16);
                when x"4" =>
                    data_reg <= reg_osc_adjust(15 downto 12);
                when x"5" =>
                    data_reg <= reg_osc_adjust(11 downto 08);
                when x"6" =>
                    data_reg <= reg_osc_adjust(07 downto 04);
                when x"7" =>
                    data_reg <= reg_osc_adjust(03 downto 00);
                when others =>
                    data_reg <= (others => '0');
            end case;
        end if;
    end process;

    -- Convert HEX Char to ASCII Char
    ---------------------------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            char_hex <= (others => '0');
        elsif rising_edge(CLK_I) then
            case data_reg is
                when x"0" =>
                    char_hex <= x"30";
                when x"1" =>
                    char_hex <= x"31";
                when x"2" =>
                    char_hex <= x"32";
                when x"3" =>
                    char_hex <= x"33";
                when x"4" =>
                    char_hex <= x"34";
                when x"5" =>
                    char_hex <= x"35";
                when x"6" =>
                    char_hex <= x"36";
                when x"7" =>
                    char_hex <= x"37";
                when x"8" =>
                    char_hex <= x"38";
                when x"9" =>
                    char_hex <= x"39";
                when x"A" =>
                    char_hex <= x"41";
                when x"B" =>
                    char_hex <= x"42";
                when x"C" =>
                    char_hex <= x"43";
                when x"D" =>
                    char_hex <= x"44";
                when x"E" =>
                    char_hex <= x"45";
                when x"F" =>
                    char_hex <= x"46";
                when others =>
                    char_hex <= x"00";
            end case;
        end if;
    end process;

    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            s_error <= '0';
            cpt_error <= (others => '0');
        elsif rising_edge(CLK_I) then
            s_error <= cpt_error(23);
            if (cpt_error /= x"000000") then
                cpt_error <= cpt_error - 1;
            else
                if (t_error_time = '1') or (t_error_size = '1') then
                    cpt_error <= (others => '1');
                end if;
            end if;
        end if;
    end process;

    MRO_ERROR <= s_error;

    uart_tx_intf : uart_tx
    generic map (
        g_freq_in       => g_freq_in
    )
    port map (
        CLK50_I         => CLK_I,
        RST_I           => RST_I,
        BITRATE_I       => "011",   -- set to 9600
        DATA_VALID_I    => data_en_out,
        DATA_I          => data_send,
        CHAR_LENGTH_I   => "00",    -- set 8 bits
        PARITY_I        => "00",    -- set no parity
        BUSY_O          => uart_busy,
        TXD_O           => MRO_TX
        );

    uart_rx_intf : uart_rx
    generic map (
        g_freq_in       => g_freq_in
    )
    port map(
        CLK50_I         => CLK_I,
        RST_I           => RST_I,
        AUTO_DETECT_I   => '0',     -- set no auto-detect
        BITRATE_I       => "011",   -- set to 9600
        RXD_I           => MRO_RX,
        CHAR_LENGTH_I   => "00",    -- set 8 bits
        PARITY_I        => "00",    -- set no parity
        PARITY_ERROR_O  => open,
        BITRATE_O       => open,
        DATA_VALID_O    => data_en_in,
        DATA_O          => data_receive
        );

end rtl_mro50;
