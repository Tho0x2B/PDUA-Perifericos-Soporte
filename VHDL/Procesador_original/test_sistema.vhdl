-- Vhdl Test Bench template for design  :  sistema
-- Simulation tool : ModelSim-Altera (VHDL)
-- Author: Diego MeCha (2020-01)

LIBRARY ieee;                                               
USE ieee.std_logic_1164.all;                                

ENTITY test_sistema IS
END test_sistema;

ARCHITECTURE sistema_arch OF test_sistema IS
-- constants                                                 
-- signals                                                   
SIGNAL clk : STD_LOGIC :='0';
SIGNAL valid : STD_LOGIC :='0';
SIGNAL switch_gpio : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
SIGNAL LED_gpio : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL finished : BOOLEAN := FALSE;
SIGNAL rst_n : STD_LOGIC :='1';
constant clk_period : time := 1 us;


COMPONENT sistema
	PORT (
	clk : IN STD_LOGIC;
	rst_n : IN STD_LOGIC;
	valid : IN STD_LOGIC;
	switch_gpio : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	LED_gpio : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END COMPONENT;

BEGIN

-- list connections between master ports and signals
	uut1 : sistema
	PORT MAP (
		clk => clk,
		rst_n => rst_n,
		valid => valid,
		switch_gpio => switch_gpio,
		LED_gpio => LED_gpio
	);

-- clock generation (depends on clk_period constant)
   clk_process :PROCESS
   BEGIN
		IF finished THEN
			WAIT;
		END IF;
		clk <= '0';
		WAIT FOR clk_period/2;
		clk <= '1';
		WAIT FOR clk_period/2;
   END PROCESS;

-- Testbench
	always : PROCESS                                              
	BEGIN                                                         
		-- code executes for every event on sensitivity list  
		valid <= '0';
		rst_n	<= '0', '1' after 5 us;
		WAIT FOR clk_period*10;

		-- Primera pulsacion/liberacion: entrada 0 = X = -3.
		switch_gpio <= X"FD";
		valid <= '1';
		WAIT FOR clk_period*6;
		valid <= '0';
		WAIT FOR clk_period*6;

		-- Segunda pulsacion/liberacion: entrada 1 = Y = 7.
		switch_gpio <= X"07";
		valid <= '1';
		WAIT FOR clk_period*6;
		valid <= '0';
		WAIT FOR clk_period*1000; -- Ambas ISR y transferencia de Z a LEDs.

		ASSERT LED_gpio = X"FFEB"
			REPORT "test_sistema: resultado incorrecto, se esperaba -3 * 7 = 0xFFEB"
			SEVERITY FAILURE;
		REPORT "test_sistema OK: X/Y por valid y resultado de 16 bits en LEDs"
			SEVERITY NOTE;
		finished <= TRUE;
		wait;                                                        
	END PROCESS always;                                         

END sistema_arch;
