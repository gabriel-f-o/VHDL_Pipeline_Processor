library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity PipelineProcessor is --Pipeline processor. This entity implements every component of the processor
	generic(		
	   ADDR_WIDTH  : natural  := 2; --2 bits RAM address
		INST_WIDTH  : natural  := 4; --4 bits instruction address

		ALUOP_WIDTH : natural := 3; --3 Bits operation ID
		ALUB_MUX_SZ : natural := 2; --Alu B source mux size
	
		OP_WIDTH	   : natural := 4; --OP width
		FS_WIDTH	   : natural := 3; --First segment width
		SS_WIDTH	   : natural := 3; --Second segment width
		LS_WIDTH    : natural := 6; --Last segment width
		
		FW_WIDTH    : natural := 2; --Forward mux size
		
		RADD_WIDTH  : natural := 3; --3 Bits register bank address
			
		DATA_WIDTH  : natural := 16 --16 Bits data
	);
	port(		
		clock		      : in std_logic;
		userEntry		: in std_logic_vector((DATA_WIDTH-1) downto 0); --User input
		
		MEM_AluComp    : out std_logic; --Debug / visualization output
		WB_WriteData   : out std_logic_vector((DATA_WIDTH-1) downto 0); --Debug / visualization output
		
		userInterface  : out std_logic_vector((DATA_WIDTH-1) downto 0) --User output
	);
end entity;

architecture pp of PipelineProcessor is	
							
	component HazardUnit is --Hazard unit, used to stall the processor when necessary
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
	end component;

	component ForwardingUnit is --Forwarding unit, used to avoid data hazzards by forwarding MEM and WB data directly into ALU
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
	end component;
	
	component ControlUnit is --Control unit. It sets the control signals so that the instructions can be executed properly in the data path
		generic(		
			OP_WIDTH	   : natural := 4; --OP width
			SS_WIDTH	   : natural := 3; --Second segment width
			
			RADD_WIDTH  : natural := 3; --3 Bits cache address
			
			ALUOP_WIDTH : natural := 3; --3 Bitzs operation ID
			ALUB_MUX_SZ : natural := 2  --Alu B mux selector size	
		);
		port(
			clock		         : in  std_logic; --Clock		
			
			ID_OP             : in  std_logic_vector((OP_WIDTH-1) downto 0); --ID instruction OP
			ID_secondSeg      : in  std_logic_vector((SS_WIDTH-1) downto 0); --ID second segment
			ID_lastSeg        : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Last 3 bits of last segment
			
			reset				   : out std_logic; --Reset memory elements
			ID_lastSegExtMode : out std_logic; --Choses mode for last segment (0 -> zero extend; 1 -> sign extend)
			
			ID_WB_WriteEn     : out std_logic; --Set WB_WriteEn to write on cache once the instruction reaches WB step
			ID_WB_DataSel     : out std_logic; --Selects data to write on cache once the instruction reaches WB step (0 -> RAM; 1 -> Alu result)
			ID_WB_WtUserReg   : out std_logic; --Set WB_WtUserReg to write on output register once the instruction reaches WB step

			ID_MEM_DataWt     : out std_logic; --Set if the instruction wants to write on RAM (LOAD)
			ID_MEM_IsJump     : out std_logic; --Set if the instruction is a JUMP one. Used in MEM step
			ID_MEM_IsBranch   : out std_logic; --Set if the instruction is a BRANCH (BEQ or BGT) one. Used in MEM step

			ID_EX_DestReg     : out std_logic; --Selects from which segment the destiny address is stored (0 -> second segment; 1 -> last segment (last 3 bits)). Used in EX step
			ID_EX_AluBSrc     : out std_logic_vector((ALUB_MUX_SZ-1) downto 0); --Selects the data source for Alu B (0 -> Data comming from cache or forwarded; 1 -> Last segment extended; 2 -> User input; 3 -> all 0 (unused))
			ID_EX_AluOp       : out std_logic_vector((ALUOP_WIDTH-1) downto 0)  --Selects Alu OP code (1 -> ADD; 2 -> NOR; 3 -> AND; 4 -> Equals; 5 -> signed greater than; else -> NOP)
		);
	end component;
		
	component PipelineDataPath is --Pipeline datapath. This entity encapsulates every component in the data path (registers, ALU, muxes, etc)
		generic(
			INST_WIDTH  : natural := 4; --4 Bits instruction address
			
			OP_WIDTH	   : natural := 4; --OP width
			FS_WIDTH	   : natural := 3; --First segment width
			SS_WIDTH	   : natural := 3; --Second segment width
			LS_WIDTH    : natural := 6; --Last segment width
			
			RADD_WIDTH  : natural := 3; --3 Bits cache address
			INPUT_WIDTH : natural := 6; --6 Bit input to extender
			
			ALUOP_WIDTH : natural := 3; --3 Bits operation ID
			ALUB_MUX_SZ : natural := 2; --Alu B mux selector size
			
			FW_WIDTH    : natural := 2; --Forwarding selector size
			
			ADDR_WIDTH  : natural := 2; --2 Bits RAM address
			
			DATA_WIDTH  : natural := 16 --16 Bits data	
		);
		port(
			clock		         : in std_logic; --Clock
			userEntry			: in std_logic_vector((DATA_WIDTH-1) downto 0); --user input
			
			reset			      : in std_logic; --Reset memory elements
			
			--Instruction Fetch Signals
			StallEn		      : in std_logic; --Activate Stall
			IFIDWriteEn       : in std_logic; --Enable write into IF/ID register
			
			--Instruction Decode signals
			ID_lastSegExtMode : in std_logic; --Last segment extender mode
			IDEXWriteEn       : in std_logic; --Enable write into ID/EX register
			
			ID_WB_WriteEn     : in std_logic; --Cache enable write control signal
			ID_WB_DataSel     : in std_logic; --Data selector (0 -> RAM; 1 -> Alu) for WB
			ID_WB_WtUserReg   : in std_logic; --Signal to update output register

			ID_MEM_DataWt     : in std_logic; --Enable write on RAM
			ID_MEM_IsJump     : in std_logic; --Flag to instruction JUMP
			ID_MEM_IsBranch   : in std_logic; --Flag to instruction BEQ and BGT

			ID_EX_DestReg     : in std_logic; --Destiny address selector (0 -> second segment; 1 -> 3 LSBs of last segment)
			ID_EX_AluBSrc     : in std_logic_vector((ALUB_MUX_SZ-1) downto 0); --Alu B source (0 -> cache or forwarded; 1 -> Extended last signal; 2 -> User input; 3 -> all 0 (unused))
			ID_EX_AluOp       : in std_logic_vector((ALUOP_WIDTH-1) downto 0); --Alu Operation (1 -> ADD; 2 -> NOR; 3 -> AND; 4 -> Equals; 5 -> signed greater than; else -> NOP)
			
			--Execution signals
			EXMEMWriteEn      : in std_logic; --Write into EX/MEM register
			
			FWData1Sel        : in std_logic_vector((FW_WIDTH-1) downto 0); --Forward selector (0 -> cache; 1 -> Forwarded from MEM; 2 -> Forwarded from WB; 3 -> all 0 (unused))
			FWData2Sel        : in std_logic_vector((FW_WIDTH-1) downto 0); --Forward selector (0 -> cache; 1 -> Forwarded from MEM; 2 -> Forwarded from WB; 3 -> all 0 (unused))
			
			--MEM
			MEMWBWriteEn      : in std_logic; --Write into MEM/WB register
			
			MEM_AluComp       : out std_logic; --Debug / visualization output
			WB_WriteData      : out std_logic_vector((DATA_WIDTH-1) downto 0); --Debug / visualization output
			
			InstructionData   : out std_logic_vector((DATA_WIDTH-1) downto 0); --Output for Hazard Detection Unit
			
			ID_OP			      : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			ID_secondSeg      : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			ID_lastSeg	      : out std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
			
			EX_OP			      : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			EX_firstSeg       : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			EX_secondSeg      : out std_logic_vector((SS_WIDTH-1) downto 0);  --3 bits after first
				
			WB_DestReg        : out std_logic_vector((RADD_WIDTH-1) downto 0); --Control signal output for destiny address (used on forwarded)
			MEM_DestReg       : out std_logic_vector((RADD_WIDTH-1) downto 0); --Control signal output for destiny address (used on forwarded)
				
			WB_WriteEn        : out	std_logic; --Control signal for cache write enable (used on forwarded)
			MEM_WB_WriteEn    : out std_logic; --Control signal for cache write enable (used on forwarded)
			
			userInterface     : out std_logic_vector((DATA_WIDTH-1) downto 0) --User Output
			
		);
	end component;


	signal resetS             : std_logic;
	signal StallEnS           : std_logic;
	signal ID_lastSegExtModeS : std_logic;
	
	signal ID_WB_WriteEnS     : std_logic;
	signal ID_WB_DataSelS     : std_logic;
	signal ID_WB_WtUserRegS   : std_logic;

	signal ID_MEM_DataWtS     : std_logic;
	signal ID_MEM_IsJumpS     : std_logic;
	signal ID_MEM_IsBranchS   : std_logic;

	signal ID_EX_DestRegS     : std_logic;
	signal ID_EX_AluBSrcS     : std_logic_vector((ALUB_MUX_SZ-1) downto 0);
	signal ID_EX_AluOpS       : std_logic_vector((ALUOP_WIDTH-1) downto 0);
	
	signal FWData1SelS        : std_logic_vector((FW_WIDTH-1) downto 0);
	signal FWData2SelS        : std_logic_vector((FW_WIDTH-1) downto 0);
	
	signal InstructionDataS   : std_logic_vector((DATA_WIDTH-1) downto 0); --Output for Hazard Detection Unit
		
	signal ID_OPS			     : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal ID_secondSegS      : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal ID_lastSegS	     : std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
			
	signal EX_OPS			     : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal EX_firstSegS       : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal EX_secondSegS      : std_logic_vector((SS_WIDTH-1) downto 0);
	
	signal WB_DestRegS        : std_logic_vector((RADD_WIDTH-1) downto 0);
	signal MEM_DestRegS       : std_logic_vector((RADD_WIDTH-1) downto 0);
	
	signal WB_WriteEnS        : std_logic;
	signal MEM_WB_WriteEnS    : std_logic;
	
begin

	HazardDetectionUnit : HazardUnit port map(InstructionDataS((DATA_WIDTH-1) downto (LS_WIDTH)), ID_OPS, ID_secondSegS, StallEnS); --Hazard detection unit, used to stall when necessary
	
	ForwardingSelectorUnit : ForwardingUnit port map(EX_OPS, EX_firstSegS, EX_secondSegS, WB_DestRegS, MEM_DestRegS, WB_WriteEnS, MEM_WB_WriteEnS, FWData1SelS, FWData2SelS); --Forwarding unit used to forward data from MEM or WB to EX
	
	RISCControlUnit : ControlUnit port map(clock, ID_OPS, ID_secondSegS, ID_lastSegS((RADD_WIDTH-1) downto 0), resetS, ID_lastSegExtModeS, ID_WB_WriteEnS, ID_WB_DataSelS, 
														ID_WB_WtUserRegS, ID_MEM_DataWtS, ID_MEM_IsJumpS, ID_MEM_IsBranchS, ID_EX_DestRegS, ID_EX_AluBSrcS, ID_EX_AluOpS); --Main controller
	
	RISCPipelineDataPath : PipelineDataPath port map(clock, userEntry, resetS, StallEnS, '1', ID_lastSegExtModeS, '1', ID_WB_WriteEnS, ID_WB_DataSelS, ID_WB_WtUserRegS,
																	 ID_MEM_DataWtS, ID_MEM_IsJumpS, ID_MEM_IsBranchS, ID_EX_DestRegS, ID_EX_AluBSrcS, ID_EX_AluOpS, '1', FWData1SelS,
																	 FWData2SelS, '1', MEM_AluComp, WB_WriteData, InstructionDataS, ID_OPS, ID_secondSegS, ID_lastSegS, EX_OPS, EX_firstSegS,
																	 EX_secondSegS, WB_DestRegS, MEM_DestRegS, WB_WriteEnS, MEM_WB_WriteEnS, userInterface); --Datapath. All interface registers WriteEn are set to 1 permanently

end pp;