--------------------------------------------------------------------------------
--
-- IDBoard : Access to the ID register of the Cyclone 10 GX
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

entity IDBoard is
    port (
        RST_I:      in   std_logic;
        CLK_I:      in   std_logic;
        ADDR_I:     in   std_logic_vector(3 downto 0);
        DATA_O:     out  std_logic_vector(31 downto 0);
        RD_I:       in   std_logic;

        ID_PIN:     in   std_logic_vector(3 downto 0);
        ID_OSC_PIN: in   std_logic_vector(3 downto 0);

        RST_O:      out  std_logic;
        data_valid: in   std_logic;
        chip_id:    in   std_logic_vector(63 downto 0)
        );
    end IDBoard;

architecture rtl_IDBoard of IDBoard is

    -- Address Decoding
    constant    CST_ADDR_ID_MSB:    std_logic_vector(3 downto 0) := x"0";
    constant    CST_ADDR_ID_LSB:    std_logic_vector(3 downto 0) := x"1";
    constant    CST_ADDR_ID_REV:    std_logic_vector(3 downto 0) := x"2";
    constant    CST_ADDR_ID_OSC:    std_logic_vector(3 downto 0) := x"3";

    signal ID_MSB : std_logic_vector(31 downto 0);
    signal ID_LSB : std_logic_vector(31 downto 0);
    signal ID_REV : std_logic_vector(3 downto 0);
    signal ID_OSC : std_logic_vector(3 downto 0);
    signal RST_ID: std_logic;
    signal rst_cpt: unsigned(4 downto 0);

begin

    --Need at least 10 Reset cycles
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            rst_cpt <= (others => '0');
            RST_ID <= '1';
        elsif rising_edge(CLK_I) then
            RST_ID <= '1';
            if (rst_cpt(4) = '0') then
                rst_cpt <= rst_cpt + 1;
            else
                RST_ID <= '0';
            end if;
        end if;
    end process;
	RST_O <= RST_ID;

    -- CPU access
    -------------
    process (RST_I, CLK_I)
    begin
        if (RST_I = '1') then
            ID_LSB <= (others => '0');
            ID_MSB <= (others => '0');
            ID_REV <= (others => '0');
            ID_OSC <= (others => '0');
            DATA_O <= (others => '0');
        elsif rising_edge(CLK_I) then
            DATA_O <= (others => '0');
            ID_REV <= ID_PIN;
            ID_OSC <= ID_OSC_PIN;
            if (data_valid = '1') then
                ID_MSB <= chip_id(63 downto 32);
                ID_LSB <= chip_id(31 downto 0);
            end if;
            if (RD_I = '1') then
                case ADDR_I is
                    when CST_ADDR_ID_MSB =>
                        DATA_O <= ID_MSB;
                    when CST_ADDR_ID_LSB =>
                        DATA_O <= ID_LSB;
                    when CST_ADDR_ID_REV =>
                        DATA_O <= x"0000000" & ID_REV;
                    when CST_ADDR_ID_OSC =>
                        DATA_O <= x"0000000" & ID_OSC;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

end rtl_IDBoard;