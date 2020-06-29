library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity EX_MEMRegister is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
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
end entity;

architecture exMem of EX_MEMRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			WBWriteEnOut  <= '0';
			WBWtUserRegOut<= '0';
			WBDataSelOut  <= '0';
			
			MEMDataWtOut  <= '0';
			MEMIsJumpOut  <= '0';
			MEMIsBranchOut<= '0';
			
			OPOut  	     <= (others => '0');	--4 bits operation ID
			DestRegOut    <= (others => '0'); --Last 6 bits
			exLastSegOut  <= (others => '0'); --Extended last signal
			
			AluCmpOut     <= '0';
			AluResOut     <= (others => '0');

	
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				WBWriteEnOut  <= WBWriteEnIn;
				WBWtUserRegOut<= WBWtUserRegIn;
				WBDataSelOut  <= WBDataSelIn;
				
				MEMDataWtOut  <= MEMDataWtIn;
				MEMIsJumpOut  <= MEMIsJumpIn;
				MEMIsBranchOut<= MEMIsBranchIn;
				
				OPOut  	     <= OPIn;	--4 bits operation ID
				DestRegOut    <= DestRegIn; --Last 6 bits
				exLastSegOut  <= exLastSegIn; --Extended last signal
				
				AluCmpOut     <= AluCmpIn;
				AluResOut     <= AluResIn;
			end if;
		end if;
		
	end process;
end exMem;