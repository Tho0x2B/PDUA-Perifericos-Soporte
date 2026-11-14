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
    Port ( clk 			: in 	std_logic;
           rst_n 			: in 	std_logic;
           valid 			: in 	std_logic;
			  switch_gpio	: in	std_logic_vector(7 downto 0);
			  LED_gpio		: out std_logic_vector(7 downto 0)
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

component interrupt_support is
    Port ( int : in  STD_LOGIC;
           iom : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           int_out : out  STD_LOGIC);
end component;

component IOper is
    Port ( clk,rst_n,valid 	: in 	std_logic;
           int 			: out std_logic;
           iom 			: in  std_logic;		-- IO=0,M=1
           rw 				: in  std_logic;		-- R=0,W=1
           bus_dir 	  	: in std_logic_vector(7 downto 0);
           bus_data_in 	: in 	std_logic_vector(7 downto 0);
			  bus_data_out	: out std_logic_vector(7 downto 0);
			  LED_gpio		: out std_logic_vector(7 downto 0);
			  switch_gpio 	: in 	std_logic_vector(7 downto 0));
end component;



signal rwi, cs_ROM, cs_RAM, cs_GPIO, cs_Mult, iom : std_logic;
signal int_gpio, int_mult, int_per, interrupt     : std_logic;


begin

--PROC	: pdua 	port map (clk,rst_n,int,iom,rwi,diri,datai,datao);
PROC	: pdua 	port map (clk,rst_n,interrupt,iom,rwi,diri,datai,datao);
MROM	: ROM  	port map (cs_ROM,rwi,iom,diri(6 downto 0),datai);
MRAM	: RAM 	port map (cs_RAM,rwi,iom,diri(6 downto 0),datao,datai);
INTSUP: interrupt_support port map (int_per,iom,clk,rst_n,interrupt);
PERIF: IOper port map (clk,rst_n,valid,int_per,iom,rwi,diri,datao,datai,LED_gpio,switch_gpio);


-- =========================================================================
-- Decodificador de Memoria (iom = '1') y Periféricos (iom = '0')
-- =========================================================================
-- Espacio de Memoria Principal (iom = '1'):
cs_ROM  <= iom and (not diri(7)); -- 0x00 a 0x7F (128 posiciones ROM)
cs_RAM  <= iom and diri(7);       -- 0x80 a 0xFF (128 posiciones RAM)
-- Decodificador 2 a 4 para Periféricos (Enable activo en bajo: iom = '0', entradas: diri(7 downto 6))
cs_GPIO <= '1' when (iom = '0' and diri(7 downto 6) = "00") else '0'; -- Salida Y0 (0x00..0x3F)
cs_Mult <= '1' when (iom = '0' and diri(7 downto 6) = "01") else '0'; -- Salida Y1 (0x40..0x7F)
-- Unión de solicitudes de interrupción hacia interrupt_support:
int_per <= int_gpio or int_mult;

end Behavioral;
