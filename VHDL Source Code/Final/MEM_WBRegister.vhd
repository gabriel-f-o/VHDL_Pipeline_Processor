library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity MEM_WBRegister is --Memory access / Write Back interface register
	generic(
		RADD_ADDR  : natural := 3; --Second segment width
		
		DATA_WIDTH : natural := 16 --16 Bits data	
	);
	port(
		clock		       : in  std_logic; --Clock
		reset		       : in  std_logic; --Reset
		WriteEn         : in  std_logic;

		--WB control signals
		MEM_WB_WriteEn  : in std_logic;
		MEM_WB_WtUserReg: in std_logic;
		MEM_WB_DataSel  : in std_logic;
		
		--The only part of the instruction that is useful now
		MEM_DestReg     : in  std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
		
		--Save useful data
		MEM_RAMData     : in  std_logic_vector((DATA_WIDTH-1) downto 0);
		MEM_AluRes      : in  std_logic_vector((DATA_WIDTH-1) downto 0);
		
		--Outputs WB control signals
		WB_WriteEn      : out std_logic;
		WB_WtUserReg    : out std_logic;
		WB_DataSel      : out std_logic;

		--Outputs destination register
		WB_DestReg      : out std_logic_vector((RADD_ADDR-1) downto 0); --Last 6 bits
		
		--RAM and ALU res data
		WB_RAMData      : out std_logic_vector((DATA_WIDTH-1) downto 0);
		WB_AluRes       : out std_logic_vector((DATA_WIDTH-1) downto 0)
	);
end entity;

architecture memWb of MEM_WBRegister is
begin
	process(clock, reset) --Called when clock or reset changes
	begin
		if(reset = '1') then --Reset makes everything go to 0
			WB_WriteEn      <= '1';
			WB_WtUserReg    <= '1';
			WB_DataSel      <= '1';

			WB_DestReg      <= (others => '0');
			
			WB_RAMData      <= (others => '0');
			WB_AluRes       <= (others => '0');
		
		elsif(rising_edge(clock)) then --On clock
			if(WriteEn = '1') then --On WriteEn enabled, update output
				WB_WriteEn      <= MEM_WB_WriteEn;
				WB_WtUserReg    <= MEM_WB_WtUserReg;
				WB_DataSel      <= MEM_WB_DataSel;

				WB_DestReg      <= MEM_DestReg;
				
				WB_RAMData      <= MEM_RAMData;
				WB_AluRes       <= MEM_AluRes;
			end if;
		end if;
		
	end process;
end memWb;