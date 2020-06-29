library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity PipelineProcessor is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
	   ADDR_WIDTH : natural  := 4;
		INST_WIDTH : natural  := 4;
		RADD_ADDR   : natural := 3;
		ALUOP_WIDTH : natural := 3; --3 Bits operation ID
		ALUB_MUX_SZ : natural := 2;
	
		OP_WIDTH	  : natural := 4; --OP width
		FS_WIDTH	  : natural := 3; --First segment width
		SS_WIDTH	  : natural := 3; --Second segment width
		LS_WIDTH   : natural := 6; --Last segment width
		
		FW_WIDTH   : natural := 2;
		
		RADD_WIDTH : natural := 3;   --3 Bits register bank address
			
		DATA_WIDTH : natural := 16 --16 Bits data
	);
	port(
		clock		     : in  std_logic; --Clock	
		userEntry     : in std_logic_vector((DATA_WIDTH-1) downto 0);
		StallOn : out std_logic;
		PCSel : out std_logic;
		
		PCOUTR : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
	   ID_OPSR			 : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	   ID_firstSegSR	 : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	   ID_secondSegSR  : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	   ID_lastSegSR	 : out std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
		
		Data1EX     : out std_logic_vector((DATA_WIDTH-1) downto 0);
		Data2EX    : out std_logic_vector((DATA_WIDTH-1) downto 0);
	
		WB_WriteDataSR : out std_logic_vector((DATA_WIDTH-1) downto 0);
		WB_WtUserRegOutSR: out std_logic;
		
		ALUAR     : out std_logic_vector((DATA_WIDTH-1) downto 0);
		ALUBR     : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		MEM_AluCmpSR : out std_logic;
		
		IFFW1 : out std_logic;
		IFFW2 : out std_logic;
		
		FWData1SelR : out std_logic_vector((FW_WIDTH-1) downto 0);
		FWData2SelR : out std_logic_vector((FW_WIDTH-1) downto 0);
		
		--WB
		userOutput : out std_logic_vector((DATA_WIDTH-1) downto 0)
		
	);
end entity;

architecture pp of PipelineProcessor is

	type FSMState is (RESET_S, OPERATION_S);
	signal currentState, nextState : FSMState := RESET_S;
	
	component BasicRegister is --Normal register (sensible to rising clock edge)
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
	end component;
	
	component InstructionMemory is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
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
	end component;
	
	component IF_IDRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
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
			
			addrR1 	 : in  std_logic_vector((RADD_WIDTH-1) downto 0);
			addrR2 	 : in  std_logic_vector((RADD_WIDTH-1) downto 0);
			writeAddr : in  std_logic_vector((RADD_WIDTH-1) downto 0);
			
			WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
			
			DataOutR1 : out std_logic_vector((DATA_WIDTH-1) downto 0); --Register 1 out
			DataOutR2 : out std_logic_vector((DATA_WIDTH-1) downto 0)  --Register 2 out
		);
	end component;
	
	component customExtend is --Custom extend, if mode = 0 -> zero extend, if mode = 1 -> sign extend
		generic(
			DATA_WIDTH : natural := 16; --16 Bits data
			INPUT_WIDTH : natural := 6  --6 Bits input data
		);
		port(
			modeIn		 : in  std_logic; --Mode
			dataIn		 : in  std_logic_vector((INPUT_WIDTH-1) downto 0); --Input data
			extendedData : out std_logic_vector((DATA_WIDTH-1) downto 0) 	--Output data
		);
	end component;
	
	component ID_EXRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
		generic(
			OP_WIDTH	   : natural := 4; --OP width
			FS_WIDTH	   : natural := 3; --First segment width
			SS_WIDTH	   : natural := 3; --Second segment width
			LS_WIDTH    : natural := 6; --Last segment width
			
			RADD_WIDTH : natural := 3;   --3 Bits register bank address
			
			ALUOP_WIDTH : natural := 3; --3 Bits operation ID
			ALUB_MUX_SZ : natural := 2;

			DATA_WIDTH : natural := 16 --16 Bits data	
		);
		port(
			clock		     : in  std_logic; --Clock
			reset		     : in  std_logic; --Reset
			WriteEn       : in  std_logic;
			
			WBWriteEnIn   : in  std_logic;
			WBWtUserRegIn : in  std_logic;
			WBDataSelIn   : in  std_logic;
			
			MEMDataWtIn   : in  std_logic;
			MEMIsJumpIn   : in  std_logic;
			MEMIsBranchIn : in  std_logic;
			
			EXDestRegIn	  : in  std_logic;
			EXALUSrcBIn	  : in  std_logic_vector((ALUB_MUX_SZ-1) downto 0); 
			EXALUOPIn	  : in  std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
			
			BankR1In      : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
			BankR2In      : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
					
			OPIn  	     : in  std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			firstSegIn    : in  std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			secondSegIn   : in  std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			lastSegIn     : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			exLastSegIn   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			
			
			WBWriteEnOut  : out std_logic;
			WBWtUserRegOut: out  std_logic;
			WBDataSelOut  : out std_logic;
			
			MEMDataWtOut  : out std_logic;
			MEMIsJumpOut  : out std_logic;
			MEMIsBranchOut: out std_logic;
			
			EXDestRegOut  : out std_logic;
			EXALUSrcBOut  : out std_logic_vector((ALUB_MUX_SZ-1) downto 0); 
			EXALUOPOut	  : out std_logic_vector((ALUOP_WIDTH-1) downto 0); --Operation
			
			BankR1Out     : out std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
			BankR2Out     : out std_logic_vector((DATA_WIDTH-1) downto 0); --Input data
					
			OPOut 	     : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			firstSegOut   : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
			secondSegOut  : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
			lastSegOut    : out std_logic_vector((RADD_WIDTH-1) downto 0); --Last 6 bits
			exLastSegOut  : out std_logic_vector((DATA_WIDTH-1) downto 0) --Extended last signal

		);
	end component;
	
	component ALU is --Arithmetic Logic Unit
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
	end component;
	
	component EX_MEMRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
		generic(
			OP_WIDTH	   : natural := 4; --OP width
			SS_WIDTH	   : natural := 3; --Second segment width
			
			DATA_WIDTH : natural := 16 --16 Bits data	
		);
		port(
			clock		     : in  std_logic; --Clock
			reset		     : in  std_logic; --Reset
			WriteEn       : in  std_logic;
			
			WBWriteEnIn   : in  std_logic;
			WBWtUserRegIn : in  std_logic;
			WBDataSelIn   : in  std_logic;
			
			MEMDataWtIn   : in  std_logic;
			MEMIsJumpIn   : in  std_logic;
			MEMIsBranchIn : in  std_logic;
					
			OPIn  	     : in  std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			DestRegIn     : in  std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
			exLastSegIn   : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			AluCmpIn      : in  std_logic;
			AluResIn      : in  std_logic_vector((DATA_WIDTH-1) downto 0);

			
			WBWriteEnOut  : out std_logic;
			WBWtUserRegOut: out  std_logic;
			WBDataSelOut  : out std_logic;
			
			MEMDataWtOut  : out std_logic;
			MEMIsJumpOut  : out std_logic;
			MEMIsBranchOut: out std_logic;
			
			OPOut  	     : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
			DestRegOut    : out std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
			exLastSegOut  : out std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
			
			AluCmpOut     : out std_logic;
			AluResOut     : out std_logic_vector((DATA_WIDTH-1) downto 0)
		);
	end component;
	
	component DataMemory is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
		generic(
			DATA_WIDTH : natural := 16; --16 Bits data
			ADDR_WIDTH : natural := 4   --6 Bits RAM address
		);
		port(
			clock		 : in  std_logic; --Clock
			reset		 : in  std_logic; --Reset 
			WriteEn   : in  std_logic; --Write on address
			
			addrIn 	 : in  std_logic_vector((ADDR_WIDTH-1) downto 0); --Address is to be considered a natural (0+) number from 0 to 2^num - 1
			WriteData : in  std_logic_vector((DATA_WIDTH-1) downto 0); --Data to write
			
			DataOut   : out std_logic_vector((DATA_WIDTH-1) downto 0) --Output
		);
	end component;
	
	component MEM_WBRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
		generic(
			OP_WIDTH	   : natural := 4; --OP width
			RADD_ADDR   : natural := 3; --Second segment width
			
			DATA_WIDTH : natural := 16 --16 Bits data	
		);
		port(
			clock		     : in  std_logic; --Clock
			reset		     : in  std_logic; --Reset
			WriteEn       : in  std_logic;
			
			WBWriteEnIn   : in  std_logic;
			WBWtUserRegIn : in  std_logic;
			WBDataSelIn   : in  std_logic;
					
			OPIn  	     : in  std_logic_vector((OP_WIDTH-1) downto 0); --4 bits operation ID
			DestRegIn     : in  std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
			
			DataMemIn     : in  std_logic_vector((DATA_WIDTH-1) downto 0);
			AluResIn      : in  std_logic_vector((DATA_WIDTH-1) downto 0);

			
			WBWriteEnOut  : out std_logic;
			WBWtUserRegOut: out std_logic;
			WBDataSelOut  : out std_logic;

			OPOut  	     : out std_logic_vector((OP_WIDTH-1) downto 0); --4 bits operation ID
			DestRegOut    : out std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
			
			DataMemOut    : out std_logic_vector((DATA_WIDTH-1) downto 0);
			AluResOut     : out std_logic_vector((DATA_WIDTH-1) downto 0)
		);
	end component;
	
	--IF
	signal PCInS 		: std_logic_vector((DATA_WIDTH-1) downto 0);
	signal PCOutS 		: std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal PCSumS		: std_logic_vector((DATA_WIDTH-1) downto 0);
	signal PCSourceSelS : std_logic;
	
	signal InstOutS	: std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal IF_IDInstInS : std_logic_vector((DATA_WIDTH-1) downto 0);	
	
	signal IF_OPS			 : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal IF_firstSegS	 : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal IF_secondSegS  : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	
	signal ID_OPS			 : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal ID_firstSegS	 : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal ID_secondSegS  : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal ID_lastSegS	 : std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
		
	--ID		
	signal ID_extdLastSegS: std_logic_vector((DATA_WIDTH-1) downto 0); 	--Last 6 bits
	
	signal Reg1DataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2DataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal Reg1FinalDataS : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2FinalDataS : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal EX_WB_WriteEnOutS : std_logic;
	signal EX_WB_DataSelOutS : std_logic;
	signal EX_WB_WtUserRegOutS : std_logic;

	signal EX_MEM_DataWtOutS : std_logic;
	signal EX_MEM_IsJumpOutS : std_logic;
	signal EX_MEM_IsBranchOutS : std_logic;

	signal EX_DestRegOutS  : std_logic;
	signal EX_ALUSrcBOut   : std_logic_vector((ALUB_MUX_SZ-1) downto 0);
	signal EX_ALUOPOut     : std_logic_vector((ALUOP_WIDTH-1) downto 0);

	signal BankR1OutS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal BankR2OutS   : std_logic_vector((DATA_WIDTH-1) downto 0);

	signal EX_OPOutS			 : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal EX_firstSegOutS	 : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal EX_secondSegOut   : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal EX_lastSegOut	    : std_logic_vector((RADD_WIDTH-1) downto 0);	--Last 6 bits
	signal EX_extLastSegOut  : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--EX
	signal CorrectData1    : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal CorrectData2    : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal AluBData    : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal EX_AluCompS : std_logic; --Input compare result
	signal EX_AluResS  : std_logic_vector((DATA_WIDTH-1) downto 0); --Output Data
	
	signal EX_DestinyAddr  : std_logic_vector((RADD_WIDTH-1) downto 0); --Output Data
	
	signal MEM_WB_WriteEnS  : std_logic;
	signal MEM_WB_WtUserRegS: std_logic;
	signal MEM_WB_DataSelS  : std_logic;

	signal MEM_DataWtS  : std_logic;
	signal MEM_IsJumpS  : std_logic;
	signal MEM_IsBranchS : std_logic;

	signal MEM_OPS  	    : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal MEM_DestRegS    : std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
	signal MEM_exLastSegS  : std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal

	signal MEM_AluCmpS     : std_logic;
	signal MEM_AluRes      : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--MEM
	signal MEM_WriteDataS  : std_logic_vector((DATA_WIDTH-1) downto 0);  --Register 2 out
	
	signal RAMDataS: std_logic_vector((DATA_WIDTH-1) downto 0);
	signal WB_WriteEnR  :  std_logic;
	signal WB_WtUserRegOutS:  std_logic;
	signal WB_DataSelR  :  std_logic;

	signal WB_OPR  	     :  std_logic_vector((OP_WIDTH-1) downto 0); --4 bits operation ID
	signal WB_DestRegR    :  std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
	
	signal WB_DataMemR   :  std_logic_vector((DATA_WIDTH-1) downto 0);
	signal WB_AluResR     :  std_logic_vector((DATA_WIDTH-1) downto 0);
	
	
	--WB
	signal WB_WriteDataS  : std_logic_vector((DATA_WIDTH-1) downto 0);  --Register 2 out

	signal WB_CacheWriteEn  :  std_logic;
	signal WB_DestRegS    : std_logic_vector((RADD_WIDTH-1) downto 0);
	
	
	--Controller signals
	signal reset			  : std_logic;
	
	--IF
	signal StallEn		  : std_logic;
	signal IFIDWriteEn   : std_logic;
	
	--ID
	signal ID_lastSegExtMode: std_logic;
	signal IDEXWriteEn   : std_logic;
	
	signal ID_WB_WriteEnIn   : std_logic;
	signal ID_WB_DataSelIn   : std_logic;
	signal ID_WB_WtUserRegIn : std_logic;

	signal ID_MEM_DataWtIn   : std_logic;
	signal ID_MEM_IsJumpIn   : std_logic;
	signal ID_MEM_IsBranchIn : std_logic;

	signal ID_EX_DestRegIn   : std_logic;
	signal ID_EX_ALUSrcBIn   : std_logic_vector((ALUB_MUX_SZ-1) downto 0);
	signal ID_EX_ALUOPIn     : std_logic_vector((ALUOP_WIDTH-1) downto 0);
	
	--EX
	signal EXMEMWriteEn : std_logic;
	signal FWData1Sel : std_logic_vector((FW_WIDTH-1) downto 0);
	signal FWData2Sel : std_logic_vector((FW_WIDTH-1) downto 0);
	
	--MEM
	signal MEMWBWriteEn : std_logic;
	
	signal FW_R1Read : std_logic;
	signal FW_R2Read : std_logic;
	
begin

	--IF
	PCSumS <= (PCOutS + 1);

	PCInS <= (PCSumS) when (PCSourceSelS = '0') else (MEM_exLastSegS);

	PCRegister : BasicRegister port map(clock, reset, (not StallEn), PCInS, PCOutS);

	InstMemory : InstructionMemory port map(clock, reset, PCOutS((INST_WIDTH-1) downto 0), InstOutS);

	IF_IDInstInS <=  (x"0000") when (StallEn = '1') else (InstOutS); 

	IF_ID_InterfaceRegister : IF_IDRegister port map(clock, (reset or PCSourceSelS), IFIDWriteEn, IF_IDInstInS, ID_OPS, ID_firstSegS, ID_secondSegS, ID_lastSegS);
	
	--ID
	CacheRegisterBank : RegisterBank port map(clock, reset, WB_CacheWriteEn, ID_firstSegS, ID_secondSegS, WB_DestRegS, WB_WriteDataS, Reg1DataS, Reg2DataS);
	
	lastSegCustomExtend : customExtend port map(ID_lastSegExtMode, ID_lastSegS, ID_extdLastSegS);
	
	Reg1FinalDataS <= WB_WriteDataS when ((WB_DestRegS = ID_firstSegS) and (WB_CacheWriteEn = '1')) else (Reg1DataS);
	Reg2FinalDataS <= WB_WriteDataS when ((WB_DestRegS = ID_secondSegS) and (WB_CacheWriteEn = '1')) else (Reg2DataS);
	
	ID_EX_Register : ID_EXRegister port map(clock, (reset or PCSourceSelS), IDEXWriteEn, ID_WB_WriteEnIn, ID_WB_WtUserRegIn, ID_WB_DataSelIn, ID_MEM_DataWtIn, ID_MEM_IsJumpIn, ID_MEM_IsBranchIn,
														 ID_EX_DestRegIn, ID_EX_ALUSrcBIn, ID_EX_ALUOPIn, Reg1FinalDataS, Reg2FinalDataS, ID_OPS, ID_firstSegS, ID_secondSegS, ID_lastSegS((RADD_WIDTH-1) downto 0), 
														 ID_extdLastSegS, EX_WB_WriteEnOutS, EX_WB_WtUserRegOutS, EX_WB_DataSelOutS, EX_MEM_DataWtOutS, EX_MEM_IsJumpOutS, EX_MEM_IsBranchOutS, EX_DestRegOutS,
														 EX_ALUSrcBOut, EX_ALUOPOut, BankR1OutS, BankR2OutS, EX_OPOutS, EX_firstSegOutS, EX_secondSegOut, EX_lastSegOut, EX_extLastSegOut);
														 
	--EX
	with FWData1Sel select
		CorrectData1 <= BankR1OutS when "00",
							 MEM_WriteDataS when "01",
							 WB_WriteDataS  when "10",
							 (others => '0')  when others;
							 
	with FWData2Sel select
		CorrectData2 <= BankR2OutS when "00",
							 MEM_WriteDataS when "01",
							 WB_WriteDataS  when "10",
							 (others => '0')  when others;
							 
	with EX_ALUSrcBOut select
		AluBData   <= CorrectData2     when "00",
							 EX_extLastSegOut    when "01",
							 userEntry        when "10",
							 (others => '0')  when others;
							 

	EX_DestinyAddr <= (EX_secondSegOut) when (EX_DestRegOutS = '0') else (EX_lastSegOut);

	ArithmeticLogicUnit : ALU port map(CorrectData1, AluBData, EX_ALUOPOut, EX_AluCompS, EX_AluResS);

	EX_MEM_Register : EX_MEMRegister port map(clock, reset, EXMEMWriteEn, EX_WB_WriteEnOutS, EX_WB_WtUserRegOutS, EX_WB_DataSelOutS, EX_MEM_DataWtOutS, EX_MEM_IsJumpOutS, EX_MEM_IsBranchOutS,
															EX_OPOutS, EX_DestinyAddr, EX_extLastSegOut, EX_AluCompS, EX_AluResS, MEM_WB_WriteEnS, MEM_WB_WtUserRegS, MEM_WB_DataSelS, MEM_DataWtS, MEM_IsJumpS, MEM_IsBranchS,
															MEM_OPS, MEM_DestRegS, MEM_exLastSegS, MEM_AluCmpS, MEM_AluRes);
															
	--MEM
	MEM_WriteDataS <= MEM_AluRes;
	
	PCSourceSelS <= (MEM_IsJumpS OR (MEM_AluCmpS AND MEM_IsBranchS));

	RAMDataMemory : DataMemory port map(clock, reset, MEM_DataWtS, MEM_exLastSegS((ADDR_WIDTH-1) downto 0), MEM_AluRes, RAMDataS);
	
	MEM_WB_Register : MEM_WBRegister port map(clock, reset, MEMWBWriteEn, MEM_WB_WriteEnS, MEM_WB_WtUserRegS, MEM_WB_DataSelS, MEM_OPS, MEM_DestRegS, RAMDataS, MEM_AluRes, WB_CacheWriteEn, WB_WtUserRegOutS, WB_DataSelR,
														   WB_OPR, WB_DestRegS, WB_DataMemR, WB_AluResR);

	--WB
	WB_WriteDataS <= (WB_DataMemR) when (WB_DataSelR = '0') else (WB_AluResR);
	
	UserOutputRegister : BasicRegister port map(clock, reset, WB_WtUserRegOutS, WB_WriteDataS, userOutput);
	
	--Hazzard Dection unit	
	StallOn <= StallEn;
	
	IF_secondSegS   <= InstOutS((SS_WIDTH-1 + LS_WIDTH) downto LS_WIDTH); -- 6 to 8
	IF_firstSegS    <= InstOutS((FS_WIDTH-1 + SS_WIDTH + LS_WIDTH) downto (SS_WIDTH + LS_WIDTH)); -- 9 to 11
	IF_OPS 		    <= InstOutS((DATA_WIDTH-1) downto (DATA_WIDTH - OP_WIDTH)); --12 to 15
	
	ID_OPSR <= ID_OPS;
	ID_firstSegSR <= ID_firstSegS;
	ID_secondSegSR <= ID_secondSegS;
	ID_lastSegSR <= ID_lastSegS;
	MEM_AluCmpSR <= MEM_AluCmpS;

	process(IF_OPS, IF_firstSegS, IF_secondSegS, ID_OPS, ID_secondSegS)
	begin
		if(ID_OPS = "0111") then
			case IF_OPS is 
				when "0001" | "0011" | "0100" | "0101" | "1100" =>
					if((ID_secondSegS = IF_firstSegS) OR (ID_secondSegS = IF_secondSegS)) then
						StallEn <= '1';
					else
						StallEn <= '0';
					end if;
						
				when "0010" =>
					if(ID_secondSegS = IF_firstSegS) then
						StallEn <= '1';
					else
						StallEn <= '0';
					end if;
				
				when "1000" | "1010" | "1011" =>
					if(ID_secondSegS = IF_secondSegS) then
						StallEn <= '1';
					else
						StallEn <= '0';
					end if;

				when others =>
					StallEn <= '0';
			end case;
		else
			StallEn <= '0';
		end if;
	end process;
	
	--Controller
	WB_WriteDataSR <= WB_WriteDataS;
	ALUAR <= CorrectData1;
	ALUBR <= AluBData;
	WB_WtUserRegOutSR <= WB_WtUserRegOutS;
	Data1EX <= BankR1OutS;
	Data2EX <= BankR2OutS;
	
	PCSel <= PCSourceSelS;
	PCOUTR <= PCOutS;
	
	process(clock) 
	begin 
		if(rising_edge(clock)) then
			currentState <= nextState; 
		end if;
	end process;
	
	process(currentState, ID_OPS, ID_secondSegS, ID_lastSegS) --Controller FSM 
	begin
		case currentState is
			when RESET_S => --Reset State
				reset	<= '1';
				
				--IF
				IFIDWriteEn <= '1';
				
				--ID
				ID_lastSegExtMode <= '0';
				IDEXWriteEn <= '1';
				
				ID_WB_WriteEnIn <= '0';
				ID_WB_DataSelIn <= '0';
				ID_WB_WtUserRegIn <= '0';

				ID_MEM_DataWtIn <= '0';
				ID_MEM_IsJumpIn <= '0';
				ID_MEM_IsBranchIn <= '0';

				ID_EX_DestRegIn <= '0';
				ID_EX_ALUSrcBIn <= (others => '0');
				ID_EX_ALUOPIn <= (others => '0');
				
				--EX
				EXMEMWriteEn <= '1';
				
				--MEM
				MEMWBWriteEn <= '1';
						
				nextState <= OPERATION_S;
				
			when OPERATION_S => --Reset State
				reset	<= '0';
				
				IFIDWriteEn  <= '1';
				IDEXWriteEn  <= '1';
				EXMEMWriteEn <= '1';
				MEMWBWriteEn <= '1';
				
				case ID_OPS is 
					when x"1" | x"3" | x"4" | x"B" => --ADD or NOR or AND
						ID_lastSegExtMode <= '0';
						
						case (ID_lastSegS((RADD_ADDR-1) downto 0)) is
							when "000" =>
								ID_WB_WriteEnIn <= '0';
								
							when others =>
								ID_WB_WriteEnIn <= '1';
						end case;

						ID_WB_DataSelIn <= '1';
						ID_WB_WtUserRegIn <= '0';

						ID_MEM_DataWtIn <= '0';
						ID_MEM_IsJumpIn <= '0';
						ID_MEM_IsBranchIn <= '0';

						ID_EX_DestRegIn <= '1';
						ID_EX_ALUSrcBIn <= (others => '0');
						
						case ID_OPS is
							when x"1" | x"B" =>
								ID_EX_ALUOPIn <= "001";
								
							when x"3" =>
								ID_EX_ALUOPIn <= "010";
								
							when x"4" =>
								ID_EX_ALUOPIn <= "011";
								
							when others =>
								ID_EX_ALUOPIn <= "000";
						end case;
						
					when x"2" | x"9" => --ADDI
						ID_lastSegExtMode <= '1';
						
						case(ID_secondSegS) is
							when "000" =>
								ID_WB_WriteEnIn <= '0';
							
							when others =>
								ID_WB_WriteEnIn <= '1';
						end case;
						
						ID_WB_DataSelIn <= '1';
						ID_WB_WtUserRegIn <= '0';

						ID_MEM_DataWtIn <= '0';
						ID_MEM_IsJumpIn <= '0';
						ID_MEM_IsBranchIn <= '0';

						ID_EX_DestRegIn <= '0';
						
						case ID_OPS is
							when x"9" =>
								ID_EX_ALUSrcBIn <= "10";
							
							when others =>
								ID_EX_ALUSrcBIn <= "01";
						end case;
						
						ID_EX_ALUOPIn <= "001";
					
					when x"5" | x"6" | x"C" =>
						ID_lastSegExtMode <= '0';
						
						ID_WB_WriteEnIn <= '0';

						ID_WB_DataSelIn <= '0';
						ID_WB_WtUserRegIn <= '0';

						ID_MEM_DataWtIn <= '0';
						
						case ID_OPS is
							when x"6" =>
								ID_MEM_IsJumpIn <= '1';
								
							when others =>
								ID_MEM_IsJumpIn <= '0';
						end case;
						
						case ID_OPS is
							when x"5" | x"C" =>
								ID_MEM_IsBranchIn <= '1';
								
							when others =>
								ID_MEM_IsBranchIn <= '0';
						end case;
							
						ID_EX_DestRegIn <= '0';
						ID_EX_ALUSrcBIn <= "00";
						
						
						case ID_OPS is
							when x"5" => 
								ID_EX_ALUOPIn <= "100";
								
							when x"C" =>
								ID_EX_ALUOPIn <= "101";
								
						   when others =>
							ID_EX_ALUOPIn <= "000";
						end case;
						
					when x"7" | x"8" =>
						ID_lastSegExtMode <= '0';
						
						case ID_OPS is
							when x"7" =>
								ID_WB_WriteEnIn <= '1';
								ID_MEM_DataWtIn <= '0';
								ID_EX_ALUOPIn <= "000";	
							
							when others =>
								ID_WB_WriteEnIn <= '0';
								ID_MEM_DataWtIn <= '1';
								ID_EX_ALUOPIn <= "001";	
						end case;
						
						ID_WB_DataSelIn <= '0';
						ID_WB_WtUserRegIn <= '0';

						ID_MEM_IsJumpIn <= '0';
						ID_MEM_IsBranchIn <= '0';

						ID_EX_DestRegIn <= '0';
						ID_EX_ALUSrcBIn <= "00";
						
					when x"A" => --OUT
						ID_lastSegExtMode <= '0';
						ID_WB_WriteEnIn <= '0';
						
						ID_WB_DataSelIn <= '1';
						ID_WB_WtUserRegIn <= '1';

						ID_MEM_DataWtIn <= '0';
						ID_MEM_IsJumpIn <= '0';
						ID_MEM_IsBranchIn <= '0';

						ID_EX_DestRegIn <= '0';
						ID_EX_ALUSrcBIn <= (others => '0');
						ID_EX_ALUOPIn <= "001";						
						
					when others =>
						ID_lastSegExtMode <= '0';
						
						ID_WB_WriteEnIn <= '0';
						
						ID_WB_DataSelIn <= '0';
						ID_WB_WtUserRegIn <= '0';

						ID_MEM_DataWtIn <= '0';
						ID_MEM_IsJumpIn <= '0';
						ID_MEM_IsBranchIn <= '0';

						ID_EX_DestRegIn <= '0';
						ID_EX_ALUSrcBIn <= (others => '0');
						ID_EX_ALUOPIn <= (others => '0');
						
				end case;
				
				nextState <= OPERATION_S;
				
			when others => --Reset State
				reset	<= '1';
				
				--IF
				IFIDWriteEn <= '1';
				
				--ID
				ID_lastSegExtMode <= '0';
				IDEXWriteEn <= '1';
				
				ID_WB_WriteEnIn <= '0';
				ID_WB_DataSelIn <= '0';
				ID_WB_WtUserRegIn <= '0';

				ID_MEM_DataWtIn <= '0';
				ID_MEM_IsJumpIn <= '0';
				ID_MEM_IsBranchIn <= '0';

				ID_EX_DestRegIn <= '0';
				ID_EX_ALUSrcBIn <= (others => '0');
				ID_EX_ALUOPIn <= (others => '0');
				
				--EX
				EXMEMWriteEn <= '1';
				
				--MEM
				MEMWBWriteEn <= '1';
						
				nextState <= RESET_S;
	
		end case;
	end process;
	
	--Forwarding Unit				  
   with EX_OPOutS select
		FW_R1Read <= '1' when x"1" to x"5" | x"8" to x"C",
						 '0' when others;
						 
	with EX_OPOutS select
		FW_R2Read <= '1' when x"1" | x"3" to x"5" | x"8" | x"A" to x"C",
						 '0' when others;
						 
	IFFW1 <= '1' when ((WB_DestRegS = ID_firstSegS) and (WB_CacheWriteEn = '1')) else '0';
	IFFW2 <= '1' when ((WB_DestRegS = ID_secondSegS) and (WB_CacheWriteEn = '1')) else '0';
	
	FWData1SelR <= FWData1Sel;
	FWData2SelR <= FWData2Sel;
	
 	process(FW_R1Read, FW_R2Read, EX_firstSegOutS, EX_secondSegOut, WB_DestRegS, MEM_DestRegS, MEM_WB_WriteEnS, WB_CacheWriteEn)
	begin	
		if((FW_R1Read = '1') AND (MEM_WB_WriteEnS = '1') AND (EX_firstSegOutS = MEM_DestRegS)) then
			FWData1Sel <= "01";
		elsif((FW_R1Read = '1') AND (WB_CacheWriteEn = '1') AND (EX_firstSegOutS = WB_DestRegS)) then
			FWData1Sel <= "10";
		else
			FWData1Sel <= "00";
		end if;
		
		if((FW_R2Read = '1') AND (MEM_WB_WriteEnS = '1') AND (EX_secondSegOut = MEM_DestRegS)) then
			FWData2Sel <= "01";
		elsif((FW_R2Read = '1') AND (WB_CacheWriteEn = '1') AND (EX_secondSegOut = WB_DestRegS)) then
			FWData2Sel <= "10";
		else
			FWData2Sel <= "00";
		end if;
	end process;
end pp;