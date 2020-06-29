library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ALU is --Arithmetic Logic Unit
	generic(
		DATA_WIDTH  : natural := 16;  --16 Bits data
		ALUOP_WIDTH : natural := 3    --3 Bits operation ID
	);
	port(		
		AluSrcA   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input A
		AluSrcB   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input B
		
		AluOP 	 : in  std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
		
		AluComp   : out std_logic; --Input compare result
		AluRes    : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output Data
	);
end entity;

architecture ula of ALU is 
begin
	process(AluSrcA, AluSrcB, AluOP) --Process to be called if any of the inputs change
	begin
		if(AluOP = "001") then --ADD
			AluRes <= (AluSrcA + AluSrcB);
			AluComp <= '0';
		elsif(AluOP = "010") then --NOR
			AluRes <= NOT (AluSrcA OR AluSrcB);
			AluComp <= '0';
		elsif(AluOP = "011") then --AND
			AluRes <= (AluSrcA AND AluSrcB);
			AluComp <= '0';
	   elsif(AluOP = "100") then --Equals
			AluRes <= (others => '0');
			if(AluSrcA = AluSrcB) then AluComp <= '1';
			else AluComp <= '0';
			end if;		
		elsif(AluOP = "101") then --Signed Greater then
			AluRes <= (others => '0');
			if(signed(AluSrcA) > signed(AluSrcB)) then AluComp <= '1';
			else AluComp <= '0';
			end if;
		else --Else NOP
			AluRes <= (others => '0');
			AluComp <= '0';
		end if;
	end process;
end ula;