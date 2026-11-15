library ieee;
use ieee.std_logic_1164.all;

entity test_mult_perif is
end entity test_mult_perif;

architecture sim of test_mult_perif is
    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal cs       : std_logic := '0';
    signal rw       : std_logic := '0';
    signal addr     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);
    signal irq      : std_logic;
    signal finished : boolean := false;
begin
    dut : entity work.MultPerif
        port map (
            clk => clk, rst_n => rst_n, cs => cs, rw => rw, addr => addr,
            data_in => data_in, data_out => data_out, irq => irq
        );

    clock_gen : process
    begin
        while not finished loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    stimulus : process
        procedure write_register (
            reg_addr : std_logic_vector(7 downto 0);
            value    : std_logic_vector(7 downto 0)
        ) is
        begin
            cs      <= '1';
            rw      <= '1';
            addr    <= reg_addr;
            data_in <= value;
            wait until rising_edge(clk);
            wait for 1 ns;
            rw <= '0';
        end procedure;

        procedure check_register (
            reg_addr : std_logic_vector(7 downto 0);
            expected : std_logic_vector(7 downto 0)
        ) is
        begin
            cs   <= '1';
            rw   <= '0';
            addr <= reg_addr;
            wait for 1 ns;
            assert data_out = expected report "Unexpected register value" severity failure;
        end procedure;

        procedure check_product (
            value_x  : std_logic_vector(7 downto 0);
            value_y  : std_logic_vector(7 downto 0);
            expected : std_logic_vector(15 downto 0)
        ) is
        begin
            write_register(x"40", value_x);
            write_register(x"41", value_y);
            write_register(x"42", x"01");
            check_register(x"42", x"01");
            assert irq = '0' report "IRQ asserted at start" severity failure;

            for cycle in 1 to 7 loop
                wait until rising_edge(clk);
                wait for 1 ns;
                assert irq = '0' and data_out = x"01"
                    report "Operation completed before eight cycles" severity failure;
            end loop;

            wait until rising_edge(clk);
            check_register(x"42", x"02");
            assert irq = '1' report "IRQ missing at cycle eight" severity failure;
            check_register(x"43", expected(7 downto 0));
            check_register(x"44", expected(15 downto 8));
            wait until rising_edge(clk);
            wait for 1 ns;
            assert irq = '1' report "IRQ cleared before acknowledgment" severity failure;

            write_register(x"42", x"02");
            check_register(x"42", x"00");
            assert irq = '0' report "Acknowledgment did not clear IRQ" severity failure;
        end procedure;
    begin
        wait until falling_edge(clk);
        rst_n <= '1';
        check_register(x"42", x"00");
        check_product(x"80", x"80", x"4000"); -- -128 * -128
        check_product(x"FD", x"07", x"FFEB"); -- -3 * 7
        report "test_mult_perif OK" severity note;
        finished <= true;
        wait;
    end process;
end architecture sim;
