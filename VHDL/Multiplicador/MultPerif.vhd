library ieee;
use ieee.std_logic_1164.all;

entity MultPerif is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        cs       : in  std_logic;
        rw       : in  std_logic;
        addr     : in  std_logic_vector(7 downto 0);
        data_in  : in  std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        irq      : out std_logic
    );
end entity MultPerif;

architecture rtl of MultPerif is
    constant ADDR_X       : std_logic_vector(7 downto 0) := x"40";
    constant ADDR_Y       : std_logic_vector(7 downto 0) := x"41";
    constant ADDR_CONTROL : std_logic_vector(7 downto 0) := x"42";
    constant ADDR_Z_LOW   : std_logic_vector(7 downto 0) := x"43";
    constant ADDR_Z_HIGH  : std_logic_vector(7 downto 0) := x"44";
    constant CMD_START    : std_logic_vector(7 downto 0) := x"01";
    constant CMD_ACK      : std_logic_vector(7 downto 0) := x"02";
    constant LATENCY     : positive := 8;

    signal operand_x   : std_logic_vector(7 downto 0);
    signal operand_y   : std_logic_vector(7 downto 0);
    signal product     : std_logic_vector(15 downto 0);
    signal result_reg  : std_logic_vector(15 downto 0);
    signal cycles_left : natural range 0 to LATENCY;
    signal busy        : std_logic;
    signal pending     : std_logic;
begin
    core : entity work.Multiplier
        generic map (N => 8)
        port map (A => operand_x, B => operand_y, Res => product);

    busy <= '1' when cycles_left /= 0 else '0';
    irq  <= pending;

    process (clk, rst_n)
    begin
        if rst_n = '0' then
            operand_x   <= (others => '0');
            operand_y   <= (others => '0');
            result_reg  <= (others => '0');
            cycles_left <= 0;
            pending     <= '0';
        elsif rising_edge(clk) then
            if cycles_left > 0 then
                cycles_left <= cycles_left - 1;
                if cycles_left = 1 then
                    result_reg <= product;
                    pending    <= '1';
                end if;
            elsif cs = '1' and rw = '1' then
                if pending = '1' then
                    if addr = ADDR_CONTROL and data_in = CMD_ACK then
                        pending <= '0';
                    end if;
                else
                    case addr is
                        when ADDR_X => operand_x <= data_in;
                        when ADDR_Y => operand_y <= data_in;
                        when ADDR_CONTROL =>
                            if data_in = CMD_START then
                                cycles_left <= LATENCY;
                            end if;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    process (cs, rw, addr, busy, pending, result_reg)
    begin
        data_out <= (others => '0');
        if cs = '1' and rw = '0' then
            case addr is
                when ADDR_CONTROL => data_out <= "000000" & pending & busy;
                when ADDR_Z_LOW   => data_out <= result_reg(7 downto 0);
                when ADDR_Z_HIGH  => data_out <= result_reg(15 downto 8);
                when others       => null;
            end case;
        end if;
    end process;
end architecture rtl;
