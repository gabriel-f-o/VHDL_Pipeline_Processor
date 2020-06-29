library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity PLDataPath is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
	   ADDR_WIDTH : natural := 4;
		INST_WIDTH : natural := 4;
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
		reset			  : in  std_logic;
		
		--IF
		StallEn		  : in  std_logic;
		IFIDWriteEn   : in  std_logic;
		
		--ID
		ID_lastSegExtMode: in  std_logic;
		IDEXWriteEn   : in  std_logic;
		
		ID_WB_WriteEnIn   : in std_logic;
		ID_WB_DataSelIn   : in std_logic;
		ID_WB_WtUserRegIn : in std_logic;

		ID_MEM_DataWtIn   : in std_logic;
		ID_MEM_IsJumpIn   : in std_logic;
		ID_MEM_IsBranchIn : in std_logic;

		ID_EX_DestRegIn   : in std_logic;
		ID_EX_ALUSrcBIn   : in std_logic_vector((ALUB_MUX_SZ-1) downto 0);
		ID_EX_ALUOPIn     : in std_logic_vector((ALUOP_WIDTH-1) downto 0);
		
		--EX
		EXMEMWriteEn : in  std_logic;
		FWData1Sel : in std_logic_vector((FW_WIDTH-1) downto 0);
		FWData2Sel : in std_logic_vector((FW_WIDTH-1) downto 0);
		userEntry     : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		--MEM
		MEMWBWriteEn : in std_logic;
		
		--WB
		userOutput : out std_logic_vector((DATA_WIDTH-1) downto 0)
		
	);
end entity;

architecture dataPath of PLDataPath is
	
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
	
end dataPath;