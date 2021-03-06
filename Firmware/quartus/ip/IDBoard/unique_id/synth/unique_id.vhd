-- unique_id.vhd

-- Generated using ACDS version 21.1 169

library IEEE;
library altera_c10gx_chip_id_191;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity unique_id is
	port (
		clkin      : in  std_logic                     := '0'; --  clkin.clk
		reset      : in  std_logic                     := '0'; --  reset.reset
		data_valid : out std_logic;                            -- output.valid
		chip_id    : out std_logic_vector(63 downto 0)         --       .data
	);
end entity unique_id;

architecture rtl of unique_id is
	component altera_c10gx_chip_id_cmp is
		port (
			clkin      : in  std_logic                     := 'X'; -- clk
			reset      : in  std_logic                     := 'X'; -- reset
			data_valid : out std_logic;                            -- valid
			chip_id    : out std_logic_vector(63 downto 0)         -- data
		);
	end component altera_c10gx_chip_id_cmp;

	for c10gx_chip_id_0 : altera_c10gx_chip_id_cmp
		use entity altera_c10gx_chip_id_191.altera_c10gx_chip_id;
begin

	c10gx_chip_id_0 : component altera_c10gx_chip_id_cmp
		port map (
			clkin      => clkin,      --  clkin.clk
			reset      => reset,      --  reset.reset
			data_valid => data_valid, -- output.valid
			chip_id    => chip_id     --       .data
		);

end architecture rtl; -- of unique_id
