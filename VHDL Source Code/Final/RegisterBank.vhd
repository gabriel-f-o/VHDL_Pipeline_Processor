library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity RegisterBank is --Cache memory (8 regiters wide)
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		RADD_WIDTH : natural := 3   --3 Bits register bank address
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset 
		WriteEn   : in  std_logic; --Write on address in write address
		
		addrR1 	 : in  std_logic_vector((RADD_WIDTH-1) downto 0); --R1 read address
		addrR2 	 : in  std_logic_vector((RADD_WIDTH-1) downto 0); --R2 read address
		writeAddr : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Address to write
		
		WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
		
		RegR1Data : out std_logic_vector((DATA_WIDTH-1) downto 0); --Register 1 out
		RegR2Data : out std_logic_vector((DATA_WIDTH-1) downto 0)  --Register 2 out
	);
end entity;

architecture regBk of RegisterBank is 

	type reg is array (0 to 2**RADD_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0); --Typedef to define "reg" as an array of length 2^(addr)
	
	signal registerBank : reg;
	
	signal addrR1Nat 	  : natural range 0 to (2**RADD_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	signal addrR2Nat 	  : natural range 0 to (2**RADD_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	signal writeAddrNat : natural range 0 to (2**RADD_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	
begin
	addrR1Nat    <= to_integer(unsigned(addrR1));
	addrR2Nat    <= to_integer(unsigned(addrR2));
	writeAddrNat <= to_integer(unsigned(writeAddr));

	RegR1Data <= registerBank(addrR1Nat); --Update both outputs with the addresses indicated in addrR1 and addrR2
	RegR2Data <= registerBank(addrR2Nat);
				
	process(clock, reset) --Process to be triggered only when clock or reset changes
	begin
		if(reset = '1') then --If reset is set
			registerBank <= (others => (others => '0')); --Set every bit of every register to 0
		elsif(rising_edge(clock)) then --Clock rises
			if(WriteEn = '1') then --If write is enabled
				if(writeAddrNat /= 0) then --If address to write is not 0
					registerBank(writeAddrNat) <= WriteData; --Writes the content in the position indicated with writeAddr
				else
					registerBank(0) <= (others => '0'); --Otherwise, keep it 0

				end if;
			end if;
		end if;
	end process;
end regBk;