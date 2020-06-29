library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity BasicRegister is --Normal register (sensible to rising clock edge)
	generic(
		DATA_WIDTH : natural := 16 --16 Bits data
	);
	port(		
		clock     : in  std_logic; 
		reset     : in  std_logic;
		RegWrite   : in  std_logic;
		
		RegIn      : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
				
		RegOut     : out std_logic_vector((DATA_WIDTH-1) downto 0)  --Output Data
	);
end entity;

architecture baReg of BasicRegister is 

begin
	process(clock, reset) --Process called only when clock or reset changes
	begin
		if(reset = '1') then --When reset is triggered
			RegOut <= (others => '0');	--Set output to 0
		elsif(rising_edge(clock)) then --When clock rises
			if(RegWrite = '1') then --If Write is enabled, update output
				RegOut <= RegIn;
			end if;
		end if;
	end process;
end baReg;