library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity HazardUnit is --Hazard unit, used to stall the processor when necessary
	generic(			
		OP_WIDTH	  : natural := 4; --OP width
		FS_WIDTH	  : natural := 3; --First segment width
		SS_WIDTH	  : natural := 3; --Second segment width
		LS_WIDTH   : natural := 6  --Last segment width
	);
	port(		
		InstructionData   : in  std_logic_vector((OP_WIDTH + FS_WIDTH + SS_WIDTH - 1) downto 0); --15 to 6 bits of instruction comming out of InstructionMemory (ignored last segment)
		ID_OP             : in  std_logic_vector((OP_WIDTH-1) downto 0); --Operation loaded in ID
		ID_secondSeg      : in  std_logic_vector((SS_WIDTH-1) downto 0); --Second segment loaded in ID
		
		StallEn           : out std_logic --1 when stall is necessary
	);
end entity;

architecture hzUn of HazardUnit is

	signal IF_OPS			 : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation
	signal IF_firstSegS	 : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal IF_secondSegS  : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	
begin
	
	IF_OPS <= InstructionData((OP_WIDTH + FS_WIDTH + SS_WIDTH - 1) downto (FS_WIDTH + SS_WIDTH)); --9 to 6
	IF_firstSegS <= InstructionData((FS_WIDTH + SS_WIDTH - 1) downto (SS_WIDTH)); --5 to 3
	IF_secondSegS <= InstructionData((SS_WIDTH-1) downto 0); --2 to 0
	
	process(IF_OPS, IF_firstSegS, IF_secondSegS, ID_OP, ID_secondSeg) --If any of the instruction parts changes
	begin
		if(ID_OP = "0111") then --The only problem that cannot be solved with forwarding is when LOAD is loaded in ID, and the next instruction wants to read from the LOAD destiny register (stored in the secondSegment)
			
			if(ID_secondSeg = "000") then --If LOAD will write on ZERO, ignore (the write is protected by hardware)
				StallEn <= '0';
			else
				case IF_OPS is 
					when "0001" | "0011" | "0100" | "0101" | "1100" => --If instruction fetched is ADD, NOR, AND, BEQ or BGT (instruction that read 2 registers)
						if((ID_secondSeg = IF_firstSegS) OR (ID_secondSeg = IF_secondSegS)) then --If any of the registers read will be written by the LOAD instruction, stall for 1 cycle
							StallEn <= '1';
						else
							StallEn <= '0';
						end if;
							
					when "0010" => --If ADDI (instructions that read only the first register)
						if(ID_secondSeg = IF_firstSegS) then --If the read address will be written
							StallEn <= '1'; --Stall for 1 cycle
						else
							StallEn <= '0';
						end if;
					
					when "1000" | "1010" | "1011" => --If STORE, OUT or MOVE (instructions that read the second register)
						if(ID_secondSeg = IF_secondSegS) then --If the read address will be written
							StallEn <= '1'; --Stall for 1 cycle
						else
							StallEn <= '0';
						end if;

					when others => --If the instruction does not read from register (e.g. JUMP), don't stall
						StallEn <= '0';
				end case;
			end if;
			
		else
			StallEn <= '0'; --Any other hazzard can be solved with forwarding
		end if;
	end process;
end hzUn;