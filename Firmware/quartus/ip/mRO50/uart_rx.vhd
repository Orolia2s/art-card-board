--------------------------------------------------------------------------------
-- 
-- uart_rx : UART receiver driver of the ART_CARD FGPA.
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
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
end uart_rx;

architecture rtl of uart_rx is

    ----------------------------------------------------------------------------
    -- Constant Declarations ---------------------------------------------------
    ----------------------------------------------------------------------------
    -- Bitrate counter constants
    constant    RX1200_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/4800,16));    --x"28B0";
    constant    RX2400_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/9600,16));    --x"1457";
    constant    RX4800_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/19200,16));   --x"0A2B";
    constant    RX9600_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/38400,16));   --x"0515";
    constant    RX19200_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/76800,16));   --x"028A";
    constant    RX38400_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/153600,16));  --x"0145";
    constant    RX57600_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/230400,16));  --x"00D8";
    constant    RX115200_C  : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/460800,16));  --x"006C";

    ----------------------------------------------------------------------------
    -- Signal Declarations -----------------------------------------------------
    ----------------------------------------------------------------------------

    type    rx_state_typ is (WAIT_START_S,
                             DATA_S,
                             PARITY_S,
                             STOP_S);

    signal  rx_state        : rx_state_typ;

    signal  rx              : std_logic;
    signal  rx_r            : std_logic;
    signal  rx_rr           : std_logic;
    signal  rx_rise         : std_logic;
    signal  rx_fall         : std_logic;
    signal  bitrate         : std_logic_vector(2 downto 0);
    signal  bitrate_chk1    : std_logic_vector(1 downto 0);
    signal  rx_clk_load     : std_logic_vector(15 downto 0);
    signal  rx_clk_cnt      : std_logic_vector(15 downto 0);
    signal  rx_clk          : std_logic;
    signal  rx_smpl_cnt     : std_logic_vector(1 downto 0);
    signal  rx_smpl_clk     : std_logic;
    signal  rx_bit_pos      : std_logic_vector(2 downto 0);
    signal  rx_smpl_start   : std_logic;
    signal  bitrate_chk2    : std_logic;
    signal  data_valid      : std_logic;
    signal  rx_actv         : std_logic;
    signal  rx_reg          : std_logic_vector(7 downto 0);

    signal  rx_parity       : std_logic;
    signal  parity_error    : std_logic;
    signal  data_len        : std_logic_vector(2 downto 0);

begin
    ----------------------------------------------------------------------------
    -- Receive Pulse Generation ------------------------------------------------
    --  The UART receive signal is used to generate edge pulses for the rest
    --      of the logic
    ----------------------------------------------------------------------------
    -- Double register incoming asynchronous receive signal and generate the
    --  rising and falling edge pulses
    rx_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx      <= '1';
            rx_r    <= '1';
            rx_rr   <= '1';
        elsif (rising_edge(CLK50_I)) then
            rx      <= RXD_I;
            rx_r    <= rx;
            rx_rr   <= rx_r;
        end if;
    end process rx_gen;
    rx_rise  <= rx_r and (not rx_rr);
    rx_fall  <= (not rx_r) and rx_rr;

    ----------------------------------------------------------------------------
    -- Bitrate Auto Detection --------------------------------------------------
    --  Examine the incoming receive signal and bitrate check indicators to
    --      determine the correct bitrate of the incoming serial data
    ----------------------------------------------------------------------------
    -- Adjust the detected bitrate based on two bitrate checks.  Bitrate check 1
    --  looks for multiple edges on the receive data between sample clocks
    --  indicating data is coming in at a higher bitrate than currently
    --  selected.  Bitrate check 2 verifies the stop bit, which may indicate the
    --  bitrate is set too high.  Bitrate check 1 will increment the detected
    --  bitrate, while bitrate check 2 will reset the bitrate back to the lowest
    --  setting.
    bitrate_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            bitrate             <= (others => '0');
        elsif (rising_edge(CLK50_I)) then
            if (AUTO_DETECT_I = '1') then
                if (bitrate_chk2 = '1') then
                    bitrate     <= (others => '0');
                elsif (bitrate_chk1 = b"11") then
                    bitrate     <= STD_LOGIC_VECTOR(UNSIGNED(bitrate) + 1);
                end if;
            else
                bitrate         <= BITRATE_I;
            end if;
        end if;
    end process bitrate_gen;

    -- Bitrate check 1 looks for multiple transitions within a single sample
    --  clock.  It is designed to pick up extra transitions at the start bit, by
    --  looking for a rising edge transition in a sample clock that already saw
    --  a falling edge.
    bitrate_chk1_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            bitrate_chk1            <= (others => '0');
        elsif (rising_edge(CLK50_I)) then
            if (rx_smpl_clk = '1' or bitrate_chk1 = b"11") then
                bitrate_chk1        <= (others => '0');
            else
                if (rx_fall = '1') then
                    bitrate_chk1(0) <= '1';
                end if;
                if (rx_rise = '1' and bitrate_chk1(0) = '1') then
                    bitrate_chk1(1) <= '1';
                end if;
            end if;
        end if;
    end process bitrate_chk1_gen;

    ----------------------------------------------------------------------------
    -- Receive Clock Generation ------------------------------------------------
    --  Generate the clock for receiving the serial data.
    ----------------------------------------------------------------------------
    -- Store the clock counter load value constant based on the bitrate
    rx_clk_load_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_clk_load         <= RX9600_C;
        elsif (rising_edge(CLK50_I)) then
            case bitrate is
                when b"000" =>
                    rx_clk_load <= RX1200_C;
                when b"001" =>
                    rx_clk_load <= RX2400_C;
                when b"010" =>
                    rx_clk_load <= RX4800_C;
                when b"011" =>
                    rx_clk_load <= RX9600_C;
                when b"100" =>
                    rx_clk_load <= RX19200_C;
                when b"101" =>
                    rx_clk_load <= RX38400_C;
                when b"110" =>
                    rx_clk_load <= RX57600_C;
                when b"111" =>
                    rx_clk_load <= RX115200_C;
                when others =>
                    rx_clk_load <= RX9600_C;
            end case;
        end if;
    end process rx_clk_load_gen;

    -- Generate the receive clock counter.  The counter is reset when the
    --  sample start indicator is set, indicating the falling edge of the start
    --  bit.  This creates deterministic timing from the falling edge of the
    --  start bit, which is the on time point for ascii time code references, to
    --  the point that we can check a received character and verify an on time
    --  point character.
    rx_clk_cnt_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_clk_cnt      <= RX9600_C;
        elsif (rising_edge(CLK50_I)) then
            if (UNSIGNED(rx_clk_cnt) = 0 or rx_smpl_start = '1') then
                rx_clk_cnt  <= rx_clk_load;
            else
                rx_clk_cnt  <= STD_LOGIC_VECTOR(UNSIGNED(rx_clk_cnt) - 1);
            end if;
        end if;
    end process rx_clk_cnt_gen;

    -- Generate the receive clock, which runs at 1/4th the bitrate, when the
    --  receive clock counter reaches zero
    rx_clk_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_clk      <= '0';
        elsif (rising_edge(CLK50_I)) then
            if (UNSIGNED(rx_clk_cnt) = 0) then
                rx_clk  <= '1';
            else
                rx_clk  <= '0';
            end if;
        end if;
    end process rx_clk_gen;

    -- Generate the sample clock counter.  The counter is reset when the sample
    --  start indicator is set when the start bit is detected.  It increments on
    --  the receive clock when the receive state machine is active.
    rx_smpl_cnt_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_smpl_cnt      <= (others => '1');
        elsif (rising_edge(CLK50_I)) then
            if (rx_smpl_start = '1') then
                rx_smpl_cnt  <= (others => '1');
            elsif (rx_clk = '1' and rx_actv = '1') then
                rx_smpl_cnt  <= STD_LOGIC_VECTOR(UNSIGNED(rx_smpl_cnt) - 1);
            end if;
        end if;
    end process rx_smpl_cnt_gen;

    -- Generate the sample clock, which runs at the bitrate, when the sample
    --  clock counter reaches two to center the sample clock within the received
    --  serial data bit
    rx_smpl_clk_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_smpl_clk      <= '0';
        elsif (rising_edge(CLK50_I)) then
            if (rx_clk = '1' and rx_smpl_cnt = b"10") then
                rx_smpl_clk  <= '1';
            else
                rx_smpl_clk  <= '0';
            end if;
        end if;
    end process rx_smpl_clk_gen;

    -- configure data_len for Receive State Machine
    data_len <= "111" when CHAR_LENGTH_I = "00" else -- 8 bits, end at 7
                "110" when CHAR_LENGTH_I = "01" else -- 7 bits, end at 6
                "101" when CHAR_LENGTH_I = "10" else -- 6 bits, end at 5
                "100" when CHAR_LENGTH_I = "11";     -- 5 bits, end at 4

    ----------------------------------------------------------------------------
    -- Receive State Machine --------------------------------------------------
    --  Controls the state of the receive line and controls signals for the
    --      receive UART.  The state machine flows as shown below:
    --
    --               --------------
    --           ---| WAIT_START_S |
    --          |    --------------
    --          |         | Start bit edge received
    --          |         v
    --          |    -----------
    --          |   | DATA_S    |<--\
    --          |    -----------    | loop until data_len+1
    --          |         |   |     | bits are received
    --          |         |   ------/
    --          |         |-------\
    --          |         v       |
    --          |    -----------  | skip parity state
    --          |   | PARITY_S  | | if no parity is selected
    --          |    -----------  |
    --          |         |       |
    --          |         |-------/
    --          |         |
    --          |         v
    --          |    -----------
    --          \---| STOP_S    |
    --               -----------
    ----------------------------------------------------------------------------
    rx_fsm : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            rx_bit_pos                      <= "000";
            rx_smpl_start                   <= '0';
            rx_actv                         <= '0';
            bitrate_chk2                    <= '0';
            data_valid                      <= '0';
            rx_reg                          <= (others => '0');
            rx_parity                       <= '0';
            parity_error                    <= '0';
            rx_state                        <= WAIT_START_S;
        elsif (rising_edge(CLK50_I)) then
            case rx_state is
                -- WAIT_START_S State (Waiting for Start Bit transition)
                when WAIT_START_S =>
                    rx_bit_pos <= "000";
                    -- Wait for falling edge of start bit
                    data_valid              <= '0';
                    bitrate_chk2            <= '0';
                    -- Set sample start and receive active on edge of start bit
                    if (rx_fall = '1') then
                        rx_smpl_start       <= '1';
                        rx_actv             <= '1';
                    else
                        rx_smpl_start       <= '0';
                    end if;
                    if (rx_smpl_clk = '1') then
                        -- Check for valid start bit
                        if (rx_r = '0') then
                            -- Clear receive register before new data
                            rx_reg          <= (others => '0');
                            parity_error    <= '0';
                            rx_parity       <= '0';
                            rx_state        <= DATA_S;
                        else
                            rx_actv         <= '0';
                        end if;
                    end if;
                -- receive Data Bits
                when DATA_S =>
                    -- Shift received serial data into data register
                    if (rx_smpl_clk = '1') then
                        rx_reg(to_integer(unsigned(rx_bit_pos))) <= rx_r;
                        -- current bit is XOR'd with Parity Bit
                        rx_parity            <= rx_parity xor rx_r;
                        if (rx_bit_pos = data_len) then
                            rx_bit_pos       <= "000";
                            -- PARITY_I(1) determines whether parity is active
                            if (PARITY_I(1) = '1') then
                                rx_state     <= PARITY_S;
                            else -- no parity
                                rx_state     <= STOP_S;
                            end if;
                            -- if not, do DATA_S again next time rx_smpl_clk = 1.
                        else
                            rx_bit_pos      <=
                                STD_LOGIC_VECTOR(UNSIGNED(rx_bit_pos) + 1);
                        end if;
                    end if;
                -- receive Parity bit
                when PARITY_S =>
                    -- PARITY_I(0) is even parity =>
                    --   rx_parity xor current_bit = 0 when parity is correct.
                    --   rx_parity xor current_bit xor PARITY(1) = 0.
                    -- PARITY_I(1) is odd parity =>
                    --   rx_parity xor current_bit = 1 when parity is correct.
                    --   rx_parity xor current_bit xor PARITY(1) = 0.

                    if (rx_smpl_clk = '1') then
                        parity_error        <= (rx_parity xor
                                                rx_r xor PARITY_I(0));
                        rx_state <= STOP_S;
                    end if;

                -- receive Stop bit
                when STOP_S =>
                    -- Clear receive active and transition to idle state
                    if (rx_smpl_clk = '1') then
                        -- Check for valid stop bit
                        if (rx_r /= '1') then
                            -- Set bitrate check 2 indicator
                            bitrate_chk2    <= '1';
                        else
                            -- Indicate valid data character on output
                            data_valid      <= '1';
                        end if;
                        rx_actv             <= '0';
                        rx_bit_pos          <= "000";
                        rx_state            <= WAIT_START_S;
                    end if;
                when others =>
                        rx_bit_pos          <= "000";
                        rx_parity           <= '0';
                        parity_error        <= '0';
                        rx_smpl_start       <= '0';
                        rx_actv             <= '0';
                        bitrate_chk2        <= '0';
                        data_valid          <= '0';
                        rx_reg              <= (others => '0');
                        rx_state            <= WAIT_START_S;
            end case;
        end if;
    end process rx_fsm;

    reg_out : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            DATA_VALID_O    <= '0';
            DATA_O          <= (others => '0');
        elsif (rising_edge(CLK50_I)) then
            DATA_VALID_O    <= '0';
            if (data_valid = '1') then
                DATA_VALID_O    <= '1';
                DATA_O          <= rx_reg;
            end if;
        end if;
    end process reg_out;

    ----------------------------------------------------------------------------
    -- Component Output Connections --------------------------------------------
    ----------------------------------------------------------------------------
    PARITY_ERROR_O  <= parity_error;
    BITRATE_O       <= bitrate;
end rtl;
