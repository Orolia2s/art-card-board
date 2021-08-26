--------------------------------------------------------------------------------
-- 
-- uart_tx : UART transmitter driver of the ART_CARD FGPA.
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

entity uart_tx is
    generic (
        g_freq_in   :    integer := 50000000
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
end uart_tx;

architecture rtl of uart_tx is

    ----------------------------------------------------------------------------
    -- Constant Declarations ---------------------------------------------------
    ----------------------------------------------------------------------------
    -- Bitrate counter constants
    constant    TX1200_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/1200,16));    --x"A2C2";
    constant    TX2400_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/2400,16));    --x"5160";
    constant    TX4800_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/4800,16));    --x"28B0";
    constant    TX9600_C    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/9600,16));    --x"1457";
    constant    TX19200_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/19200,16));   --x"0A2B";
    constant    TX38400_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/38400,16));   --x"0515";
    constant    TX57600_C   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/57600,16));   --x"0363";
    constant    TX115200_C  : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(g_freq_in/115200,16));  --x"01B1";

    ----------------------------------------------------------------------------
    -- Signal Declarations -----------------------------------------------------
    ----------------------------------------------------------------------------

    type    tx_state_typ is (WAIT_START_S,
                             DATA_S,
                             PARITY_S,
                             STOP_S,
                             RESET_S);

    signal  tx_state    : tx_state_typ;


    signal  tx_clk      : std_logic;
    signal  tx_clk_load : std_logic_vector(15 downto 0);
    signal  tx_clk_cnt  : std_logic_vector(15 downto 0);
    signal  tx_bit_pos  : std_logic_vector(2 downto 0);
    signal  tx_reg      : std_logic_vector(7 downto 0);
    signal  tx_busy     : std_logic;
    signal  txd         : std_logic;

    signal  tx_parity   : std_logic;
    signal  data_len    : std_logic_vector(2 downto 0);

begin
        ----------------------------------------------------------------------------
    -- Transmit Clock Generation -----------------------------------------------
    --  Generate the clock for transmitting the serial data.
    ----------------------------------------------------------------------------
    -- Store the clock counter load value constant based on the bitrate selected
    tx_clk_load_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            tx_clk_load         <= TX9600_C;
        elsif (rising_edge(CLK50_I)) then
            case BITRATE_I is
                when b"000" =>
                    tx_clk_load <= TX1200_C;
                when b"001" =>
                    tx_clk_load <= TX2400_C;
                when b"010" =>
                    tx_clk_load <= TX4800_C;
                when b"011" =>
                    tx_clk_load <= TX9600_C;
                when b"100" =>
                    tx_clk_load <= TX19200_C;
                when b"101" =>
                    tx_clk_load <= TX38400_C;
                when b"110" =>
                    tx_clk_load <= TX57600_C;
                when b"111" =>
                    tx_clk_load <= TX115200_C;
                when others =>
                    tx_clk_load <= TX9600_C;
            end case;
        end if;
    end process tx_clk_load_gen;

    -- Generate the transmit clock counter, which runs at the bitrate.  The
    --  counter is held in reset while in the idle state to create deterministic
    --  timing from data valid input while in idle state to the falling edge of
    --  the start bit.
    tx_clk_cnt_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            tx_clk_cnt      <= TX9600_C;
        elsif (rising_edge(CLK50_I)) then
            if (UNSIGNED(tx_clk_cnt) = 0 or tx_busy = '0') then
                tx_clk_cnt  <= tx_clk_load;
            else
                tx_clk_cnt  <= STD_LOGIC_VECTOR(UNSIGNED(tx_clk_cnt) - 1);
            end if;
        end if;
    end process tx_clk_cnt_gen;

    -- Generate the clock pulse when the clock counter reaches zero
    tx_clk_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            tx_clk      <= '0';
        elsif (rising_edge(CLK50_I)) then
            if (UNSIGNED(tx_clk_cnt) = 0) then
                tx_clk  <= '1';
            else
                tx_clk  <= '0';
            end if;
        end if;
    end process tx_clk_gen;

    -- configure data_len for Transmit State Machine
    data_len <= "111" when CHAR_LENGTH_I = "00" else -- 8 bits, end at 7
                "110" when CHAR_LENGTH_I = "01" else -- 7 bits, end at 6
                "101" when CHAR_LENGTH_I = "10" else -- 6 bits, end at 5
                "100" when CHAR_LENGTH_I = "11";     -- 5 bits, end at 4

    ----------------------------------------------------------------------------
    -- Transmit State Machine --------------------------------------------------
    --  Controls the state of the transmit line and controls signals for the
    --      transmit UART.  The state machine flows as shown below:
    --
    --               --------------
    --           ---| WAIT_START_S |
    --          |    --------------
    --          |         | DATA_VALID_I = '1'
    --          |         v
    --          |    -----------
    --          |   | DATA_S    |<--\
    --          |    -----------    | loop until data_len+1
    --          |         |   |     | bits are transmitted
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
    --          |   | STOP_S    |
    --          |    -----------
    --          |         |
    --          |         v
    --          |    ----------
    --           ---| RESET_S  |
    --               ----------
    ----------------------------------------------------------------------------
    tx_fsm_gen : process (CLK50_I, RST_I)
    begin
        if (RST_I = '1') then
            tx_busy                     <= '0';
            tx_reg                      <= (others => '0');
            txd                         <= '1';
            tx_bit_pos                  <= "000";
            tx_state                    <= WAIT_START_S;
            tx_parity                   <= '0';
        elsif (rising_edge(CLK50_I)) then
            case tx_state is
                -- WAIT_START_S State (waiting for DATA_VALID)
                -- sends Start bit immediately when DATA_VALID_I is asserted
                when WAIT_START_S =>
                    -- Send start bit, load data register, set busy signal
                    if (DATA_VALID_I = '1') then
                        tx_busy         <= '1';
                        tx_reg          <= DATA_I;
                        txd             <= '0';
                        tx_bit_pos      <= "000";
                        tx_state        <= DATA_S;
                        tx_parity       <= '0'; -- parity is reset
                    else -- DATA_VALID_I = '0'
                        tx_busy         <= '0';
                        txd             <= '1';
                        tx_bit_pos      <= "000";
                        tx_state        <= WAIT_START_S;
                    end if;
                -- sends Data bits
                when DATA_S =>
                    tx_busy <= '1';
                    -- Send current bit and shift data register
                    if (tx_clk = '1') then
                        tx_reg          <= '0' & tx_reg(7 downto 1);
                        txd             <= tx_reg(0);
                        -- current bit is XOR'd with parity bit.
                        tx_parity       <= tx_parity xor tx_reg(0);
                        -- check to see if we've sent enough bits
                        if (tx_bit_pos = data_len) then
                            tx_bit_pos <= "000";
                            -- PARITY_I(1) determines whether parity is active
                            if (PARITY_I(1) = '1') then
                                tx_state <= PARITY_S;
                            else -- no parity
                                tx_state <= STOP_S;
                            end if;
                        -- if not, do DATA_S again next time tx_clk = 1.
                        else
                            tx_bit_pos      <=
                                STD_LOGIC_VECTOR(UNSIGNED(tx_bit_pos) + 1);
                        end if;
                    end if;
                -- send parity bit
                when PARITY_S =>
                    tx_busy <= '1';
                    -- PARITY_I(0) is even parity = current value of tx_parity
                    -- PARITY_I(0) is odd parity  = inverse value of tx_parity
                    if (tx_clk = '1') then
                        txd      <= tx_parity xor PARITY_I(0);
                        tx_state <= STOP_S;
                    end if;
                -- Send Stop Bit
                when STOP_S =>
                    tx_busy <= '1';
                    if (tx_clk = '1') then
                        txd             <= '1';
                        tx_state        <= RESET_S;
                    end if;
                -- after Stop bit is over,
                -- clear busy, and go immediately to WAIT_START_S
                -- // go immediately to WAIT_START_S
                when RESET_S =>
--                    tx_busy <= '1';
                    if (tx_clk = '1') then
                        tx_busy         <= '0';
                        tx_parity       <= '0'; -- reset parity
                        tx_state        <= WAIT_START_S;
                    end if;
                when others =>
                    tx_busy             <= '0';
                    tx_reg              <= (others => '0');
                    txd                 <= '1';
                    tx_bit_pos          <= "000";
                    tx_parity           <= '0';
                    tx_state            <= WAIT_START_S;
            end case;
        end if;
    end process tx_fsm_gen;


    ----------------------------------------------------------------------------
    -- Component Output Connections --------------------------------------------
    ----------------------------------------------------------------------------
    TXD_O   <= txd;
    BUSY_O  <= tx_busy;
end rtl;
