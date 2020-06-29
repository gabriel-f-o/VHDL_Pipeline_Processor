library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity InstructionMemory is --Instruction memory, for simplicity sake, we'll keep only 16 regiters
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		INST_WIDTH : natural := 4   --4 Bits instruction address
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset 
		WriteEn   : in  std_logic; --Write on address
		
		addrSel 	 : in  std_logic_vector((INST_WIDTH-1) downto 0); --Selecs Address
		WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
		
		RegData   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
	);
end entity;

architecture instMem of InstructionMemory is

	type dataRegister is array (0 to 2**INST_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0); --Typedef to define "dataRegister" as an array of length 2^(addr)

	signal InstructionBank : dataRegister; --Declare intruction reg bank
	
	signal addrInNat : natural range 0 to (2**INST_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	
begin
	addrInNat <= to_integer(unsigned(addrSel)); --Convertion
	RegData <= InstructionBank(addrInNat); --Update output no matter what
	
	process(clock, reset) --Process to be executed when reset or clock changes
	begin
		if(reset = '1') then --Reset to default state
			InstructionBank <= 
			(
				0  => "0010000001010110", --ADDI $R1, $ZERO, 22  // i = 22
				1  => "0010000010111110", --ADDI $R2, $ZERO, -2  // j = -2
				2  => "0010000011010000", --ADDI $R3, $ZERO, 16  // k = 16
				3  => "0010000100000000", --ADDI $R4, $ZERO, 0   // input = 0
				4  => "0010000101000000", --ADDI $R5, $ZERO, 0   // output = 0
				5  => "0010000111000010", --ADDI $TEMP(R7), $ZERO, 2 // temp = 2
				6  => "0101100111001101", --BEQ  $R4, $TEMP(R7), END(13) //if(input == temp) goto 13
				7  => "1100100011001010", --BGT $R4, $R3, IF(10) //if(entrada > k) goto 10
				8  => "0001001101000101", --ADD $R5, $R5, $R1 //output += i;
				9  => "0110000000001011", --JUMP ENDIF(11)
				10 => "0001010101000101", --ADD $R5, $R5, $R2
				11 => "1001000100000000", --IN $R4
				12 => "0110000000000110", --JUMP LOOP(6)
				13 => "1010000101000000", --OUT $R5
				14 => "0110000000001101", --JUMP 13
	
				others => (others => '0') --Rest of RAM goes to 0	
			);
		elsif(rising_edge(clock)) then
			if(WriteEn = '1') then
				InstructionBank(addrInNat) <= WriteData;
			end if;
		end if;
	end process;
end instMem;

--Instruction Set
--ADD   0001 000 011 000|001 -> $1 = $0 + $3		
--ADDI  0010 000 011 101010  -> $3 = $0 + 42 
--NOR   0011 000 011 000|001 -> $1 = $0 NOR $3
--AND   0100 000 011 000|001 -> $1 = $0 AND $3
--BEQ   0101 000 011 000101  -> if($0 == $3) PC = 5
--JUMP  0110 000 000 000101  -> PC = 5
--LOAD  0111 000 011 000101  -> $3 = RAM ADDRESS(5)
--STORE 1000 000 011 000101  -> RAM ADDRESS(5) = $3
--IN    1001 000 011 000000  -> $3 = Input
--OUT   1010 000 011 000000  -> Out = $3
--MOVE  1011 000 001 000|011  -> $3 = $1
--BGT   1100 000 011 000001  -> if ($ZERO > $3) PC = 1