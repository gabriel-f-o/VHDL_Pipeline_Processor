library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity PipelineDataPath is --Pipeline datapath. This entity encapsulates every component in the data path (registers, ALU, muxes, etc)
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
end entity;

architecture pipeDp of PipelineDataPath is	

	component BasicRegister is --Normal register (sensible to rising clock edge)
		generic(
			DATA_WIDTH : natural := 16 --16 Bits data
		);
		port(		
			clock    : in  std_logic; 
			reset    : in  std_logic;
			RegWrite : in  std_logic;
			
			RegSrc   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
					
			RegData  : out std_logic_vector((DATA_WIDTH-1) downto 0)  --Output Data
		);
	end component;

	component InstructionMemory is --Instruction memory, for simplicity sake, we'll keep only 16 regiters
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
	end component;

	component IF_IDRegister is --Instruction Fetch / Instruction Decode interface register
		generic(
			OP_WIDTH	  : natural := 4; --OP width
			FS_WIDTH	  : natural := 3; --First segment width
			SS_WIDTH	  : natural := 3; --Second segment width
			LS_WIDTH   : natural := 6; --Last segment width
			DATA_WIDTH : natural := 16 --16 Bits data	
		);
		port(
			clock		    : in  std_logic; --Clock
			reset		    : in  std_logic; --Reset
			WriteEn      : in  std_logic; --Write on register
			
			IF_Inst      : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
					
			ID_OP		    : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			ID_firstSeg  : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			ID_secondSeg : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			ID_lastSeg	 : out std_logic_vector((LS_WIDTH-1) downto 0)	--Last 6 bits
		);
	end component;

	component RegisterBank is --Cache memory (8 regiters wide)
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
	end component;

	component customExtend is --Custom extend, if mode = 0 -> zero extend, if mode = 1 -> sign extend
		generic(
			DATA_WIDTH  : natural := 16; --16 Bits data
			INPUT_WIDTH : natural := 6  --6 Bits input data
		);
		port(
			modeSel		 : in  std_logic; --Mode
			shortData	 : in  std_logic_vector((INPUT_WIDTH-1) downto 0); --Input data
			extendedData : out std_logic_vector((DATA_WIDTH-1) downto 0) 	--Output data
		);
	end component;

	component ID_EXRegister is --Instruction Decode / Execution interface register
		generic(
			OP_WIDTH	   : natural := 4; --OP width
			FS_WIDTH	   : natural := 3; --First segment width
			SS_WIDTH	   : natural := 3; --Second segment width
			
			RADD_WIDTH  : natural := 3;   --3 Bits register bank address
			
			ALUOP_WIDTH : natural := 3; --3 Bits operation ID
			ALUB_MUX_SZ : natural := 2;

			DATA_WIDTH  : natural := 16 --16 Bits data	
		);
		port(
			clock		       : in  std_logic; --Clock
			reset		       : in  std_logic; --Reset
			WriteEn         : in  std_logic; --Enable writing
			
			--Control signals for WB step
			ID_WB_WriteEn   : in  std_logic; --Write on cache
			ID_WB_WtUserReg : in  std_logic; --Write output
			ID_WB_DataSel   : in  std_logic; --Mux selector for data source
			
			--Control signals for MEM step
			ID_MEM_DataWt   : in  std_logic; --Write on RAM
			ID_MEM_IsJump   : in  std_logic; --If it is executing a jump
			ID_MEM_IsBranch : in  std_logic; --If it is executing a branch instruction
			
			--Control signals for EX step
			ID_EX_DestReg   : in  std_logic;
			ID_EX_AluSrcBSel: in  std_logic_vector((ALUB_MUX_SZ-1) downto 0); 
			ID_EX_AluOp     : in  std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
			
			--Save cache data
			ID_BankR1Data   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
			ID_BankR2Data   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
			
			--Save instruction fields
			ID_OP  	       : in  std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			ID_firstSeg     : in  std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			ID_secondSeg    : in  std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			ID_lastSeg      : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			ID_exLastSeg    : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			
			--Outputs WB control signals
			EX_WB_WriteEn   : out std_logic;
			EX_WB_WtUserReg : out std_logic;
			EX_WB_DataSel   : out std_logic;
			
			--Outputs MEM control signals
			EX_MEM_DataWt   : out std_logic;
			EX_MEM_IsJump   : out std_logic;
			EX_MEM_IsBranch : out std_logic;
			
			--Outputs EX control signals
			EX_DestReg      : out std_logic;
			EX_AluSrcBSel   : out std_logic_vector((ALUB_MUX_SZ-1) downto 0); 
			EX_AluOp        : out std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
			
			EX_BankR1Data   : out std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
			EX_BankR2Data   : out std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
					
			EX_OP           : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			EX_firstSeg     : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			EX_secondSeg    : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			EX_lastSeg      : out std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			EX_exLastSeg    : out std_logic_vector((DATA_WIDTH-1) downto 0) --Extended last signal

		);
	end component;

	component ALU is --Arithmetic Logic Unit
		generic(
			DATA_WIDTH  : natural := 16;  --16 Bits data
			ALUOP_WIDTH : natural := 3 --3 Bits operation ID
		);
		port(		
			AluSrcA   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input A
			AluSrcB   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input B
			
			AluOP 	 : in  std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
			
			AluComp   : out std_logic; --Input compare result
			AluRes    : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output Data
		);
	end component;

	component EX_MEMRegister is --Execute / Memory Access interface register
		generic(
			RADD_WIDTH  : natural := 3; --Second segment width
			
			DATA_WIDTH  : natural := 16 --16 Bits data	
		);
		port(
			clock		       : in  std_logic; --Clock
			reset		       : in  std_logic; --Reset
			WriteEn         : in  std_logic; --Write on register
			
			--WB control signals
			EX_WB_WriteEn   : in std_logic;
			EX_WB_WtUserReg : in std_logic;
			EX_WB_DataSel   : in std_logic;
			
			--MEM control signals
			EX_MEM_DataWt   : in std_logic;
			EX_MEM_IsJump   : in std_logic;
			EX_MEM_IsBranch : in std_logic;
			
			--Saves useful parts of the original instruction				
			EX_DestReg      : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			EX_exLastSeg    : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			EX_AluComp      : in  std_logic;
			EX_AluRes       : in  std_logic_vector((DATA_WIDTH-1) downto 0);

			
			--Outputs WB control signals
			MEM_WB_WriteEn  : out std_logic;
			MEM_WB_WtUserReg: out  std_logic;
			MEM_WB_DataSel  : out std_logic;
			
			--Outputs MEM control signals
			MEM_DataWt      : out std_logic;
			MEM_IsJump      : out std_logic;
			MEM_IsBranch    : out std_logic;
			
			--Outputs stored information
			MEM_DestReg     : out std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			MEM_exLastSeg   : out std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			MEM_AluComp     : out std_logic;
			MEM_AluRes      : out std_logic_vector((DATA_WIDTH-1) downto 0)
		);
	end component;

	component DataMemory is --Ram memory, for simplicity sake, we'll keep only 16 regiters
		generic(
			DATA_WIDTH : natural := 16; --16 Bits data
			ADDR_WIDTH : natural := 2   --2 Bits RAM address
		);
		port(
			clock		 : in  std_logic; --Clock
			reset		 : in  std_logic; --Reset 
			WriteEn   : in  std_logic; --Write on address
			
			addrSel 	 : in  std_logic_vector((ADDR_WIDTH-1) downto 0); --Selecs Address
			WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
			
			RegData   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
		);
	end component;

	component MEM_WBRegister is --Memory access / Write Back interface register
		generic(
			RADD_ADDR  : natural := 3; --Second segment width
			
			DATA_WIDTH : natural := 16 --16 Bits data	
		);
		port(
			clock		       : in  std_logic; --Clock
			reset		       : in  std_logic; --Reset
			WriteEn         : in  std_logic;

			--WB control signals
			MEM_WB_WriteEn  : in std_logic;
			MEM_WB_WtUserReg: in std_logic;
			MEM_WB_DataSel  : in std_logic;
			
			--The only part of the instruction that is useful now
			MEM_DestReg     : in  std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
			
			--Save useful data
			MEM_RAMData     : in  std_logic_vector((DATA_WIDTH-1) downto 0);
			MEM_AluRes      : in  std_logic_vector((DATA_WIDTH-1) downto 0);
			
			--Outputs WB control signals
			WB_WriteEn      : out std_logic;
			WB_WtUserReg    : out std_logic;
			WB_DataSel      : out std_logic;

			--Outputs destination register
			WB_DestReg      : out std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
			
			--RAM and ALU res data
			WB_RAMData      : out std_logic_vector((DATA_WIDTH-1) downto 0);
			WB_AluRes       : out std_logic_vector((DATA_WIDTH-1) downto 0)
		);
	end component;


	--Instruction Fetch signals
	signal PCInS 		      : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal PCOutS 		      : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal PCSumS		      : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal PCSrcSelS        : std_logic;
	
	signal InstDataS	      : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal IF_IDInstS       : std_logic_vector((DATA_WIDTH-1) downto 0);	
	
	signal IF_OPS			   : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal IF_firstSegS	   : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal IF_secondSegS    : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	
	signal ID_OPS			   : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal ID_firstSegS	   : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal ID_secondSegS    : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal ID_lastSegS	   : std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
		
	--ID		
	signal ID_extdLastSegS  : std_logic_vector((DATA_WIDTH-1) downto 0); 	--Last 6 bits
	
	signal Reg1DataS        : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2DataS        : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal Reg1FinalDataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2FinalDataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal EX_WB_WriteEnS   : std_logic;
	signal EX_WB_DataSelS   : std_logic;
	signal EX_WB_WtUserRegS : std_logic;

	signal EX_MEM_WriteEnS  : std_logic;
	signal EX_MEM_IsJumpS   : std_logic;
	signal EX_MEM_IsBranchS : std_logic;

	signal EX_DestRegS      : std_logic;
	signal EX_AluSrcBS      : std_logic_vector((ALUB_MUX_SZ-1) downto 0);
	signal EX_AluOpS        : std_logic_vector((ALUOP_WIDTH-1) downto 0);

	signal BankR1DataS      : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal BankR2DataS      : std_logic_vector((DATA_WIDTH-1) downto 0);

	signal EX_secondSegS    : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal EX_lastSegS	   : std_logic_vector((RADD_WIDTH-1) downto 0);	--Last 6 bits
	signal EX_extLastSegS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--EX
	signal CorrectData1S    : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal CorrectData2S    : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal AluBSrcDataS     : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal EX_AluCompS      : std_logic; --Input compare result
	signal EX_AluResS       : std_logic_vector((DATA_WIDTH-1) downto 0); --Output Data
	
	signal EX_DestinyAddrS  : std_logic_vector((RADD_WIDTH-1) downto 0); --Output Data
	
	signal MEM_WB_WriteEnS  : std_logic;
	signal MEM_WB_WtUserRegS: std_logic;
	signal MEM_WB_DataSelS  : std_logic;

	signal MEM_WriteEnS     : std_logic;
	signal MEM_IsJumpS      : std_logic;
	signal MEM_IsBranchS    : std_logic;

	signal MEM_DestRegS     : std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
	signal MEM_exLastSegS   : std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal

	signal MEM_AluCompS     : std_logic;
	signal MEM_AluResS      : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--MEM	
	signal RAMDataS         : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal WB_WriteEnS      :  std_logic;
	signal WB_WtUserRegS    :  std_logic;
	signal WB_DataSelS      :  std_logic;
	
	signal WB_DataMemS      :  std_logic_vector((DATA_WIDTH-1) downto 0);
	signal WB_AluResS       :  std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--WB
	signal WB_WriteDataS    : std_logic_vector((DATA_WIDTH-1) downto 0);  --Register 2 out
	signal WB_DestRegS      : std_logic_vector((RADD_WIDTH-1) downto 0);
	
begin
	--Output control signals to external control units
	MEM_AluComp <= MEM_AluCompS;
	InstructionData <= InstDataS;
	WB_WriteData <= WB_WriteDataS;
	
	ID_OP <= ID_OPS;
	ID_secondSeg <= ID_secondSegS;
	ID_lastSeg <= ID_lastSegS;
	
	EX_secondSeg <= EX_secondSegS;
	
	WB_DestReg <= WB_DestRegS;
	MEM_DestReg <= MEM_DestRegS;
	
	WB_WriteEn <= WB_WriteEnS;
	MEM_WB_WriteEn <= MEM_WB_WriteEnS;
	
	--IF
	PCSumS <= (PCOutS + 1);

	PCInS <= (PCSumS) when (PCSrcSelS = '0') else (MEM_exLastSegS); --Selects PC+1 or last segment extended

	PCRegister : BasicRegister port map(clock, reset, (not StallEn), PCInS, PCOutS); --WriteEn on PC is the oposite of stall (if stall is enabled, PC won't be written), this is necessary to not skip instructions if stall is enabled

	InstMemory : InstructionMemory port map('0', reset, '0', PCOutS((INST_WIDTH-1) downto 0), (others => '0'), InstDataS); --Instruction memory. Since it's read-only, clock, WriteEn, and inputData are don't care, thus forced to GND

	IF_IDInstS <=  (others => '0') when (StallEn = '1') else (InstDataS); --Instruction that goes into IF/ID is the instruction fetched, or all 0 if stall is enabled (load a NOP into ID)

	IF_ID_InterfaceRegister : IF_IDRegister port map(clock, (reset or PCSrcSelS), IFIDWriteEn, IF_IDInstS, ID_OPS, ID_firstSegS, ID_secondSegS, ID_lastSegS); --IF/ID register. It can be reset by either the reset signal, or the PCSrc control signal, 
																																																				 --this is important for the branch prediction, where we assume the brench is never taken and continue loading instruction, then if the brench is taken (hence PCSel = 1), we have to erase every instruction loaded
	
	--ID
	CacheRegisterBank : RegisterBank port map(clock, reset, WB_WriteEnS, ID_firstSegS, ID_secondSegS, WB_DestRegS, WB_WriteDataS, Reg1DataS, Reg2DataS); --Cache register bank
	
	lastSegCustomExtend : customExtend port map(ID_lastSegExtMode, ID_lastSegS, ID_extdLastSegS);
	
	Reg1FinalDataS <= WB_WriteDataS when ((WB_DestRegS = ID_firstSegS) and (WB_WriteEnS = '1')) else (Reg1DataS); --Forwarding from WB to ID. If you try to read and write on the same address at the same time, the data passed forward will be before writing. To avoid this problem, this mechanism passes the write data to EX instead of the bank data, but only if the instruction loaded into WB wants to write on cache, and is writing on the same address ID is reading from
	Reg2FinalDataS <= WB_WriteDataS when ((WB_DestRegS = ID_secondSegS) and (WB_WriteEnS = '1')) else (Reg2DataS); --Same mechanism described above, but for reg 2
	
	ID_EX_Register : ID_EXRegister port map(clock, (reset or PCSrcSelS), IDEXWriteEn, ID_WB_WriteEn, ID_WB_WtUserReg, ID_WB_DataSel, ID_MEM_DataWt, ID_MEM_IsJump, ID_MEM_IsBranch,
														 ID_EX_DestReg, ID_EX_AluBSrc, ID_EX_AluOp, Reg1FinalDataS, Reg2FinalDataS, ID_OPS, ID_firstSegS, ID_secondSegS, ID_lastSegS((RADD_WIDTH-1) downto 0), 
														 ID_extdLastSegS, EX_WB_WriteEnS, EX_WB_WtUserRegS, EX_WB_DataSelS, EX_MEM_WriteEnS, EX_MEM_IsJumpS, EX_MEM_IsBranchS, EX_DestRegS,
														 EX_AluSrcBS, EX_AluOpS, BankR1DataS, BankR2DataS, EX_OP, EX_firstSeg, EX_secondSegS, EX_lastSegS, EX_extLastSegS); --ID/EX register. It has the same reset logic as IF/ID
														 
	--EX
	with FWData1Sel select --Mux to select forwarding (the control signal logic is described in the forwarding unit)
		CorrectData1S <= BankR1DataS    when "00", --0 selects Cache
							  MEM_AluResS     when "01", --1 selects MEM data
							  WB_WriteDataS  when "10", --2 selects WB data
							 (others => '0') when others; --Unused
							 
	with FWData2Sel select --Mux to select forwarding (the control signal logic is described in the forwarding unit)
		CorrectData2S <= BankR2DataS    when "00", --0 selects Cache
							  MEM_AluResS     when "01", --1 selects MEM data
							  WB_WriteDataS  when "10", --2 selects WB data
							 (others => '0') when others; --Unused
							 
	with EX_AluSrcBS select --Mux to select data source for Alu B
		AluBSrcDataS   <= CorrectData2S  when "00", --0 selects cache or forwarded
							   EX_extLastSegS when "01", --1 selects last signal extended
							   userEntry      when "10", --2 selects user input
							  (others => '0') when others; --unused
							 

	EX_DestinyAddrS <= (EX_secondSegS) when (EX_DestRegS = '0') else (EX_lastSegS); --Mux to select the destiny address (0 -> selects second segment; 1 -> selects 3 LSBs of last segment)

	ArithmeticLogicUnit : ALU port map(CorrectData1S, AluBSrcDataS, EX_AluOpS, EX_AluCompS, EX_AluResS); --ALU

	EX_MEM_Register : EX_MEMRegister port map(clock, reset, EXMEMWriteEn, EX_WB_WriteEnS, EX_WB_WtUserRegS, EX_WB_DataSelS, EX_MEM_WriteEnS, EX_MEM_IsJumpS, EX_MEM_IsBranchS,
															EX_DestinyAddrS, EX_extLastSegS, EX_AluCompS, EX_AluResS, MEM_WB_WriteEnS, MEM_WB_WtUserRegS, MEM_WB_DataSelS, MEM_WriteEnS, MEM_IsJumpS, MEM_IsBranchS,
															MEM_DestRegS, MEM_exLastSegS, MEM_AluCompS, MEM_AluResS); --EX/MEM register
															
	--MEM
	PCSrcSelS <= (MEM_IsJumpS OR (MEM_AluCompS AND MEM_IsBranchS)); --PC needs to be written if it's a JUMP instruction, or a branch when alu compare = 1

	RAMDataMemory : DataMemory port map(clock, reset, MEM_WriteEnS, MEM_exLastSegS((ADDR_WIDTH-1) downto 0), MEM_AluResS, RAMDataS); --Data Memory
	
	MEM_WB_Register : MEM_WBRegister port map(clock, reset, MEMWBWriteEn, MEM_WB_WriteEnS, MEM_WB_WtUserRegS, MEM_WB_DataSelS, MEM_DestRegS, RAMDataS, MEM_AluResS, WB_WriteEnS, WB_WtUserRegS, WB_DataSelS,
														   WB_DestRegS, WB_DataMemS, WB_AluResS); --MEM/WB register

	--WB
	WB_WriteDataS <= (WB_DataMemS) when (WB_DataSelS = '0') else (WB_AluResS); --Write Back Mux (0 -> selects RAM; 1 -> selects Alu res)
	
	UserOutputRegister : BasicRegister port map(clock, reset, WB_WtUserRegS, WB_WriteDataS, userInterface); --User output

end pipeDp;