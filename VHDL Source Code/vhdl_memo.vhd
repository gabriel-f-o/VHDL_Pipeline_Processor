--This is a commentary

library IEEE; --Standart IEEE library
use IEEE.std_logic_1164.all; --std_logic data type
use IEEE.std_logic_unsigned.all; --Operators like + and -
use IEEE.numeric_std.all; --Some other functions

entity --this is the high-level abstraction of your hardware -> imagine a black box with inputs and outputs


entity my_entity is --this is an entity declaration
	generic( --you can add generic (like #defines) [optional]
		my_define_first : positive := 16; --generic syntax "name" : <type> := "value" -> as type you can use positive (1+), natural(0+) or integer(Z), and assign a number to it
		my_define_first : natural := 16; --generic syntax "name" : <type> := "value" -> as type you can use positive (1+), natural(0+) or integer(Z), and assign a number to it
		...
		my_define_end : integer := -7 --no ';' on the last
	); --end generic
	port( --begin port declaration [optional but probably necessary]
		input_1 : in bit; -- input sintax, "name" : <in/out> "type" -> as type you can have bit (0 or 1) bit_vector(X <downto/to> Y) (a bus containing various bits), std_logic (like a bit, but have Hi-Z state and other functions (requires use IEEE.std_logic_1164.all)
						  -- std_logic_vector(X <downto/to> Y), natural range X to Y (treated as a normal number, used to access vectors), array(X to Y) of bit/...
	    input_2 : in bit_vector(5 downto 0); --6 bit vector
		input_3 : in std_logic;
		
		output_1: out std_logic_vector(5 downto 0);
		output_2: out natural range 0 to 15 -- final entry, no ';'
	); --End port
end entity; --end entity

--To declare an entity that has no input/ output
entity blank is end;

--After declaring entity, you must describe its architecture

architecture hardware of my_entity is --Architecture syntax -> architecture "arch_name" of "entity_name" is
	--put stuff here like components (other entities that you might want to include), signals, etc...

	type enumLike is (LIKE_ENUM_1, LIKE_ENUM_2, LIKE_ENUM_3); --you can declare this type like an enum, where LIKE_ENUM_1 = 0...

	type my_type is array (0 to 7) of std_logic_vector(15 downto 0); --type keyword is like "typedef", creates a type called "my_type" that is a array of 8 16-bit signals (registers), note here we used 0 to 7, the difference is that a <= "100" will be stored as "100" if you use downto, and "001" otherwise

	signal registerBank : my_type; --Signal syntax signal "name" : "type" := "initial value if needed"
	
	signal sigS : std_logic; --Can be used as wires, registers...

	component my_entity_2 is --Declare a component (like a type), file that defines the architecture must be included in the project
		generic( --just copy and past the entity, changing to component
			...
		);
		port(
			...			
		);
	end component;

begin --begin architecture, everything inside is parallel

	My_object : my_entity_2 port map(input_1, registerBank, output_1, sigS, ...); --Create the hardware equivalent to the entity, you must do the port map to associate the object's in/outputs into signals and input/outputs of the system

	process(clock) --process is useful to use sequential logic (but hardware is still parallel), the variables inside are called "sensibility list" and the process will be called every time one variable inside changes
	begin --begin process
		if(input_1 = '1') then --inside process, you can use if(also called MUX template), elsif and else. = means the equality check operator, /= is different operator 
			...
			signalWhatever <= '0'; -- <= is the assign operator
		elsif(rising_edge(input_3)) then --you can even compare rising / falling edge
			...
		else --not then here
			...
		end if; --end if
		
		case input_2 is -- inside process, case compare
			when "000000" => --use => here, don't ask
				...
			when "000001" =>
				...
			when "000001" | "000010" | "000011" => --You can use "|" to multiple cases
				...
			when "00" to "11" => --And use "to" to define ranges
				...
			when others => --others is a very powerfull keyword, will come back later
				...
		end case; --end case
	end process; --Finish process
	
	with Sel select --Like case, but outside process
	output_2 <= input_n0 when '0', --Select input 0 if select is 0
			  input_n1   when '1', --Select input 1 if select is 1
				 (others => '0') when others; --Just in case
				 
				 
				 
				 
	 test <= input_0 when (input_1 = '1') else input_4; --If outside process (also called MUX template)
	 
end hardware; --End architecture by using end "arch_name"




-----------------------------------------------------------------------------------------------------
--Vectors manipulation
signal lv = std_logic_vector(5 downto 0) := --signal of 6 bits // := is to initialize
		(0 => '1', --you can assign bit-by-bit  like that, using "position" => "value" (use =>, don't ask)
		 others => '0' --set others to 0
		);

lv(0) --selecs LSB (must be a natural number)
lv(2 downto 0) --selecs 3 LSBs

--others is a keyword that fills every non-used value, so you can use lv = (others => '0') to initialize as 0, just like in cases
