library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity InstructionMemory is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
		DATA_WIDTH : natural := 16; --16 Bits data
		INST_WIDTH : natural := 4   --4 Bits instruction address
	);
	port(
		clock		 : in  std_logic; --Clock
		reset		 : in  std_logic; --Reset 
		
		addrIn 	 : in  std_logic_vector((INST_WIDTH-1) downto 0);
		
		DataOut   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
	);
end entity;

architecture instMem of InstructionMemory is

	type dataRegister is array (0 to 2**INST_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0); --Typedef to define "dataRegister" as an array of length 2^(addr)

	signal InstructionBank : dataRegister; --Declare intruction reg bank
	signal addrInNat : natural range 0 to (2**INST_WIDTH-1); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
	
begin
	addrInNat <= to_integer(unsigned(addrIn));
	DataOut <= InstructionBank(addrInNat);
	
	process(reset) --Process to be executed when reset and clock changes
	begin
		if(reset = '1') then --Reset to default state
			InstructionBank <= 
			(
				--0  => "0110000000000101", --JUMP  0110 000 000 000101  -> PC = 5
				--2  => "0111000011000000", --LOAD  0111 000 011 000101  -> $3 = RAM ADDRESS(5)
				--3  => "0001011000000010",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--0  => "0010000001000001",  --ADDI  0010 000 011 101010  -> $3 = $0 + 42 
				--1  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--2  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--3  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--4  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--5  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--6  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--7  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--8  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--9  => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--10 => "0001001001000001",  --ADD   0001 000 011 000|011 -> $3 = $0 + $3	
				--11 => "1010000001000000", --OUT   1010 000 011 000000  -> Out = $3

				--0  => "0111000011000010",
				--1  => "0010011011101010", --ADDI  0010 000 011 101010  -> $3 = $0 + 42 
				
				
				
				--0  => "1000000001000010", --STORE 1000 000 011 000101  -> RAM ADDRESS(5) = $3
				--5  => "0111000011000010", --LOAD  0111 000 011 000101
				--12 => "1010000011000000",  --OUT   1010 000 011 000000 
			
				--0  => "1001000011000000", --IN    1001 000 011 000000  -> $3 = Input
				--5  => "1011000011000001",  --MOVE  1011 000 001 000|011  -> $3 = $1
				--12 => "1010000001000000",
				
				--0  => "0010000001010110", --ADDI $R1, $ZERO, 22  // i = 22
				--5  => "1100001000000111", --BGT   1100 000 011 000001  -> if ($ZERO > $3) PC = 1
				--1  => "0110000000000111", --JUMP  0110 000 000 000111  -> PC = 7
				--1  => "0101000101000111", --BEQ   0101 000 011 000101  -> if($0 == $5) PC = 7
				--6  => "0010000010111110", --ADDI $R2, $ZERO, -2  // j = -2
				--7  => "0001001010000011", --ADD  $R3, $R1, $R2 //i+j
				--13 => "1010000011000000", --OUT R3
				
				
				--0  => "0010000001010110", --ADDI $R1, $ZERO, 22  // i = 22
				--1  => "0010000010111110", --ADDI $R2, $ZERO, -2  // j = -2
				--2  => "0010000011010000", --ADDI $R3, $ZERO, 16  // k = 16
				--3  => "0010000100000000", --ADDI $R4, $ZERO, 0   // input = 0
				--4  => "0010000101000000", --ADDI $R5, $ZERO, 0   // output = 0
				--5  => "0010000111000010", --ADDI $TEMP(R7), $ZERO, 2 // temp = 2
				
				--6  => "1010000001000000", --OUT   1010 000 001 000000  -> Out = $1
				--7  => "1010000010000000", --OUT   1010 000 010 000000  -> Out = $2
				--8  => "1010000011000000", --OUT   1010 000 011 000000  -> Out = $3
				--9  => "1010000100000000", --OUT   1010 000 100 000000  -> Out = $4
				--10 => "1010000101000000", --OUT   1010 000 101 000000  -> Out = $5
				--11 => "1010000111000000", --OUT   1010 000 111 000000  -> Out = $7

				--0 => "0111000011000101", --LOAD  0111 000 011 000101  -> $3 = RAM ADDRESS(5)
				--1 => "0001000111000111", --ADD   0001 000 111 000|111 -> $7 = $0 + $7
				--2 => "0111000011000100", --LOAD  0111 000 011 000100  -> $3 = RAM ADDRESS(4)
				--3 => "0001000011000011", --ADD 0001 000 011 000|011 -> $3 = $0 + $3
				--0 =>  x"0010",
				--1 =>  x"0011",
				--2 =>  x"0012",
				--3 =>  x"0013",
				--4 =>  x"0014",
				--5 =>  x"0015",
				--6 =>  x"0016",
				--7 =>  x"0017",
				--8 =>  x"0018",
				--9 =>  x"0019",
				--10 => x"001A",
				--11 => x"001B",
				--12 => x"001C",
				--13 => x"001D",
				--14 => x"001E",
				--15 => x"001F",				
				
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
				14 => "0110000000001101",
	
				others => (others => '0') --Rest of RAM goes to 0	
			);
		end if;
	end process;
end instMem;


--Instruction Set
--ADD   0001 000 011 000|011 -> $3 = $0 + $3		
--ADDI  0010 000 011 101010  -> $3 = $0 + 42 
--NOR   0011 000 011 000|011 -> $3 = $0 NOR $3
--AND   0100 000 011 000|011 -> $3 = $0 AND $3
--BEQ   0101 000 011 000101  -> if($0 == $3) PC = 5
--JUMP  0110 000 000 000101  -> PC = 5
--LOAD  0111 000 011 000101  -> $3 = RAM ADDRESS(5)
--STORE 1000 000 011 000101  -> RAM ADDRESS(5) = $3
--IN    1001 000 011 000000  -> $3 = Input
--OUT   1010 000 011 000000  -> Out = $3
--MOVE  1011 000 001 000|011  -> $3 = $1
--BGT   1100 000 011 000001  -> if ($ZERO > $3) PC = 1