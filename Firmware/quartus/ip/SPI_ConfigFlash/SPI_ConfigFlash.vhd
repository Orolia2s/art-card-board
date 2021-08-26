--------------------------------------------------------------------------------
-- 
-- SPI_ConfigFlash : Connection of the serial FLASH of the ART_CARD FGPA.
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

entity SPI_ConfigFlash is
    port (
        -- General signals
        SCLK    : in    std_logic;
        MISO    : out   std_logic;
        MOSI    : in    std_logic;
        SS_n    : in    std_logic
    );
end entity SPI_ConfigFlash;

architecture A_SPI_ConfigFlash of SPI_ConfigFlash is

    component intel_generic_serial_flash_interface_asmiblock
    generic (
    DEVICE_FAMILY:      string  := "Arria 10";
    NCS_LENGTH:         integer := 3;
    DATA_LENGTH:        integer := 4;
    ENABLE_SIM_MODEL:   string  := "false"
    );
    port (
    atom_ports_dclk     : in    std_logic;
    atom_ports_ncs      : in    std_logic_vector(NCS_LENGTH-1 downto 0);
    atom_ports_oe       : in    std_logic;
    atom_ports_dataout  : in    std_logic_vector(DATA_LENGTH-1 downto 0);
    atom_ports_dataoe   : in    std_logic_vector(DATA_LENGTH-1 downto 0);

    atom_ports_datain   : out   std_logic_vector(DATA_LENGTH-1 downto 0)
    );
    end component;

    signal ncs      : std_logic_vector(2 downto 0);
    signal oe       : std_logic;
    signal dataout  : std_logic_vector(3 downto 0);
    signal dataoe   : std_logic_vector(3 downto 0);
    signal datain   : std_logic_vector(3 downto 0);

begin

    ncs <= "11" & SS_n;
    oe  <= '0';                 -- Active-low signal to enable DCLK and nCSO pins to reach the flash
    dataout <= "110" & MOSI;    -- data0out = FPGA design data to the EPCS through the AS_DATA0 pin
    dataoe  <= "1101";          -- Controls data pin either as input or output because the dedicated pins for active serial data is bidirectional
                                -- '0' : input
                                -- '1' : output

                                -- data0oe = 1'b1
                                -- data1oe = 1'b0
                                -- data2oe = 1'b1
                                -- data3oe = 1'b1
    MISO <= datain(1);
    -- Signal from the AS data pin to your FPGA design
    -- data0in = don't care
    -- data1in = EPCS device data to your FPGA design through the AS_DATA1 pin.
    -- data2in = don't care
    -- data3in = don't care


    flash_c10gx: intel_generic_serial_flash_interface_asmiblock
    generic map (
        DEVICE_FAMILY   => "Cyclone 10 GX",
        NCS_LENGTH      => 3,
        DATA_LENGTH     => 4,
        ENABLE_SIM_MODEL    => "false"
        )
    port map (
    atom_ports_dclk     => SCLK,
    atom_ports_ncs      => ncs,
    atom_ports_oe       => oe,
    atom_ports_dataout  => dataout,
    atom_ports_dataoe   => dataoe,

    atom_ports_datain   => datain
    );

end architecture A_SPI_ConfigFlash;

