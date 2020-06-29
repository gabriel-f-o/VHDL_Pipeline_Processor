library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity customExtend is --Custom extend, if mode = 0 -> zero extend, if mode = 1 -> sign extend
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		INPUT_WIDTH : natural := 6  --6 Bits input data
	);
	port(
		modeIn		 : in  std_logic; --Mode
		dataIn		 : in  std_logic_vector((INPUT_WIDTH-1) downto 0); --Input data
		extendedData : out std_logic_vector((DATA_WIDTH-1) downto 0) 	--Output data
	);
end entity;

architecture cstEx of customExtend is 
	
begin
	process(dataIn, modeIn) --Process called if mode or data in changes
	begin
		if(dataIn(INPUT_WIDTH-1) = '1' and modeIn = '1') then --If first bit is '1' and mode is sign extend
			extendedData((DATA_WIDTH-1) downto INPUT_WIDTH) <= (others => '1'); --Fill MSBs with 1
		else
			extendedData((DATA_WIDTH-1) downto INPUT_WIDTH) <= (others => '0'); --Else, fill with 0
		end if;
		
		extendedData((INPUT_WIDTH-1) downto 0) <= dataIn; --Data comes at the LSBs
	end process;
end cstEx;