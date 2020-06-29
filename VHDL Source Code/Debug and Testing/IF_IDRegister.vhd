library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity IF_IDRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
		OP_WIDTH	  : natural := 4; --OP width
		FS_WIDTH	  : natural := 3; --First segment width
		SS_WIDTH	  : natural := 3; --Second segment width
		LS_WIDTH   : natural := 6; --Last segment width
		DATA_WIDTH : natural := 16 --16 Bits data	
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset
		WriteEn   : in  std_logic;
		
		RegIn     : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
				
		OP			 : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
		firstSeg	 : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
		secondSeg : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
		lastSeg	 : out std_logic_vector((LS_WIDTH-1) downto 0)	--Last 6 bits
	);
end entity;

architecture ifId of IF_IDRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			OP 		 <= (others => '0');
			firstSeg  <= (others => '0');
			secondSeg <= (others => '0');
			lastSeg 	 <= (others => '0');
	
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				lastSeg 	 <= RegIn((LS_WIDTH-1) downto 0); --0 to 5
				secondSeg <= RegIn((SS_WIDTH-1 + LS_WIDTH) downto LS_WIDTH); -- 6 to 8
				firstSeg  <= RegIn((FS_WIDTH-1 + SS_WIDTH + LS_WIDTH) downto (SS_WIDTH + LS_WIDTH)); -- 9 to 11
				OP 		 <= RegIn((DATA_WIDTH-1) downto (DATA_WIDTH - OP_WIDTH)); --12 to 15
			end if;
		end if;
		
	end process;
end ifId;