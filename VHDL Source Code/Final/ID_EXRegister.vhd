library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ID_EXRegister is --Instruction Decode / Execution interface register
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
end entity;

architecture idEx of ID_EXRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			EX_WB_WriteEn   <= '0';
			EX_WB_WtUserReg <= '0';
			EX_WB_DataSel   <= '0';

			EX_MEM_DataWt   <= '0';
			EX_MEM_IsJump   <= '0';
			EX_MEM_IsBranch <= '0';

			EX_DestReg      <= '0';
			EX_AluSrcBSel   <= (others => '0');
			EX_AluOp        <= (others => '0');
			 
			EX_BankR1Data   <= (others => '0');
			EX_BankR2Data   <= (others => '0');

			EX_OP           <= (others => '0');
			EX_firstSeg     <= (others => '0');
			EX_secondSeg    <= (others => '0');
			EX_lastSeg      <= (others => '0');
			EX_exLastSeg    <= (others => '0');
	
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				EX_WB_WriteEn   <= ID_WB_WriteEn;
				EX_WB_WtUserReg <= ID_WB_WtUserReg;
				EX_WB_DataSel   <= ID_WB_DataSel;

				EX_MEM_DataWt   <= ID_MEM_DataWt;
				EX_MEM_IsJump   <= ID_MEM_IsJump;
				EX_MEM_IsBranch <= ID_MEM_IsBranch;

				EX_DestReg      <= ID_EX_DestReg;
				EX_AluSrcBSel   <= ID_EX_AluSrcBSel;
				EX_AluOp        <= ID_EX_AluOp;
				 
				EX_BankR1Data   <= ID_BankR1Data;
				EX_BankR2Data   <= ID_BankR2Data;

				EX_OP           <= ID_OP;
				EX_firstSeg     <= ID_firstSeg;
				EX_secondSeg    <= ID_secondSeg;
				EX_lastSeg      <= ID_lastSeg;
				EX_exLastSeg    <= ID_exLastSeg;
			end if;
		end if;
		
	end process;
end idEx;