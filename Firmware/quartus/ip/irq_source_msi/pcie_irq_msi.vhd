--------------------------------------------------------------------------------
-- 
-- pcie_irq_msi : PCIe IRQ management of the ART_CARD FGPA.
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

entity pcie_irq_msi is
port
    (
    CLK_I               : in    std_logic;
    RST_I               : in    std_logic;

    -- Input IRQ
    IRQ_I               : in    std_logic_vector(15 downto 0)    := x"0000";

    -- MSI/MSI-X input from PCIe IP
    MSIINTFC_I          : in  std_logic_vector(81 downto 0);
    MSIXINTFC_I         : in  std_logic_vector(15 downto 0);
    INTXREQ_O           : out std_logic;
    INTXACK_I           : in  std_logic;

    -- Txs Master Interface
    TXS_WRITE_O         : out std_logic;
    TXS_ADDRESS_O       : out std_logic_vector(31 downto 0);
    TXS_WRITEDATA_O     : out std_logic_vector(63 downto 0);
    TXS_BYTEENABLE_O    : out std_logic_vector(7 downto 0);
    TXS_WAITREQUEST_I   : in  std_logic

    );
end pcie_irq_msi;


architecture A_pcie_irq_msi of pcie_irq_msi is

    signal s_master_enable: std_logic;
    signal s_msi_enable:    std_logic;
    signal s_msi_data:      std_logic_vector(15 downto 0);
    signal s_msi_address:   std_logic_vector(63 downto 0);

    signal txs_address:     std_logic_vector(31 downto 0);
    signal txs_data:        std_logic_vector(63 downto 0);
    signal txs_write:       std_logic;
    signal txs_byteenable:  std_logic_vector(7 downto 0);

    signal s_irq:           std_logic_vector(15 downto 0);
    signal s_irq_r:         std_logic_vector(15 downto 0);
    signal s_irq_rr:        std_logic_vector(15 downto 0);
    signal s_act_irq:       std_logic_vector(15 downto 0);
    signal s_req:           std_logic_vector(15 downto 0);
    signal s_req_data:      std_logic_vector(3 downto 0);

    constant TIME_IRQ_C:    unsigned(15 downto 0) := x"1D4C";  -- 8ns * 7500 = 60us
    constant TIME_IRQ_MAX_C:unsigned(15 downto 0) := x"6000";
    constant TIME_IRQ_RET_C:unsigned(15 downto 0) := x"6010";
    signal cpt_time_irq:    unsigned(15 downto 0);
    signal top_time_irq:    std_logic;

    signal time_err:        std_logic;

begin

    s_master_enable <= MSIINTFC_I(81);
    s_msi_enable    <= MSIINTFC_I(80);
    s_msi_data      <= MSIINTFC_I(79 downto 64);
    s_msi_address   <= MSIINTFC_I(63 downto 0);

--  s_msix_enable   <= MSIXINTFC_I(15);
--  s_msix_mask     <= MSIXINTFC_I(14);
--  s_msix_tb_size  <= MSIXINTFC_I(10 downto 0);


    -- Register Input IRQ
    process(CLK_I, RST_I)
    begin
        if (RST_I = '1') then
            s_irq <= (others => '0');
            s_irq_r <= (others => '0');
            s_irq_rr <= (others => '0');
        elsif rising_edge(CLK_I) then
            s_irq <= IRQ_I;
            s_irq_r <= s_irq;
            s_irq_rr <= s_irq_r;
        end if;
    end process;

    -- Detect IRQ rising
    process(CLK_I, RST_I)
    begin
        if (RST_I = '1') then
            s_req <= (others => '0');
            s_req_data <= x"0";
        elsif rising_edge(CLK_I) then
            if (s_master_enable = '1') and (s_msi_enable = '1') then
                -- irq0 first
                if (s_act_irq(0) = '0') and (s_irq_rr(0) = '1') then
                    s_req <= x"0001";
                    s_req_data <= x"0";
                elsif (s_act_irq(1) = '0') and (s_irq_rr(1) = '1') then
                    s_req <= x"0002";
                    s_req_data <= x"1";
                elsif (s_act_irq(2) = '0') and (s_irq_rr(2) = '1') then
                    s_req <= x"0004";
                    s_req_data <= x"2";
--                elsif (s_act_irq(3) = '0') and (s_irq_rr(3) = '1') then
                elsif (s_act_irq(3) = '0') and (top_time_irq = '1') and (time_err = '0') then
                    s_req <= x"0008";
                    s_req_data <= x"3";
                elsif (s_act_irq(4) = '0') and (s_irq_rr(4) = '1') then
                    s_req <= x"0010";
                    s_req_data <= x"4";
                elsif (s_act_irq(5) = '0') and (s_irq_rr(5) = '1') then
                    s_req <= x"0020";
                    s_req_data <= x"5";
                elsif (s_act_irq(6) = '0') and (s_irq_rr(6) = '1') then
                    s_req <= x"0040";
                    s_req_data <= x"6";
                elsif (s_act_irq(7) = '0') and (s_irq_rr(7) = '1') then
                    s_req <= x"0080";
                    s_req_data <= x"7";
                elsif (s_act_irq(8) = '0') and (s_irq_rr(8) = '1') then
                    s_req <= x"0100";
                    s_req_data <= x"8";
                elsif (s_act_irq(9) = '0') and (s_irq_rr(9) = '1') then
                    s_req <= x"0200";
                    s_req_data <= x"9";
                elsif (s_act_irq(10) = '0') and (s_irq_rr(10) = '1') then
                    s_req <= x"0400";
                    s_req_data <= x"A";
                elsif (s_act_irq(11) = '0') and (s_irq_rr(11) = '1') then
                    s_req <= x"0800";
                    s_req_data <= x"B";
                elsif (s_act_irq(12) = '0') and (s_irq_rr(12) = '1') then
                    s_req <= x"1000";
                    s_req_data <= x"C";
                elsif (s_act_irq(13) = '0') and (s_irq_rr(13) = '1') then
                    s_req <= x"2000";
                    s_req_data <= x"D";
                elsif (s_act_irq(14) = '0') and (s_irq_rr(14) = '1') then
                    s_req <= x"4000";
                    s_req_data <= x"E";
                elsif (s_act_irq(15) = '0') and (s_irq_rr(15) = '1') then
                    s_req <= x"8000";
                    s_req_data <= x"F";
                else
                    s_req <= x"0000";
                    s_req_data <= x"0";
                end if;
            else
                s_req <= x"0000";
                s_req_data <= x"0";
            end if;
        end if;
    end process;

    -- wait time before address UART IRQ
    process(CLK_I, RST_I)
    begin
        if (RST_I = '1') then
            cpt_time_irq <= (others => '0');
            top_time_irq <= '0';
            time_err <= '0';
        elsif rising_edge(CLK_I) then
            if (s_irq_rr(3) = '0') then
                time_err <= '0';
                top_time_irq <= '0';
                cpt_time_irq <= (others => '0');
            else
                cpt_time_irq <= cpt_time_irq + 1;
                if (cpt_time_irq = TIME_IRQ_C) then
                    top_time_irq <= '1';
                end if;
                if (cpt_time_irq = TIME_IRQ_MAX_C) then
                    time_err <= '1';
                end if;
                if (cpt_time_irq = TIME_IRQ_RET_C) then
                    time_err <= '0';
                    top_time_irq <= '0';
                    cpt_time_irq <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- Send Message
    process(CLK_I, RST_I)
    begin
        if (RST_I = '1') then
            txs_address <= (others => '0');
            txs_data <= (others => '0');
            txs_write <= '0';
            txs_byteenable <= (others => '0');
            s_act_irq <= (others => '0');
        elsif rising_edge(CLK_I) then
            --unset irqs
            s_act_irq <= s_act_irq and (s_irq_rr(15 downto 4) & top_time_irq & s_irq_rr(2 downto 0));
            txs_write <= txs_write and TXS_WAITREQUEST_I;
            if (s_master_enable = '1') and (s_msi_enable = '1') then
                txs_address <= s_msi_address(31 downto 0);
                if (s_req /= x"0000") and (txs_write = '0') then
                    txs_write <= '1';
                    txs_byteenable <= x"0F";
                    txs_data <= x"00000000" & x"0000" & s_msi_data(15 downto 4) & s_req_data;
                    s_act_irq <= s_act_irq or s_req;
                end if;
            end if;
        end if;
    end process;

    TXS_ADDRESS_O    <= txs_address;
    TXS_WRITEDATA_O  <= txs_data;
    TXS_WRITE_O      <= txs_write;
    TXS_BYTEENABLE_O <= txs_byteenable;

    INTXREQ_O <= '0';

end A_pcie_irq_msi;
