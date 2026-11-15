-- ***********************************************************
-- ** PROYECTO PDUA                                         **
-- **   										                        **
-- ** Universidad de Los Andes                              **
-- ** Pontificia Universidad Javeriana                      **
-- **   										                        **
-- ** Rev 0.0 Arq Basica        Mauricio Guerrero   06/2007 **
-- ** Rev 0.1 Microprograma     Mauricio Guerrero           **
-- **         RAM doble puerto  Diego Méndez        11/2007 **
-- ** Rev 0.2 ALU bit-slice     MGH                 03/2008 **
-- ** Rev 0.3 Corrección Doc    DMCH                03/2009 **
-- ** Rev 0.4 ROM-RAM 128       DMCH                11/2009 **
-- ** Rev 0.5 PUSH-POP          DMCH                11/2009 **
-- ** Rev 0.6 Videos-Doc        DMCH                03/2021 **
-- ***********************************************************

-- ***********************************************************
-- Descripcion:                 
--               ______________________________________
--              |                ______   _____        |
--              |               | ROM  | | RAM |       |
--              |               |______| |_____|       |
--              |    _________                         |
--       CLK -->|-->|         |                        |
--     Rst_n -->|-->|  PDUA   |----------------> D_out | 
--       INT -->|-->|         |<---------------- D_in  |    
--              |   |         |----------------> Dir   |    
--              |   |         |----------------> Ctrl  |  
--              |   |_________|                        |
--              |                                      |
--              |______________________________________|  
-- ***********************************************************


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sistema is
    Port ( clk 	: in 	std_logic;
           rst_n 	: in 	std_logic;
           int 	: in 	std_logic
			  );
end sistema;

architecture Behavioral of sistema is

component pdua is
    Port ( clk 	: in 	std_logic;
           rst_n 	: in 	std_logic;
           int 	: in 	std_logic;
           iom 	: out 	std_logic;
           rw 		: out 	std_logic;
           bus_dir 	: out 	std_logic_vector(7 downto 0);
           bus_data_in : in 	std_logic_vector(7 downto 0);
			  bus_data_out : out	std_logic_vector(7 downto 0));
end component;

component ROM is
    Port ( cs,rd,iom	: in std_logic;
           dir 	: in std_logic_vector(6 downto 0);
           data 	: out std_logic_vector(7 downto 0));
end component;

component RAM is
    Port ( cs,rw,iom 	: in 	std_logic;
           dir 	: in 	std_logic_vector(6 downto 0);
           data_in 	: in 	std_logic_vector(7 downto 0);
			  data_out 	: out std_logic_vector(7 downto 0));
end component;

signal rwi, iom, cs_ROM, cs_RAM, cs_Mult : std_logic;
signal datai, datao, diri                : std_logic_vector(7 downto 0);
signal rom_data, ram_data, mult_data    : std_logic_vector(7 downto 0);
signal irq_mult, irq_request, irq_pdua  : std_logic;
signal iom_irq, io_write_prev           : std_logic;

begin
    PROC : pdua port map (clk, rst_n, irq_pdua, iom, rwi, diri, datai, datao);
    MROM : ROM  port map (cs_ROM, rwi, iom, diri(6 downto 0), rom_data);
    MRAM : RAM  port map (cs_RAM, rwi, iom, diri(6 downto 0), datao, ram_data);

    MULT : entity work.MultPerif
        port map (
            clk => clk, rst_n => rst_n, cs => cs_Mult, rw => rwi,
            addr => diri, data_in => datao, data_out => mult_data, irq => irq_mult
        );

    INTSUP : entity work.interrupt_support
        port map (
            int => irq_request, iom => iom_irq,
            clk => clk, rst => rst_n, int_out => irq_pdua
        );

    cs_ROM <= iom and not diri(7);
    cs_RAM <= iom and diri(7);

    -- SND prepara la direccion en el primer ciclo y presenta el dato en el segundo.
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            io_write_prev <= '0';
        elsif rising_edge(clk) then
            io_write_prev <= (not iom) and rwi;
        end if;
    end process;

    cs_Mult <= '1' when iom = '0' and diri(7 downto 6) = "01"
                       and (rwi = '0' or io_write_prev = '1') else '0';

    datai <= rom_data  when rwi = '0' and cs_ROM = '1' else
             ram_data  when rwi = '0' and cs_RAM = '1' else
             mult_data when rwi = '0' and cs_Mult = '1' else
             (others => '0');

    irq_request <= int or irq_mult;
    -- El PDUA indica la entrada a la ISR con IOM=0 y la direccion del vector.
    iom_irq <= '0' when iom = '0' and rwi = '0' and diri = x"02" else '1';

end Behavioral;
