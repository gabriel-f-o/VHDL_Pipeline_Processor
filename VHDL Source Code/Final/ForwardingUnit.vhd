library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ForwardingUnit is --Forwarding unit, used to avoid data hazzards by forwarding MEM and WB data directly into ALU
	generic(		
		OP_WIDTH	  : natural := 4; --OP width
		FS_WIDTH	  : natural := 3; --First segment width
		SS_WIDTH	  : natural := 3; --Second segment width
		
		FW_WIDTH   : natural := 2; --Mux selection size for forwarding
		
		RADD_WIDTH : natural := 3  --3 Bits register bank address
	);
	port(		
		EX_OP             : in  std_logic_vector((OP_WIDTH-1) downto 0); --OP in EX step
		EX_firstSeg       : in  std_logic_vector((FS_WIDTH-1) downto 0); --First Seg in EX step
		EX_secondSeg      : in  std_logic_vector((SS_WIDTH-1) downto 0); --Second Seg in EX step
		
		WB_DestReg        : in  std_logic_vector((RADD_WIDTH-1) downto 0); --WB Destiny register
		MEM_DestReg       : in  std_logic_vector((RADD_WIDTH-1) downto 0); --MEM destiny register
		
		WB_WriteEn        : in  std_logic; --WB write cache enable
		MEM_WB_WriteEn    : in  std_logic; --MEM write cache enable
		
		FWData1Sel        : out std_logic_vector((FW_WIDTH-1) downto 0); --0 -> data comes from R1; 1 -> Data comes from MEM; 2 -> Data comes from WB; 3 -> all 0 (unused)
		FWData2Sel        : out std_logic_vector((FW_WIDTH-1) downto 0)  --0 -> data comes from R2; 1 -> Data comes from MEM; 2 -> Data comes from WB; 3 -> all 0 (unused)
	);
end entity;

architecture fwUn of ForwardingUnit is	

	signal FW_R1Read : std_logic; --Instruction being executed read from R1
	signal FW_R2Read : std_logic; --Instruction being executed read from R2
	
begin

	--Instruction read from R1
	with EX_OP select
		FW_R1Read <= '1' when x"1" to x"5" | x"8" to x"C", --ADD, ADDI, NOR, AND, BEQ, STORE, IN, OUT, MOVE, BGT (instructions that only read from ZERO added to make easier (e.g. MOVE), when writing into ZERO, controller puts WriteEn = 0, so it does not affect the logic)
						 '0' when others;
					
	--Instruction read from R2		
	with EX_OP select
		FW_R2Read <= '1' when x"1" | x"3" to x"5" | x"8" | x"A" to x"C", --ADD, NOR, AND, BEQ, STORE, OUT, MOVE, BGT
						 '0' when others;
						 
		
 	process(FW_R1Read, FW_R2Read, EX_firstSeg, EX_secondSeg, WB_DestReg, MEM_DestReg, MEM_WB_WriteEn, WB_WriteEn)
	begin	
		if((FW_R1Read = '1') AND (MEM_WB_WriteEn = '1') AND (EX_firstSeg = MEM_DestReg)) then --If the instruction read from R1, and the instruction loaded in MEM wants to write on the same address
			FWData1Sel <= "01"; --Selects MEM data (1)
		elsif((FW_R1Read = '1') AND (WB_WriteEn = '1') AND (EX_firstSeg = WB_DestReg)) then --If the instruction read from R1, and the instruction loaded in WB wants to write on the same address
			FWData1Sel <= "10"; --Selects WB data (2), selecting MEM first is important because if many instructions manipulate the same register, the MEM data will be the last updated value
		else
			FWData1Sel <= "00"; --Otherwise keep the R1 value (0)
		end if;
		
		if((FW_R2Read = '1') AND (MEM_WB_WriteEn = '1') AND (EX_secondSeg = MEM_DestReg)) then --If the instruction read from R2, and the instruction loaded in MEM wants to write on the same address
			FWData2Sel <= "01"; --Selects 1
		elsif((FW_R2Read = '1') AND (WB_WriteEn = '1') AND (EX_secondSeg = WB_DestReg)) then --If the instruction read from R2, and the instruction loaded in WB wants to write on the same address
			FWData2Sel <= "10"; --Selects 2
		else
			FWData2Sel <= "00"; --Otherwise, keep 0
		end if;
	end process;
	
end fwUn;