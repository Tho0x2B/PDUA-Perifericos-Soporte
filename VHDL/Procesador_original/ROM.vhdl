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
-- ROM (Solo lectura)
--                  _______
--    cs,iom,rd -->|       |
--          dir -->|       |--> data
--                 |_______|   
--        
-- ***********************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ROM is
    Port ( cs,rd,iom	: in std_logic;
           dir 	: in std_logic_vector(6 downto 0);
           data 	: out std_logic_vector(7 downto 0));
end ROM;

architecture Behavioral of ROM is

begin
process(cs,rd,dir,iom)
begin
if cs = '1' and rd = '0' and iom = '1' then
       case dir is
	    when "0000000" => data <= "01010000";  -- 0x00 JMP MAIN
	    when "0000001" => data <= "00000011";  -- 0x01 MAIN 
	    when "0000010" => data <= "00010111";  -- 0x02 RAI Vector de Interrupcion (apunta a la ISR)
	    when "0000011" => data <= "00011000";  -- 0x03 MOV ACC,CTE 
       when "0000100" => data <= "00010000";  -- 0x04 CTE = 0x10
	    when "0000101" => data <= "10000000";  -- 0x05 COMP2 ACC (0xF0)
	    when "0000110" => data <= "01110000";  -- 0x06 CALL DIR
	    when "0000111" => data <= "00001111";  -- 0x07 DIR (0x0F)
	    when "0001000" => data <= "10000000";  -- 0x08 COMP2 ACC
       when "0001001" => data <= "01010000";  -- 0x09 JUMP FIN 	 
       when "0001010" => data <= "00001001";  -- 0x0A FIN
       when "0001011" => data <= "00000000";  -- 0x0B 
       when "0001100" => data <= "00000000";  -- 0x0C 
       when "0001101" => data <= "00000000";  -- 0x0D 
	    when "0001110" => data <= "00000000";  -- 0x0E 
       when "0001111" => data <= "00011000";  -- 0x0F SUBR: MOV ACC,CTE
	    when "0010000" => data <= "00110000";  -- 0x10 CTE = 0x30
	    when "0010001" => data <= "01111000";  -- 0x11 RET
	    when "0010010" => data <= "00000000";  -- 0x12 
	    when "0010011" => data <= "00000000";  -- 0x13 
		 when "0010100" => data <= "00000000";  -- 0x14 
	    when "0010101" => data <= "00000000";  -- 0x15
	    when "0010110" => data <= "00000000";  -- 0x16 
	    when "0010111" => data <= "00011000";  -- 0x17 ISR: MOV ACC, CTE
		 when "0011000" => data <= "00000101";  -- 0x18 CTE = 0x05 (dir lectura switch)
		 when "0011001" => data <= "00101000";  -- 0x19 MOV DPTR,ACC
		 when "0011010" => data <= "10011000";  -- 0x1A RCV ACC,[DPTR]
		 when "0011011" => data <= "00011000";  -- 0x1B MOV ACC, CTE
		 when "0011100" => data <= "00000100";  -- 0x1C CTE = 0x04 (dir escritura LED) 
	    when "0011101" => data <= "00101000";  -- 0x1D MOV DPTR,ACC
		 when "0011110" => data <= "00011000";  -- 0x1E MOV ACC, CTE
		 when "0011111" => data <= "10011001";  -- 0x1F CTE = 0x99 (valor escritura LED) 
		 when "0100000" => data <= "10100000";  -- 0x20 SND [DPTR],ACC
		 when "0100001" => data <= "01111000";  -- 0x21 RET
	
		 when others => data <= (others => 'X'); 
       end case;
else data <= (others => 'Z');
end if;  
end process;
end;
