library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity InstructionDecode is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
		ALUOP_WIDTH : natural := 3; --3 Bits operation ID
		ALUB_MUX_SZ : natural := 2;
	
		OP_WIDTH	  : natural := 4; --OP width
		FS_WIDTH	  : natural := 3; --First segment width
		SS_WIDTH	  : natural := 3; --Second segment width
		LS_WIDTH   : natural := 6; --Last segment width
		
		RADD_WIDTH : natural := 3;   --3 Bits register bank address
			
		DATA_WIDTH : natural := 16 --16 Bits data
	);
	port(
		clock		     : in  std_logic; --Clock
		reset			  : in  std_logic;
		PCSourceSel   : in std_logic;
		
		CacheWriteEn  : in  std_logic;
		lastSegExtMode: in  std_logic;
		
		IDEXWriteEn   : in std_logic;
		
		WBWriteEnIn   : in std_logic;
		WBDataSelIn   : in std_logic;
		WBWtUserRegIn : in std_logic;
		
		MEMDataWtIn   : in std_logic;
		MEMIsJumpIn   : in std_logic;
		MEMIsBranchIn : in std_logic;
		
		EXDestRegIn   : in std_logic;
		EXALUSrcBIn   : in std_logic_vector((ALUB_MUX_SZ-1) downto 0);
		EXALUOPIn     : in std_logic_vector((ALUOP_WIDTH-1) downto 0);
		
		
		OPS			 : in std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	   firstSegS	 : in std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	   secondSegS   : in std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	   lastSegS	    : in std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
		
		WBDestRegS  : in std_logic_vector((RADD_WIDTH-1) downto 0);
		WBWriteDataS: in std_logic_vector((DATA_WIDTH-1) downto 0);  --Register 2 out
		
		
		EX_WBWriteEnOutS : out std_logic;
		EX_WBDataSelOutS : out std_logic;
		EX_WBWtUserRegOutS : out std_logic;
		
		EX_MEMDataWtOutS : out std_logic;
		EX_MEMIsJumpOutS : out std_logic;
		EX_MEMIsBranchOutS : out std_logic;
		
		EXDestRegOutS  : out std_logic;
		EXALUSrcBOut   : out std_logic_vector((ALUB_MUX_SZ-1) downto 0);
		EXALUOPOut      : out std_logic_vector((ALUOP_WIDTH-1) downto 0);
		
		BankR1OutS   : out std_logic_vector((DATA_WIDTH-1) downto 0);
		BankR2OutS   : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		EX_OPOutS			 : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	   EX_firstSegOutS	 : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	   EX_secondSegOut   : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	   EX_lastSegOut	    : out std_logic_vector((RADD_WIDTH-1) downto 0);	--Last 6 bits
		EX_extLastSegOut : out std_logic_vector((DATA_WIDTH-1) downto 0);

		extdLastSegR: out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		Reg1DataR   : out std_logic_vector((DATA_WIDTH-1) downto 0);
		Reg2DataR   : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		Reg1FinalDataR   : out std_logic_vector((DATA_WIDTH-1) downto 0);
	   Reg2FinalDataR   : out std_logic_vector((DATA_WIDTH-1) downto 0)
	);
end entity;

architecture idStep of InstructionDecode is
	
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

	signal extdLastSegS: std_logic_vector((DATA_WIDTH-1) downto 0); 	--Last 6 bits
	
	signal Reg1DataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2DataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal Reg1FinalDataS   : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal Reg2FinalDataS   : std_logic_vector((DATA_WIDTH-1) downto 0);

begin
	extdLastSegR <= extdLastSegS;
	Reg1DataR <= Reg1DataS;
	Reg2DataR <= Reg2DataS;
	
	Reg1FinalDataR <= Reg1FinalDataS;
	Reg2FinalDataR <= Reg2FinalDataS;
	
	--Instruction Decode Stuff
	
	CacheRegisterBank : RegisterBank port map(clock, reset, CacheWriteEn, firstSegS, secondSegS, WBDestRegS, WBWriteDataS, Reg1DataS, Reg2DataS);
	
	lastSegCustomExtend : customExtend port map(lastSegExtMode, lastSegS, extdLastSegS);
	
	Reg1FinalDataS <= WBWriteDataS when ((WBDestRegS = firstSegS) and (CacheWriteEn = '1')) else (Reg1DataS);
	Reg2FinalDataS <= WBWriteDataS when ((WBDestRegS = secondSegS) and (CacheWriteEn = '1')) else (Reg2DataS);
	
	ID_EX_Register : ID_EXRegister port map(clock, (reset or PCSourceSel), IDEXWriteEn, WBWriteEnIn, WBWtUserRegIn, WBDataSelIn, MEMDataWtIn, MEMIsJumpIn, MEMIsBranchIn,
														 EXDestRegIn, EXALUSrcBIn, EXALUOPIn, Reg1FinalDataS, Reg2FinalDataS, OPS, firstSegS, secondSegS, lastSegS((RADD_WIDTH-1) downto 0), 
														 extdLastSegS, EX_WBWriteEnOutS, EX_WBWtUserRegOutS, EX_WBDataSelOutS, EX_MEMDataWtOutS, EX_MEMIsJumpOutS, EX_MEMIsBranchOutS, EXDestRegOutS,
														 EXALUSrcBOut, EXALUOPOut, BankR1OutS, BankR2OutS, EX_OPOutS, EX_firstSegOutS, EX_secondSegOut, EX_lastSegOut,
														 EX_extLastSegOut);			

end idStep;