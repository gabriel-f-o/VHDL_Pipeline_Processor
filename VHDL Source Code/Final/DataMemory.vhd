library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity DataMemory is --Ram memory, for simplicity sake, we'll keep only 4 regiters
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		ADDR_WIDTH : natural := 2   --2 Bits RAM address
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset 
		WriteEn   : in  std_logic; --Write on address
		
		addrSel 	 : in  std_logic_vector((ADDR_WIDTH-1) downto 0); --Selecs Address
		WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
		
		RegData   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
	);
end entity;

architecture datMem of DataMemory is

	type dataRegister is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0); --Typedef to define "dataRegister" as an array of length 2^(addr)

	signal RAMDataMemory : dataRegister; --Declare intruction reg bank
	
	signal addrSelNat 	: natural range 0 to (2**ADDR_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	
begin
	addrSelNat <= to_integer(unsigned(addrSel)); --Converts std_logic_vector to natural
	RegData <= RAMDataMemory(addrSelNat); --Update output no matter what (asynch)
	
	process(clock, reset) --Process to be executed when reset and clock changes
	begin
		if(reset = '1') then --Reset to default state
			RAMDataMemory <= (others => (others => '0')); --Rest of Memory goes to 0			
		elsif(rising_edge(clock)) then --On clock rising edge
			if(WriteEn = '1') then --If write enabled
				RAMDataMemory(addrSelNat) <= WriteData;
			end if;
		end if;
	end process;
end datMem;