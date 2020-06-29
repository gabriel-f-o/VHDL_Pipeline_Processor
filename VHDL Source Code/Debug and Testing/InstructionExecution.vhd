library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity InstructionExecution is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
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
		EX_MEMWriteEn : in  std_logic;
		
		userEntry : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		EX_WBWriteEnS : in std_logic;
		EX_WBWtUserRegIn : in std_logic;
		EX_WBDataSelS : in std_logic;
		
		EX_MEMDataWtS : in std_logic;
		EX_MEMIsJumpS : in std_logic;
		EX_MEMIsBranchS : in std_logic;
		
		EXDestRegS  : in std_logic;
		EXALUSrcB   : in std_logic_vector((ALUB_MUX_SZ-1) downto 0);
		EXALUOP      : in std_logic_vector((ALUOP_WIDTH-1) downto 0);
		
		BankR1S   : in std_logic_vector((DATA_WIDTH-1) downto 0);
		BankR2S   : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		EX_OPS			 : in std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	   EX_firstSegS	 : in std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	   EX_secondSeg   : in std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	   EX_lastSeg	    : in std_logic_vector((RADD_WIDTH-1) downto 0);	--Last 6 bits
		EX_extLastSeg : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		FWWBDataS    : in std_logic_vector((DATA_WIDTH-1) downto 0);
	   FWMEMDataS   : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		FWData1Sel : in std_logic_vector((FW_WIDTH-1) downto 0);
		FWData2Sel : in std_logic_vector((FW_WIDTH-1) downto 0);
		
		WBWriteEnS  : out std_logic;
		WBWtUserRegS: out std_logic;
		WBDataSelS  : out std_logic;
		
		MEMDataWtS  : out std_logic;
		MEMIsJumpS  : out std_logic;
		MEMIsBranchS : out std_logic;
		
		OPS  	     : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
		DestRegS    : out std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
		exLastSegS  : out std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
		
		AluCmpS     : out std_logic;
		AluRes     : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		CorrectData1R    : out std_logic_vector((DATA_WIDTH-1) downto 0);
	   CorrectData2R    : out std_logic_vector((DATA_WIDTH-1) downto 0);
	
	   AluBDataR    : out std_logic_vector((DATA_WIDTH-1) downto 0)
	);
end entity;

architecture exStep of InstructionExecution is

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

	signal CorrectData1    : std_logic_vector((DATA_WIDTH-1) downto 0);
	signal CorrectData2    : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal AluBData    : std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal AluCompS : std_logic; --Input compare result
	signal AluResS  : std_logic_vector((DATA_WIDTH-1) downto 0); --Output Data
	
	signal DestinyAddr  : std_logic_vector((RADD_WIDTH-1) downto 0); --Output Data
	
begin
	CorrectData1R <= CorrectData1;
	CorrectData2R <= CorrectData2;
	
	AluBDataR <= AluBData;
			
	with FWData1Sel select
		CorrectData1 <= BankR1S when "00",
							 FWMEMDataS when "01",
							 FWWBDataS  when "10",
							 (others => '0')  when others;
							 
	with FWData2Sel select
		CorrectData2 <= BankR2S when "00",
							 FWMEMDataS when "01",
							 FWWBDataS  when "10",
							 (others => '0')  when others;
							 
	with EXALUSrcB select
		AluBData   <= CorrectData2     when "00",
							 EX_extLastSeg    when "01",
							 userEntry        when "10",
							 (others => '0')  when others;
							 
	
	DestinyAddr <= (EX_secondSeg) when (EXDestRegS = '0') else (EX_lastSeg);
	
	ArithmeticLogicUnit : ALU port map(CorrectData1, AluBData, EXALUOP, AluCompS, AluResS);
	
	EX_MEM_Register : EX_MEMRegister port map(clock, reset, EX_MEMWriteEn, EX_WBWriteEnS, EX_WBWtUserRegIn, EX_WBDataSelS, EX_MEMDataWtS, EX_MEMIsJumpS, EX_MEMIsBranchS,
														   EX_OPS, DestinyAddr, EX_extLastSeg, AluCompS, AluResS, WBWriteEnS, WBWtUserRegS, WBDataSelS, MEMDataWtS, MEMIsJumpS, MEMIsBranchS,
															OPS, DestRegS, exLastSegS, AluCmpS, AluRes);
	

end exStep;