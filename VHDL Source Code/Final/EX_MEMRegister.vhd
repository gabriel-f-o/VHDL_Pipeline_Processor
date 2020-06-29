library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity EX_MEMRegister is --Execute / Memory Access interface register
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
end entity;

architecture exMem of EX_MEMRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			MEM_WB_WriteEn  <= '0';
			MEM_WB_WtUserReg<= '0';
			MEM_WB_DataSel  <= '0';
			
			MEM_DataWt      <= '0';
			MEM_IsJump      <= '0';
			MEM_IsBranch    <= '0';
			
			MEM_DestReg     <= (others => '0');
			MEM_exLastSeg   <= (others => '0');
			
			MEM_AluComp     <= '0';
			MEM_AluRes      <= (others => '0');
	
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				MEM_WB_WriteEn  <= EX_WB_WriteEn;
				MEM_WB_WtUserReg<= EX_WB_WtUserReg;
				MEM_WB_DataSel  <= EX_WB_DataSel;
				
				MEM_DataWt      <= EX_MEM_DataWt;
				MEM_IsJump      <= EX_MEM_IsJump;
				MEM_IsBranch    <= EX_MEM_IsBranch;
				
				MEM_DestReg     <= EX_DestReg;
				MEM_exLastSeg   <= EX_exLastSeg;
				
				MEM_AluComp     <= EX_AluComp;
				MEM_AluRes      <= EX_AluRes;
			end if;
		end if;
		
	end process;
end exMem;