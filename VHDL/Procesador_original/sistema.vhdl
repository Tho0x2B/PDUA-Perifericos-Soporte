library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sistema is
    Port ( clk         : in  std_logic;
           rst_n       : in  std_logic;
           valid       : in  std_logic;
           switch_gpio : in  std_logic_vector(7 downto 0);
           LED_gpio    : out std_logic_vector(15 downto 0)
         );
end sistema;

architecture Behavioral of sistema is

component pdua is
    Port ( clk          : in  std_logic;
           rst_n        : in  std_logic;
           int          : in  std_logic;
           iom          : out std_logic;
           rw           : out std_logic;
           bus_dir      : out std_logic_vector(7 downto 0);
           bus_data_in  : in  std_logic_vector(7 downto 0);
           bus_data_out : out std_logic_vector(7 downto 0));
end component;

component ROM is
    Port ( cs, rd, iom : in  std_logic;
           dir         : in  std_logic_vector(6 downto 0);
           data        : out std_logic_vector(7 downto 0));
end component;

component RAM is
    Port ( cs, rw, iom : in  std_logic;
           dir         : in  std_logic_vector(6 downto 0);
           data_in     : in  std_logic_vector(7 downto 0);
           data_out    : out std_logic_vector(7 downto 0));
end component;

signal rwi, iom                          : std_logic;
signal en_deco_io, cs_ROM, cs_RAM        : std_logic;
signal cs_GPIO, cs_Mult                  : std_logic;
signal datai, datao, diri                : std_logic_vector(7 downto 0);
signal rom_data, ram_data                : std_logic_vector(7 downto 0);
signal gpio_data, mult_data              : std_logic_vector(7 downto 0);
signal irq_gpio, irq_mult                : std_logic;
signal irq_request, irq_pdua             : std_logic;
signal iom_irq, io_write_prev            : std_logic;

begin
    PROC : pdua port map (clk, rst_n, irq_pdua, iom, rwi, diri, datai, datao);
    MROM : ROM  port map (cs_ROM, rwi, iom, diri(6 downto 0), rom_data);
    MRAM : RAM  port map (cs_RAM, rwi, iom, diri(6 downto 0), datao, ram_data);

    -- Instancia del Periférico GPIO (Decodificador 2 a 4 -> Salida Y0: cs_GPIO)
    GPIO : entity work.GPIO_Perif
        port map (
            clk => clk, rst_n => rst_n, valid => valid,
            cs => cs_GPIO, rw => rwi,
            addr => diri, data_in => datao, data_out => gpio_data,
            switch_gpio => switch_gpio, LED_gpio => LED_gpio,
            irq => irq_gpio
        );

    -- Instancia del Periférico Multiplicador (Decodificador 2 a 4 -> Salida Y1: cs_Mult)
    MULT : entity work.MultPerif
        port map (
            clk => clk, rst_n => rst_n, cs => cs_Mult, rw => rwi,
            addr => diri, data_in => datao, data_out => mult_data,
            irq => irq_mult
        );

    INTSUP : entity work.interrupt_support
        port map (
            int => irq_request, iom => iom_irq,
            clk => clk, rst => rst_n, int_out => irq_pdua
        );

    -- =====================================================================
    -- 1. DECODIFICADOR DE MEMORIA PRINCIPAL (Compuertas AND con IOM = '1')
    -- =====================================================================
    cs_ROM <= iom and (not diri(7)); -- A7 = '0' (0x00 a 0x7F)
    cs_RAM <= iom and diri(7);       -- A7 = '1' (0x80 a 0xFF)

    -- Sincronización del segundo ciclo de escritura para instrucción SND
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            io_write_prev <= '0';
        elsif rising_edge(clk) then
            io_write_prev <= (not iom) and rwi;
        end if;
    end process;

    -- =====================================================================
    -- 2. DECODIFICADOR 2 A 4 DE PERIFÉRICOS (Enable: IOM = '0', Entradas: A7..A6)
    -- =====================================================================
    en_deco_io <= '1' when (iom = '0' and (rwi = '0' or io_write_prev = '1')) else '0';

    cs_GPIO <= '1' when (en_deco_io = '1' and diri(7 downto 6) = "00") else '0'; -- Salida Y0 (0x00..0x3F)
    cs_Mult <= '1' when (en_deco_io = '1' and diri(7 downto 6) = "01") else '0'; -- Salida Y1 (0x40..0x7F)
    -- Salidas Y2 ("10") y Y3 ("11") sin conectar

    -- Multiplexor del Bus de Datos de Entrada al Procesador (datai)
    datai <= rom_data  when rwi = '0' and cs_ROM  = '1' else
             ram_data  when rwi = '0' and cs_RAM  = '1' else
             gpio_data when rwi = '0' and cs_GPIO = '1' else
             mult_data when rwi = '0' and cs_Mult = '1' else
             (others => '0');

    -- Unión de interrupciones de ambos periféricos y señal de reconocimiento
    irq_request <= irq_gpio or irq_mult;
    iom_irq     <= '0' when iom = '0' and rwi = '0' and diri = x"02" else '1';

end Behavioral;
