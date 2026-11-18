library ieee;
use ieee.std_logic_1164.all;

entity test_sistema is end entity;

architecture sim of test_sistema is
    constant PERIODO : time := 10 ns;
    signal clk, rst_n, valid : std_logic := '0';
    signal switch_gpio : std_logic_vector(7 downto 0) := (others => '0');
    signal LED_gpio : std_logic_vector(15 downto 0);
    signal fin : boolean := false;
begin
    dut : entity work.sistema
        port map(clk=>clk, rst_n=>rst_n, valid=>valid,
                 switch_gpio=>switch_gpio, LED_gpio=>LED_gpio);

    reloj : process
    begin
        while not fin loop
            clk <= '0'; wait for PERIODO/2;
            clk <= '1'; wait for PERIODO/2;
        end loop;
        wait;
    end process;

    estimulos : process
        procedure ciclos(n : positive) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end procedure;

        procedure cargar(dato : std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(clk);
            switch_gpio <= dato; valid <= '1'; ciclos(6);
            valid <= '0'; ciclos(6);
        end procedure;

        procedure comprobar(x, y : std_logic_vector(7 downto 0);
                             esperado : std_logic_vector(15 downto 0)) is
        begin
            cargar(x); cargar(y);
            -- Incluye ambas atenciones de IRQ, transferencias y retorno a MAIN.
            ciclos(2000);
            assert LED_gpio = esperado
                report "Sistema: resultado incorrecto en los 16 LEDs" severity failure;
        end procedure;
    begin
        ciclos(3); rst_n <= '1'; ciclos(8);
        assert LED_gpio=x"0000" report "Sistema: LEDs tras reset" severity failure;
        comprobar(x"FD", x"07", x"FFEB"); -- -3 * 7
        comprobar(x"80", x"80", x"4000"); -- -128 * -128
        comprobar(x"7F", x"80", x"C080"); -- 127 * -128
        comprobar(x"00", x"7F", x"0000"); -- 0 * 127
        comprobar(x"FF", x"FF", x"0001"); -- -1 * -1
        comprobar(x"0C", x"07", x"0054"); -- 12 * 7
        report "test_sistema OK: 6 operaciones consecutivas GPIO-PDUA-MULT-LED" severity note;
        fin <= true;
        wait;
    end process;
end architecture sim;
