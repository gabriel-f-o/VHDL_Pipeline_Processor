library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity DataMemory is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		ADDR_WIDTH : natural := 4   --6 Bits RAM address
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset 
		WriteEn   : in  std_logic; --Write on address
		
		addrIn 	 : in  std_logic_vector((ADDR_WIDTH-1) downto 0); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
		WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
		
		DataOut   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
	);
end entity;

architecture datMem of DataMemory is

	type dataRegister is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0); --Typedef to define "dataRegister" as an array of length 2^(addr)

	signal DataMemory : dataRegister; --Declare intruction reg bank
	
	signal addrInNat 	: natural range 0 to (2**ADDR_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	
begin
	addrInNat <= to_integer(unsigned(addrIn));
	DataOut <= DataMemory(addrInNat); --Update output
	
	process(clock, reset) --Process to be executed when reset and clock changes
	begin
		if(reset = '1') then --Reset to default state
			--DataMemory <= (others => (others => '0')); --Rest of Memory goes to 0			
			DataMemory <= (2 => x"0020", 3 => x"0021", others => (others => '0')); --Rest of Memory goes to 0			
		elsif(rising_edge(clock)) then --On clock rising edge
			if(WriteEn = '1') then --If write enabled
				DataMemory(addrInNat) <= WriteData;
			end if;
		end if;
	end process;
end datMem;