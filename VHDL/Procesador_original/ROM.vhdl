-- ***********************************************************
-- ** PROYECTO PDUA                                         **
-- **                                                       **
-- ** Universidad de Los Andes                              **
-- ** Pontificia Universidad Javeriana                      **
-- **                                                       **
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
    Port ( cs,rd,iom    : in std_logic;
           dir  : in std_logic_vector(6 downto 0);
           data     : out std_logic_vector(7 downto 0));
end ROM;

architecture Behavioral of ROM is

begin
process(cs,rd,iom,dir)
begin
if cs = '1' and rd = '0' and iom = '1' then
       case dir is
when "0000000" => data <= "01010000";  -- 0x00: JMP MAIN
when "0000001" => data <= "00000011";  -- 0x01: MAIN = 0x03
when "0000010" => data <= "00000101";  -- 0x02: Vector de interrupcion -> ISR = 0x05
when "0000011" => data <= "01010000";  -- 0x03: MAIN: JMP MAIN (lazo vacio)
when "0000100" => data <= "00000011";  -- 0x04: 0x03 (MAIN)

when "0000101" => data <= "10001000";  -- 0x05: ISR: PUSH ACC (guarda ACC en la pila, RAM 0x88-0x8F)
when "0000110" => data <= "00001000";  -- 0x06: MOV ACC, A
when "0000111" => data <= "10001000";  -- 0x07: PUSH ACC (guarda A en la pila)
when "0001000" => data <= "00011000";  -- 0x08: ISR MOV ACC CTE (Direccion Registro de estados Mult) el registro de estados es 000000 despues va el bit de pendiente y el menos significatvo es el de ocupado, si esta en pendiente es que si fue el multplicador el de la interrupcion
when "0001001" => data <= "01010000";  -- 0x09: 0x50
when "0001010" => data <= "00101000";  -- 0x0A: MOV DPTR ACC
when "0001011" => data <= "10011000";  -- 0x0B: RCV ACC [DPTR]
when "0001100" => data <= "00010000";  -- 0x0C: MOV A ACC
when "0001101" => data <= "00011000";  -- 0x0D: MOV ACC CTE
when "0001110" => data <= "00000010";  -- 0x0E: 0x02
when "0001111" => data <= "01000000";  -- 0x0F: AND ACC, A ( si el segundo bit menos significativo es 1(si fue mult) como se hace el and con 0x02 si da distitno de 0 el programa sigue con la parte de la ISR de mult, si no se sabe que no fue el mult que hizo la interrupcion)
when "0010000" => data <= "01011000";  -- 0x10: JZ DIR (No fue)
when "0010001" => data <= "01000110";  -- 0x11: 0x46 (ISR GPIO)  [antes decia 0x4F; la etiqueta ISR GPIO esta en 0x46]
--Mete en ram la parte baja del resultado
when "0010010" => data <= "00011000";  -- 0x12: MOV ACC CTE (Direccion del byte bajo de Z[7:0]
when "0010011" => data <= "01011000";  -- 0x13: 0x58
when "0010100" => data <= "00101000";  -- 0x14: MOV DPTR ACC
when "0010101" => data <= "10011000";  -- 0x15: RCV ACC [DTPR]
when "0010110" => data <= "00010000";  -- 0x16: MOVE A ACC
when "0010111" => data <= "00011000";  -- 0x17: MOV ACC CTE
when "0011000" => data <= "10000010";  -- 0x18: 0x82
when "0011001" => data <= "00101000";  -- 0x19: MOV DPTR ACC
when "0011010" => data <= "00001000";  -- 0x1A: MOV ACC A
when "0011011" => data <= "00110000";  -- 0x1B: MOV [DPTR] ACC
--Mete en ram la parte alta del resultado
when "0011100" => data <= "00011000";  -- 0x1C: MOV ACC, CTE
when "0011101" => data <= "01100000";  -- 0x1D: 0x60
when "0011110" => data <= "00101000";  -- 0x1E: MOV DPTR, ACC
when "0011111" => data <= "10011000";  -- 0x1F: RCV ACC [DPTR]
when "0100000" => data <= "00010000";  -- 0x20: MOVE A ACC
when "0100001" => data <= "00011000";  -- 0x21: MOVE ACC CTE
when "0100010" => data <= "10000011";  -- 0x22: 0x83
when "0100011" => data <= "00101000";  -- 0x23: MOV DPTR ACC
when "0100100" => data <= "00001000";  -- 0x24: MOV ACC A
when "0100101" => data <= "00110000";  -- 0x25: MOV [DPTR] ACC

when "0100110" => data <= "00011000";  -- 0x26: MOV ACC CTE
when "0100111" => data <= "01010000";  -- 0x27: 0x50
when "0101000" => data <= "00101000";  -- 0x28: MOVE DPTR ACC
when "0101001" => data <= "00011000";  -- 0x29: MOVE ACC CTE
when "0101010" => data <= "00000010";  -- 0x2A: 0x02
when "0101011" => data <= "10100000";  -- 0x2B: SEND [DPTR] ACC  (senal de acknowledge)
--Poner en los leds byte bajo
when "0101100" => data <= "00011000";  -- 0x2C: MOVE ACC CTE
when "0101101" => data <= "10000010";  -- 0x2D: 0x82
when "0101110" => data <= "00101000";  -- 0x2E: MOV DPTR ACC
when "0101111" => data <= "00100000";  -- 0x2F: MOV ACC [DPTR]
when "0110000" => data <= "00010000";  -- 0x30: MOV A ACC
when "0110001" => data <= "00011000";  -- 0x31: MOV ACC CTE
when "0110010" => data <= "00011000";  -- 0x32: DIR LEDS BYTE BAJO (THOMAS)
when "0110011" => data <= "00101000";  -- 0x33: MOV DPTR ACC
when "0110100" => data <= "00001000";  -- 0x34: MOVE ACC A
when "0110101" => data <= "10100000";  -- 0x35: SEND [DPTR] ACC
--Poner en los leds byte alto
when "0110110" => data <= "00011000";  -- 0x36: MOVE ACC CTE
when "0110111" => data <= "10000011";  -- 0x37: 0x83
when "0111000" => data <= "00101000";  -- 0x38: MOV DPTR ACC
when "0111001" => data <= "00100000";  -- 0x39: MOV ACC [DPTR]
when "0111010" => data <= "00010000";  -- 0x3A: MOV A ACC
when "0111011" => data <= "00011000";  -- 0x3B: MOV ACC CTE
when "0111100" => data <= "00100000";  -- 0x3C: DIR LEDS BYTE ALTO (THOMAS)
when "0111101" => data <= "00101000";  -- 0x3D: MOV DPTR ACC
when "0111110" => data <= "00001000";  -- 0x3E: MOVE ACC A
when "0111111" => data <= "10100000";  -- 0x3F: SEND [DPTR] ACC
when "1000000" => data <= "10010000";  -- 0x40: FINAL INTERRUPCION:POP ACC
when "1000001" => data <= "00010000";  -- 0x41: MOV A ACC ( aca llega una interrupcion anidada)
when "1000010" => data <= "10010000";  -- 0x42: POP ACC
when "1000011" => data <= "00111000";  -- 0x43: INV ACC
when "1000100" => data <= "00111000";  -- 0x44: INV ACC
when "1000101" => data <= "01111000";  -- 0x45: RET

when "1000110" => data <= "00011000";  -- 0x46: ISR GPIO: MOV ACC CTE
when "1000111" => data <= "00010000";  -- 0x47: DIR REGISTRO ESTADOS GPIO (THOMAS)
when "1001000" => data <= "00101000";  -- 0x48: MOV DPTR ACC
when "1001001" => data <= "10011000";  -- 0x49: RCV ACC [DPTR]
when "1001010" => data <= "00010000";  -- 0x4A: MOV A ACC
when "1001011" => data <= "00011000";  -- 0x4B: MOV ACC CTE
when "1001100" => data <= "00000010";  -- 0x4C: 0x02
when "1001101" => data <= "01000000";  -- 0x4D: AND ACC A
when "1001110" => data <= "01011000";  -- 0x4E: JZ FINAL ISR
when "1001111" => data <= "01000000";  -- 0x4F: 0x40 (FINAL INTERRUPCION)  [antes decia 0x49; FINAL INTERRUPCION esta en 0x40]

when "1010000" => data <= "00011000";  -- 0x50: MOV ACC CTE
when "1010001" => data <= "00000000";  -- 0x51: DIR operando x (THOMAS)
when "1010010" => data <= "00101000";  -- 0x52: MOVE DTPR ACC
when "1010011" => data <= "10011000";  -- 0x53: RCV ACC [DPTR]
when "1010100" => data <= "00010000";  -- 0x54: MOV A ACC
when "1010101" => data <= "00011000";  -- 0x55: MOV ACC CTE
when "1010110" => data <= "01000000";  -- 0x56: 0x40
when "1010111" => data <= "00101000";  -- 0x57: MOV DPTR ACC
when "1011000" => data <= "00001000";  -- 0x58: MOV ACC A
when "1011001" => data <= "10100000";  -- 0x59: SND [DPTR] ACC
when "1011010" => data <= "00011000";  -- 0x5A: MOVE ACC CTE
when "1011011" => data <= "10000000";  -- 0x5B: 0x80
when "1011100" => data <= "00101000";  -- 0x5C: MOVE DPTR ACC
when "1011101" => data <= "00001000";  -- 0x5D: MOVE ACC A
when "1011110" => data <= "00110000";  -- 0x5E: MOV [DPTR] ACC

when "1011111" => data <= "00011000";  -- 0x5F: MOV ACC CTE
when "1100000" => data <= "00001000";  -- 0x60: DIR operando y (THOMAS)
when "1100001" => data <= "00101000";  -- 0x61: MOVE DTPR ACC
when "1100010" => data <= "10011000";  -- 0x62: RCV ACC [DPTR]
when "1100011" => data <= "00010000";  -- 0x63: MOV A ACC
when "1100100" => data <= "00011000";  -- 0x64: MOV ACC CTE
when "1100101" => data <= "01001000";  -- 0x65: 0x48
when "1100110" => data <= "00101000";  -- 0x66: MOV DPTR ACC
when "1100111" => data <= "00001000";  -- 0x67: MOV ACC A
when "1101000" => data <= "10100000";  -- 0x68: SND [DPTR] ACC
when "1101001" => data <= "00011000";  -- 0x69: MOVE ACC CTE
when "1101010" => data <= "10000001";  -- 0x6A: 0x81
when "1101011" => data <= "00101000";  -- 0x6B: MOVE DPTR ACC
when "1101100" => data <= "00001000";  -- 0x6C: MOVE ACC A
when "1101101" => data <= "00110000";  -- 0x6D: MOV [DPTR] ACC


when "1101110" => data <= "00011000";  -- 0x6E: MOV ACC CTE
when "1101111" => data <= "00010000";  -- 0x6F: DIR REGISTRO DE CONTROL (MISMA DIRECCION QUE ESTADOS)
when "1110000" => data <= "00101000";  -- 0x70: MOV DPTR ACC
when "1110001" => data <= "00011000";  -- 0x71: MOV ACC CTE
when "1110010" => data <= "00000010";  -- 0x72: 0x02
when "1110011" => data <= "10100000";  -- 0x73: SND [DPTR] ACC
when "1110100" => data <= "00011000";  -- 0x74: MOV ACC CTE
when "1110101" => data <= "01010000";  -- 0x75: 0x50
when "1110110" => data <= "00101000";  -- 0x76: MOV DPTR ACC
when "1110111" => data <= "00011000";  -- 0x77: MOVE ACC CTE
when "1111000" => data <= "00000001";  -- 0x78: 0x01
when "1111001" => data <= "10100000";  -- 0x79: SND [DPTR] ACC
when "1111010" => data <= "01010000";  -- 0x7A: JMP FINAL INTERRUPCION
when "1111011" => data <= "01000000";  -- 0x7B: 0x40
when "1111100" => data <= "XXXXXXXX";  -- 0x7C: 
when "1111101" => data <= "XXXXXXXX";  -- 0x7D: 
when "1111110" => data <= "XXXXXXXX";  -- 0x7E: 
when "1111111" => data <= "XXXXXXXX";  -- 0x7F: 

         when others => data <= (others => 'X'); 
       end case;
else data <= (others => 'Z');
end if;  
end process;
end;
