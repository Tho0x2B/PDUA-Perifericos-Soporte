-- Testbench exhaustivo de MultPerif
-- Prueba los 65 536 pares (X, Y) con signo, de -128 a 127, a traves del bus,
-- igual que lo haria el PDUA: escribe X y Y, da START, espera la latencia,
-- revisa ocupado / IRQ / estado, lee Z_L y Z_H, compara con X*Y y hace ACK.
-- Mapa: X 0x40, Y 0x48, control/estado 0x50, Z_L 0x58, Z_H 0x60
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_mult_perif_exhaustivo is
end entity test_mult_perif_exhaustivo;

architecture sim of test_mult_perif_exhaustivo is
    constant DIR_X      : std_logic_vector(7 downto 0) := x"40";
    constant DIR_Y      : std_logic_vector(7 downto 0) := x"48";
    constant DIR_CTRL   : std_logic_vector(7 downto 0) := x"50";
    constant DIR_Z_BAJO : std_logic_vector(7 downto 0) := x"58";
    constant DIR_Z_ALTO : std_logic_vector(7 downto 0) := x"60";
    constant LATENCIA   : positive := 8;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal cs       : std_logic := '0';
    signal rw       : std_logic := '0';
    signal addr     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);
    signal irq      : std_logic;
    signal fin      : boolean := false;
begin
    dut : entity work.MultPerif
        port map (
            clk => clk, rst_n => rst_n, cs => cs, rw => rw, addr => addr,
            data_in => data_in, data_out => data_out, irq => irq
        );

    reloj : process
    begin
        while not fin loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    estimulos : process
        variable errores   : natural := 0;
        variable pruebas   : natural := 0;
        variable esperado  : std_logic_vector(15 downto 0);
        variable obtenido  : std_logic_vector(15 downto 0);

        procedure escribir (dir : std_logic_vector(7 downto 0);
                            dato : std_logic_vector(7 downto 0)) is
        begin
            cs      <= '1';
            rw      <= '1';
            addr    <= dir;
            data_in <= dato;
            wait until rising_edge(clk);
            wait for 1 ns;
            rw <= '0';
        end procedure;

        procedure leer (dir : std_logic_vector(7 downto 0);
                        variable dato : out std_logic_vector(7 downto 0)) is
        begin
            cs   <= '1';
            rw   <= '0';
            addr <= dir;
            wait for 1 ns;
            dato := data_out;
        end procedure;

        procedure error (mensaje : string; x, y : integer) is
        begin
            errores := errores + 1;
            if errores <= 10 then
                report "ERROR en " & integer'image(x) & " * " & integer'image(y) & ": " & mensaje
                    severity error;
            end if;
        end procedure;

        variable estado, z_bajo, z_alto : std_logic_vector(7 downto 0);
    begin
        -- Reset
        rst_n <= '0';
        wait for 22 ns;
        rst_n <= '1';
        wait until falling_edge(clk);

        leer(DIR_CTRL, estado);
        assert estado = x"00" report "Estado distinto de 0x00 despues del reset" severity failure;
        assert irq = '0' report "IRQ activa despues del reset" severity failure;

        for x in -128 to 127 loop
            for y in -128 to 127 loop
                pruebas  := pruebas + 1;
                esperado := std_logic_vector(to_signed(x * y, 16));

                -- Operandos y START
                escribir(DIR_X, std_logic_vector(to_signed(x, 8)));
                escribir(DIR_Y, std_logic_vector(to_signed(y, 8)));
                escribir(DIR_CTRL, x"01");

                -- Justo despues del START: ocupado, sin IRQ
                leer(DIR_CTRL, estado);
                if estado /= x"01" or irq /= '0' then
                    error("no quedo ocupado despues del START", x, y);
                end if;

                -- Ciclos 1 a 7: debe seguir ocupado y sin IRQ
                for ciclo in 1 to LATENCIA - 1 loop
                    wait until rising_edge(clk);
                    wait for 1 ns;
                    leer(DIR_CTRL, estado);
                    if estado /= x"01" or irq /= '0' then
                        error("termino en el ciclo " & integer'image(ciclo) &
                              ", antes de " & integer'image(LATENCIA), x, y);
                    end if;
                end loop;
                wait until rising_edge(clk);
                wait for 1 ns;

                -- Ciclo 8: resultado pendiente e IRQ
                leer(DIR_CTRL, estado);
                if estado /= x"02" or irq /= '1' then
                    error("no aparecio la IRQ en el ciclo " & integer'image(LATENCIA), x, y);
                end if;

                -- Resultado de 16 bits
                leer(DIR_Z_BAJO, z_bajo);
                leer(DIR_Z_ALTO, z_alto);
                obtenido := z_alto & z_bajo;
                if obtenido /= esperado then
                    error("Z = " & integer'image(to_integer(signed(obtenido))) &
                          ", esperado " & integer'image(x * y), x, y);
                end if;

                -- ACK: baja la IRQ y el estado vuelve a 0x00
                escribir(DIR_CTRL, x"02");
                leer(DIR_CTRL, estado);
                if estado /= x"00" or irq /= '0' then
                    error("el ACK no bajo la IRQ", x, y);
                end if;
            end loop;
        end loop;

        cs <= '0';
        report "Prueba exhaustiva terminada: " & integer'image(pruebas) &
               " pares probados, " & integer'image(errores) & " errores" severity note;
        assert errores = 0 report "LA PRUEBA EXHAUSTIVA FALLO" severity failure;
        fin <= true;
        wait;
    end process;
end architecture sim;
