library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ALU is --Arithmetic Logic Unit
	generic(
		DATA_WIDTH  : natural := 16;  --16 Bits data
		ALUOP_WIDTH : natural := 3 --3 Bits operation ID
	);
	port(		
		inputA    : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input A
		inputB    : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input B
		
		aluOP 	 : in  std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
		
		aluComp   : out std_logic; --Input compare result
		aluRes    : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output Data
	);
end entity;

architecture ula of ALU is 
begin
	process(inputA, inputB, aluOP) --Process to be called if any of the inputs change
	begin
		if(aluOP = "001") then --ADD
			aluRes <= (inputA + inputB);
			aluComp <= '0';
		elsif(aluOP = "010") then --NOR
			aluRes <= NOT (inputA OR inputB);
			aluComp <= '0';
		elsif(aluOP = "011") then --AND
			aluRes <= (inputA AND inputB);
			aluComp <= '0';
	   elsif(aluOP = "100") then --Equals
			aluRes <= (others => '0');
			if(inputA = inputB) then aluComp <= '1';
			else aluComp <= '0';
			end if;		
		elsif(aluOP = "101") then --Greater then
			aluRes <= (others => '0');
			if(inputA > inputB) then aluComp <= '1';
			else aluComp <= '0';
			end if;
		else --Else NOP
			aluRes <= (others => '0');
			aluComp <= '0';
		end if;
	end process;
end ula;