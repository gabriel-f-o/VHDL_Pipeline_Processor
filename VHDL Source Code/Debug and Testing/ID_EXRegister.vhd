library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ID_EXRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
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
end entity;

architecture idEx of ID_EXRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			WBWriteEnOut  <= '0';
			WBDataSelOut  <= '0';
			WBWtUserRegOut<= '0';
			
			MEMDataWtOut  <= '0';
			MEMIsJumpOut  <= '0';
			MEMIsBranchOut<= '0';
			
			EXDestRegOut  <= '0';
			EXALUSrcBOut  <= (others => '0');
			EXALUOPOut	  <= (others => '0'); --Operation
			
			BankR1Out     <= (others => '0'); --Input data
			BankR2Out     <= (others => '0'); --Input data
					
			OPOut 	     <= (others => '0');	--4 bits operation ID
			firstSegOut   <= (others => '0');	--First 3 bits after OP
			secondSegOut  <= (others => '0');	--3 bits after first
			lastSegOut    <= (others => '0'); --Last 6 bits
			exLastSegOut  <= (others => '0'); --Extended last signal

	
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				WBWriteEnOut  <= WBWriteEnIn;
				WBDataSelOut  <= WBDataSelIn;
				WBWtUserRegOut<= WBWtUserRegIn;
				
				MEMDataWtOut  <= MEMDataWtIn;
				MEMIsJumpOut  <= MEMIsJumpIn;
				MEMIsBranchOut<= MEMIsBranchIn;
				
				EXDestRegOut  <= EXDestRegIn;
				EXALUSrcBOut  <= EXALUSrcBIn;
				EXALUOPOut	  <= EXALUOPIn; --Operation
				
				BankR1Out     <= BankR1In; --Input data
				BankR2Out     <= BankR2In; --Input data
						
				OPOut 	     <= OPIn;	--4 bits operation ID
				firstSegOut   <= firstSegIn;	--First 3 bits after OP
				secondSegOut  <= secondSegIn;	--3 bits after first
				lastSegOut    <= lastSegIn; --Last 6 bits
				exLastSegOut  <= exLastSegIn; --Extended last signal
			end if;
		end if;
		
	end process;
end idEx;