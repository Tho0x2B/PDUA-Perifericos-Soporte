library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_gpio_perif is end entity;

architecture sim of test_gpio_perif is
    constant PERIODO : time := 10 ns;
    signal clk, rst_n, valid, cs, rw : std_logic := '0';
    signal addr, data_in, data_out, switch_gpio : std_logic_vector(7 downto 0) := (others => '0');
    signal LED_gpio : std_logic_vector(15 downto 0);
    signal irq : std_logic;
    signal fin : boolean := false;
begin
    dut : entity work.GPIO_Perif
        port map(clk=>clk, rst_n=>rst_n, valid=>valid, cs=>cs, rw=>rw,
                 addr=>addr, data_in=>data_in, data_out=>data_out,
                 switch_gpio=>switch_gpio, LED_gpio=>LED_gpio, irq=>irq);

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

        procedure pulsacion(dato : std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(clk);
            switch_gpio <= dato;
            valid <= '1';
            ciclos(6);
            valid <= '0';
            ciclos(6);
        end procedure;

        procedure leer(dir, esperado : std_logic_vector(7 downto 0)) is
        begin
            cs <= '1'; rw <= '0'; addr <= dir;
            wait for 1 ns;
            assert data_out = esperado report "GPIO: lectura incorrecta en " &
                integer'image(to_integer(unsigned(dir))) severity failure;
        end procedure;

        procedure escribir(dir, dato : std_logic_vector(7 downto 0);
                           seleccionado : std_logic := '1') is
        begin
            wait until falling_edge(clk);
            cs <= seleccionado; rw <= '1'; addr <= dir; data_in <= dato;
            ciclos(1);
            rw <= '0';
            wait for 1 ns;
        end procedure;
    begin
        ciclos(2);
        rst_n <= '1';
        ciclos(4);
        leer(x"00", x"00"); leer(x"08", x"00"); leer(x"10", x"00");
        assert irq='0' and LED_gpio=x"0000" report "GPIO: reset incorrecto" severity failure;

        pulsacion(x"FD");
        leer(x"00", x"FD"); leer(x"08", x"00"); leer(x"10", x"00");
        assert irq='0' report "GPIO: IRQ antes de capturar ambas entradas" severity failure;

        -- Mantener pulsado no debe capturar repetidamente ni completar el par.
        switch_gpio <= x"07"; valid <= '1';
        ciclos(12);
        leer(x"08", x"00");
        assert irq='0' report "GPIO: captura sin liberacion" severity failure;
        valid <= '0'; ciclos(6);
        for offset in 0 to 7 loop
            leer(std_logic_vector(to_unsigned(offset,8)), x"FD");
            leer(std_logic_vector(to_unsigned(8+offset,8)), x"07");
            leer(std_logic_vector(to_unsigned(16+offset,8)), x"02");
        end loop;
        assert irq='1' report "GPIO: falta IRQ persistente" severity failure;

        -- Capturas bloqueadas hasta ACK; las lecturas no consumen los datos.
        pulsacion(x"AA"); pulsacion(x"BB");
        leer(x"00", x"FD"); leer(x"08", x"07"); leer(x"10", x"02");
        escribir(x"00", x"55"); -- entrada de solo lectura
        escribir(x"10", x"03"); -- comando no reconocido
        escribir(x"10", x"02", '0'); -- ACK sin CS
        leer(x"10", x"02");

        -- Escrituras de salida independientes del estado de captura.
        escribir(x"1F", x"EB"); escribir(x"27", x"FF");
        assert LED_gpio=x"FFEB" report "GPIO: salidas/alias incorrectos" severity failure;
        escribir(x"18", x"00", '0');
        for dir in 40 to 63 loop
            escribir(std_logic_vector(to_unsigned(dir,8)), x"00");
            leer(std_logic_vector(to_unsigned(dir,8)), x"00");
        end loop;
        assert LED_gpio=x"FFEB" and irq='1' report "GPIO: acceso invalido con efectos" severity failure;
        cs <= '0'; addr <= x"10"; wait for 1 ns;
        assert data_out=x"00" report "GPIO: lectura sin CS" severity failure;
        cs <= '1'; rw <= '1'; wait for 1 ns;
        assert data_out=x"00" report "GPIO: salida activa durante escritura" severity failure;
        rw <= '0';

        -- ACK con boton sostenido: su liberacion no es un nuevo dato.
        valid <= '1'; switch_gpio <= x"11"; ciclos(6);
        escribir(x"17", x"02");
        leer(x"10", x"00");
        assert irq='0' and LED_gpio=x"FFEB" report "GPIO: ACK incorrecto" severity failure;
        ciclos(8); valid <= '0'; ciclos(6);
        leer(x"00", x"FD"); leer(x"08", x"07");

        pulsacion(x"22");
        escribir(x"10", x"02"); -- sin pendiente: no reiniciar la fase
        pulsacion(x"33");
        leer(x"00", x"22"); leer(x"08", x"33"); leer(x"10", x"02");
        escribir(x"10", x"02"); ciclos(4);

        -- Reset durante una captura parcial restaura registros y fase.
        pulsacion(x"44"); rst_n <= '0'; wait for 1 ns;
        assert irq='0' and LED_gpio=x"0000" report "GPIO: reset asincrono incorrecto" severity failure;
        ciclos(2); rst_n <= '1'; ciclos(4);
        pulsacion(x"80"); pulsacion(x"7F");
        leer(x"00", x"80"); leer(x"08", x"7F"); leer(x"10", x"02");
        report "test_gpio_perif OK" severity note;
        fin <= true;
        wait;
    end process;
end architecture sim;
