library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity MemoryAccess is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
	   ADDR_WIDTH : natural := 4;
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
		MEM_WBWriteEn : in  std_logic;
		
		WBWriteEnS  : in std_logic;
		WBWtUserRegInS: in std_logic;
		WBDataSelS  : in std_logic;
		
		MEMDataWtS  : in std_logic;
		MEMIsJumpS  : in std_logic;
		MEMIsBranchS : in std_logic;
		
		OPS  	     : in std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
		DestRegS    : in std_logic_vector((SS_WIDTH-1) downto 0); --Last 6 bits
		exLastSegS  : in std_logic_vector((DATA_WIDTH-1) downto 0); --Extended last signal
		
		AluCmpS     : in std_logic;
		AluRes     : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		PCSourceSelS : out std_logic;
		
		WBWriteEnR  : out std_logic;
		WBWtUserRegOutS: out std_logic;
		WBDataSelR  : out std_logic;

		OPR  	     : out std_logic_vector((OP_WIDTH-1) downto 0); --4 bits operation ID
		DestRegR    : out std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
		
		DataMemR   : out std_logic_vector((DATA_WIDTH-1) downto 0);
		AluResR     : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		RAMDataR: out std_logic_vector((DATA_WIDTH-1) downto 0)
		
	);
end entity;

architecture memStep of MemoryAccess is
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

	signal RAMDataS: std_logic_vector((DATA_WIDTH-1) downto 0);
	
begin
	RAMDataR <= RAMDataS;
	
	PCSourceSelS <= (MEMIsJumpS OR (AluCmpS AND MEMIsBranchS));

	RAMDataMemory : DataMemory port map(clock, reset, MEMDataWtS, exLastSegS((ADDR_WIDTH-1) downto 0), AluRes, RAMDataS);
	
	MEM_WB_Register : MEM_WBRegister port map(clock, reset, MEM_WBWriteEn, WBWriteEnS, WBWtUserRegInS, WBDataSelS, OPS, DestRegS, RAMDataS, AluRes, WBWriteEnR, WBWtUserRegOutS, WBDataSelR,
														   OPR, DestRegR, DataMemR, AluResR);

end memStep;