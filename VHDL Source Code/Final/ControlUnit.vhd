library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ControlUnit is --Control unit. It sets the control signals so that the instructions can be executed properly in the data path
	generic(		
		OP_WIDTH	   : natural := 4; --OP width
		SS_WIDTH	   : natural := 3; --Second segment width
		
		RADD_WIDTH  : natural := 3; --3 Bits cache address
		
		ALUOP_WIDTH : natural := 3; --3 Bitzs operation ID
		ALUB_MUX_SZ : natural := 2  --Alu B mux selector size	
	);
	port(
		clock		         : in  std_logic; --Clock		
		
		ID_OP             : in  std_logic_vector((OP_WIDTH-1) downto 0); --ID instruction OP
		ID_secondSeg      : in  std_logic_vector((SS_WIDTH-1) downto 0); --ID second segment
		ID_lastSeg        : in  std_logic_vector((RADD_WIDTH-1) downto 0); --Last 3 bits of last segment
		
		reset				   : out std_logic; --Reset memory elements
		ID_lastSegExtMode : out std_logic; --Choses mode for last segment (0 -> zero extend; 1 -> sign extend)
		
		ID_WB_WriteEn     : out std_logic; --Set WB_WriteEn to write on cache once the instruction reaches WB step
		ID_WB_DataSel     : out std_logic; --Selects data to write on cache once the instruction reaches WB step (0 -> RAM; 1 -> Alu result)
		ID_WB_WtUserReg   : out std_logic; --Set WB_WtUserReg to write on output register once the instruction reaches WB step

		ID_MEM_DataWt     : out std_logic; --Set if the instruction wants to write on RAM (LOAD)
		ID_MEM_IsJump     : out std_logic; --Set if the instruction is a JUMP one. Used in MEM step
		ID_MEM_IsBranch   : out std_logic; --Set if the instruction is a BRANCH (BEQ or BGT) one. Used in MEM step

		ID_EX_DestReg     : out std_logic; --Selects from which segment the destiny address is stored (0 -> second segment; 1 -> last segment (last 3 bits)). Used in EX step
		ID_EX_AluBSrc     : out std_logic_vector((ALUB_MUX_SZ-1) downto 0); --Selects the data source for Alu B (0 -> Data comming from cache or forwarded; 1 -> Last segment extended; 2 -> User input; 3 -> all 0 (unused))
		ID_EX_AluOp       : out std_logic_vector((ALUOP_WIDTH-1) downto 0)  --Selects Alu OP code (1 -> ADD; 2 -> NOR; 3 -> AND; 4 -> Equals; 5 -> signed greater than; else -> NOP)
	);
end entity;

architecture ctrlUn of ControlUnit is	
	type FSMState is (RESET_S, OPERATION_S); --Declares FSM with 2 states (reset and normal operation)
	signal currentState, nextState : FSMState := RESET_S; --Initialize states in Reset
	
begin

	process(clock) 
	begin 
		if(rising_edge(clock)) then --On every clock pulse
			currentState <= nextState; --Updates state (won't be very useful, just to guarantee the initial condition)
		end if;
	end process;
	
	process(currentState, ID_OP, ID_secondSeg, ID_lastSeg) --When state or the instruction parts change
	begin
		case currentState is				
			when OPERATION_S => --Normal operation state
				reset	<= '0'; --Disable reset
				
				case ID_OP is --Check which instruction is being decoded
					when x"1" | x"3" | x"4" | x"B" => --ADD or NOR or AND or MOVE
						ID_lastSegExtMode <= '0'; --last segment extend mode is zero extend
						
						case (ID_lastSeg((RADD_WIDTH-1) downto 0)) is --If the last 3 bits of last segment are 0, the instruction is trying to write on ZERO, which is forbidden
							when "000" =>
								ID_WB_WriteEn <= '0'; --Disables writing
								
							when others =>
								ID_WB_WriteEn <= '1'; --Otherwise, writing is allowed
						end case;

						ID_WB_DataSel <= '1'; --Data to write comes from ALU, not RAM
						ID_WB_WtUserReg <= '0'; --Won't update user output

						ID_MEM_DataWt <= '0'; --Don't write on RAM
						ID_MEM_IsJump <= '0'; --Not jump
						ID_MEM_IsBranch <= '0'; --Not branch

						ID_EX_DestReg <= '1'; --Destiny address comes from last segment
						ID_EX_AluBSrc <= (others => '0'); --ALU B data comes from internal data (forwarded or cache)
						
						case ID_OP is --Selects Alu OP code depending on the instruction
							when x"1" | x"B" => --ADD or MOVE
								ID_EX_AluOp <= "001"; --ADD
								
							when x"3" => --NOR
								ID_EX_AluOp <= "010"; --NOR
								
							when x"4" => --AND
								ID_EX_AluOp <= "011"; --AND
								
							when others => --NOP otherwise
								ID_EX_AluOp <= "000";
						end case;
						
					when x"2" | x"9" => --ADDI or IN
						ID_lastSegExtMode <= '1'; --Last segment is a signed value
						
						case(ID_secondSeg) is --If second segment is 0, the instruction is trying to write on ZERO, which is forbidden
							when "000" =>
								ID_WB_WriteEn <= '0'; --Disables writing
							
							when others =>
								ID_WB_WriteEn <= '1'; --Enables writing
						end case;
						
						ID_WB_DataSel <= '1'; --Data to write comes from ALU, not RAM
						ID_WB_WtUserReg <= '0'; --Won't update user output

						ID_MEM_DataWt <= '0'; --Don't write on RAM
						ID_MEM_IsJump <= '0'; --Not jump
						ID_MEM_IsBranch <= '0'; --Not branch

						ID_EX_DestReg <= '0'; --Destiny address comes from second segment
						
						case ID_OP is --Selects ALU B source depending on the instruction
							when x"9" => --if IN
								ID_EX_AluBSrc <= "10"; --Selects user input (2)
							
							when others =>
								ID_EX_AluBSrc <= "01"; --Otherwise, selects extended last segment
						end case;
						
						ID_EX_AluOp <= "001"; --Always ADD
					
					when x"5" | x"6" | x"C" => --BEQ, JUMP or BGT
						ID_lastSegExtMode <= '0'; --Last segment is unsigned (is an address)
						
						ID_WB_WriteEn <= '0'; --Won't write on cache

						ID_WB_DataSel <= '0'; --Don't care
						ID_WB_WtUserReg <= '0'; --Won't update user output

						ID_MEM_DataWt <= '0'; --Won't write on RAM
						
						case ID_OP is --Control flags
							when x"6" => --JUMP
								ID_MEM_IsJump <= '1'; --Sets jump flag
								
							when others =>
								ID_MEM_IsJump <= '0'; --Otherwise keep it 0
						end case;
						
						case ID_OP is --Control flags
							when x"5" | x"C" => --BEQ and BGT
								ID_MEM_IsBranch <= '1'; --Branch flag
								
							when others =>
								ID_MEM_IsBranch <= '0'; --Otherwise keep it 0
						end case;
							
						ID_EX_DestReg <= '0'; --Don't care
						ID_EX_AluBSrc <= "00"; --Alu B comes from cache or forwarded
						
						
						case ID_OP is --Selects Alu OP
							when x"5" => --BEQ
								ID_EX_AluOp <= "100"; --Equals
								
							when x"C" => --BGT
								ID_EX_AluOp <= "101"; --Signed Greater than
								
						   when others => --Otherwise
							ID_EX_AluOp <= "000"; --NOP
						end case;
						
					when x"7" | x"8" => --LOAD or STORE
						ID_lastSegExtMode <= '0'; --Last segment is unsigned (address)
						
						case ID_OP is
							when x"7" => --LOAD
							
								case(ID_secondSeg) is --If second segment is 0, the instruction is trying to write on ZERO, which is forbidden
									when "000" =>
										ID_WB_WriteEn <= '0'; --Disables writing
									
									when others =>
										ID_WB_WriteEn <= '1'; --Enables writing
								end case;
								
								ID_MEM_DataWt <= '0'; --Won't write on RAM
								ID_EX_AluOp <= "000"; --Alu NOP
							
							when others =>
								ID_WB_WriteEn <= '0'; --Won't write on cache
								ID_MEM_DataWt <= '1'; --Will write on RAM
								ID_EX_AluOp <= "001"; --Alu ADD
						end case;
						
						ID_WB_DataSel <= '0'; --Data comes from RAM (don't care in STORE)
						ID_WB_WtUserReg <= '0'; --Won't update user output

						ID_MEM_IsJump <= '0'; --Not jump
						ID_MEM_IsBranch <= '0'; --Not branch

						ID_EX_DestReg <= '0'; --Destiny address comes from second segment (don't care in STORE)
						ID_EX_AluBSrc <= "00"; --Alu B source comes from cache or forwarded (don't care in LOAD)
						
					when x"A" => --OUT
						ID_lastSegExtMode <= '0'; --Don't care
						ID_WB_WriteEn <= '0'; --Don't write on cache
						
						ID_WB_DataSel <= '1'; --Data comes from Alu
						ID_WB_WtUserReg <= '1'; --Updates user output

						ID_MEM_DataWt <= '0'; --Don't write on RAM
						ID_MEM_IsJump <= '0'; --Not jump
						ID_MEM_IsBranch <= '0'; --Not branch

						ID_EX_DestReg <= '0'; --Don't care
						ID_EX_AluBSrc <= (others => '0'); --Alu B source is cache or forwarded
						ID_EX_AluOp <= "001"; --ADD
						
					when others => --Other OP codes are considered NOP
						ID_lastSegExtMode <= '0'; --zero extend (don't care)
						
						ID_WB_WriteEn <= '0'; --Don't write on cache
						
						ID_WB_DataSel <= '0'; --Don't care
						ID_WB_WtUserReg <= '0'; --Don't update output register

						ID_MEM_DataWt <= '0'; --Don't write on RAM
						ID_MEM_IsJump <= '0'; --Not jump
						ID_MEM_IsBranch <= '0'; --Not branch

						ID_EX_DestReg <= '0'; --Don't care
						ID_EX_AluBSrc <= (others => '0'); --Don't care
						ID_EX_AluOp <= (others => '0'); --NOP
						
				end case;
				
				nextState <= OPERATION_S; --Continue on Operating State
				
			when others => --Reset State (and default state)
				reset	<= '1'; --Reset all memory elements to 0
				
				ID_lastSegExtMode <= '0'; --zero extend (don't care)
				
				ID_WB_WriteEn <= '0'; --Don't write on cache
				
				ID_WB_DataSel <= '0'; --Don't care
				ID_WB_WtUserReg <= '0'; --Don't update output register

				ID_MEM_DataWt <= '0'; --Don't write on RAM
				ID_MEM_IsJump <= '0'; --Not jump
				ID_MEM_IsBranch <= '0'; --Not branch

				ID_EX_DestReg <= '0'; --Don't care
				ID_EX_AluBSrc <= (others => '0'); --Don't care
				ID_EX_AluOp <= (others => '0'); --NOP
				
				nextState <= OPERATION_S; --Goes to operating state
	
		end case;
	end process;
	
end ctrlUn;