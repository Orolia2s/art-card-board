	component unique_id is
		port (
			clkin      : in  std_logic                     := 'X'; -- clk
			reset      : in  std_logic                     := 'X'; -- reset
			data_valid : out std_logic;                            -- valid
			chip_id    : out std_logic_vector(63 downto 0)         -- data
		);
	end component unique_id;

	u0 : component unique_id
		port map (
			clkin      => CONNECTED_TO_clkin,      --  clkin.clk
			reset      => CONNECTED_TO_reset,      --  reset.reset
			data_valid => CONNECTED_TO_data_valid, -- output.valid
			chip_id    => CONNECTED_TO_chip_id     --       .data
		);

