library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity InstructionFetch is --Ram memory, for simplicity sake, we'll keep only 2^6 regiters
	generic(
		INST_WIDTH : natural := 4; --4 Bits instruction address
		
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
		StallEn       : in std_logic;
		PCSourceSel   : in std_logic;
		IFIDWriteEn : in std_logic;		
		
	   PCInR 		: out std_logic_vector((DATA_WIDTH-1) downto 0);
	   PCOutR 		: out std_logic_vector((DATA_WIDTH-1) downto 0);
	   InstOutR 	: out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		IF_IDInstInR : out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		MEMexLastSegS : in std_logic_vector((DATA_WIDTH-1) downto 0);
		
		
		PCSumR 		: out std_logic_vector((DATA_WIDTH-1) downto 0);
		
		OPR			 : out std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	   firstSegR	 : out std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	   secondSegR   : out std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	   lastSegR 	 : out std_logic_vector((LS_WIDTH-1) downto 0)	--Last 6 bits
	);
end entity;

architecture ifStep of InstructionFetch is

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
	
	--signal PCSourceSelS : std_logic;
	--signal MEMexLastSegS : std_logic_vector((DATA_WIDTH-1) downto 0) := (others => '0');
	
	signal PCInS 		: std_logic_vector((DATA_WIDTH-1) downto 0);
	signal PCOutS 		: std_logic_vector((DATA_WIDTH-1) downto 0);
	
	--signal StallEnS : std_logic;
	signal PCSum		: std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal InstOutS	: std_logic_vector((DATA_WIDTH-1) downto 0);
	
	signal IF_IDInstInS : std_logic_vector((DATA_WIDTH-1) downto 0);	
	
	
	signal OPS			 : std_logic_vector((OP_WIDTH-1) downto 0);	--4 bits operation ID
	signal firstSegS	 : std_logic_vector((FS_WIDTH-1) downto 0);	--First 3 bits after OP
	signal secondSegS  : std_logic_vector((SS_WIDTH-1) downto 0);	--3 bits after first
	signal lastSegS	 : std_logic_vector((LS_WIDTH-1) downto 0);	--Last 6 bits
	signal extdLastSegS : std_logic_vector((DATA_WIDTH-1) downto 0);
	
begin
	--Debugging stuff
	
	PCInR <= PCInS;
	PCOutR <= PCOutS;
	
	InstOutR <= InstOutS;
	
	--MEMexLastSegR <= MEMexLastSegS;
	
	PCSumR <= PCSum;
	
	IF_IDInstInR <= IF_IDInstInS;
	
	
	OPR <= OPS;
	firstSegR <= firstSegS;
	secondSegR <= secondSegS;
	lastSegR <= lastSegS;
	
	PCSum <= (PCOutS + 1);

	PCInS <= (PCSum) when (PCSourceSel ='0') else (MEMexLastSegS);
	
	PCRegister : BasicRegister port map(clock, reset, (not StallEn), PCInS, PCOutS);
	
	InstMemory : InstructionMemory port map(clock, reset, PCOutS((INST_WIDTH-1) downto 0), InstOutS);
	
	IF_IDInstInS <=  (x"0000") when (StallEn = '1') else (InstOutS); 
	
	IF_ID_InterfaceRegister : IF_IDRegister port map(clock, (reset or PCSourceSel), IFIDWriteEn, IF_IDInstInS, OPS, firstSegS, secondSegS, lastSegS);

end ifStep;