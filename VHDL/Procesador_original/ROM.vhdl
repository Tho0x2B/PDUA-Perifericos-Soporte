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
    -- Diagnostico: (-128) x (-128) = 0x4000.
    -- La ISR deja el byte bajo en RAM 0x80 y el alto en RAM 0x81.
    process (cs, rd, iom, dir)
    begin
        if cs = '1' and rd = '0' and iom = '1' then
            case dir is
                when "0000000" => data <= x"50"; -- 00 JMP MAIN
                when "0000001" => data <= x"03"; -- 01
                when "0000010" => data <= x"20"; -- 02 vector de interrupcion -> ISR
                when "0000011" => data <= x"18"; -- 03 MOV ACC, 0x40 ; MAIN: operando X = -128
                when "0000100" => data <= x"40"; -- 04
                when "0000101" => data <= x"28"; -- 05 MOV DPTR, ACC
                when "0000110" => data <= x"18"; -- 06 MOV ACC, 0x80
                when "0000111" => data <= x"80"; -- 07
                when "0001000" => data <= x"A0"; -- 08 SND [DPTR], ACC
                when "0001001" => data <= x"18"; -- 09 MOV ACC, 0x41 ; operando Y = -128
                when "0001010" => data <= x"41"; -- 0A
                when "0001011" => data <= x"28"; -- 0B MOV DPTR, ACC
                when "0001100" => data <= x"18"; -- 0C MOV ACC, 0x80
                when "0001101" => data <= x"80"; -- 0D
                when "0001110" => data <= x"A0"; -- 0E SND [DPTR], ACC
                when "0001111" => data <= x"18"; -- 0F MOV ACC, 0x42 ; registro de control: iniciar
                when "0010000" => data <= x"42"; -- 10
                when "0010001" => data <= x"28"; -- 11 MOV DPTR, ACC
                when "0010010" => data <= x"18"; -- 12 MOV ACC, 0x01
                when "0010011" => data <= x"01"; -- 13
                when "0010100" => data <= x"A0"; -- 14 SND [DPTR], ACC
                when "0010101" => data <= x"50"; -- 15 ESPERA: JMP ESPERA
                when "0010110" => data <= x"15"; -- 16
                when "0100000" => data <= x"18"; -- 20 MOV ACC, 0x43 ; ISR: leer byte bajo de Z
                when "0100001" => data <= x"43"; -- 21
                when "0100010" => data <= x"28"; -- 22 MOV DPTR, ACC
                when "0100011" => data <= x"98"; -- 23 RCV ACC, [DPTR]
                when "0100100" => data <= x"10"; -- 24 MOV A, ACC ; conservar el byte mientras se prepara DPTR
                when "0100101" => data <= x"18"; -- 25 MOV ACC, 0x80 ; direccion de destino en RAM
                when "0100110" => data <= x"80"; -- 26
                when "0100111" => data <= x"28"; -- 27 MOV DPTR, ACC
                when "0101000" => data <= x"08"; -- 28 MOV ACC, A
                when "0101001" => data <= x"30"; -- 29 MOV [DPTR], ACC
                when "0101010" => data <= x"18"; -- 2A MOV ACC, 0x44 ; leer byte alto de Z
                when "0101011" => data <= x"44"; -- 2B
                when "0101100" => data <= x"28"; -- 2C MOV DPTR, ACC
                when "0101101" => data <= x"98"; -- 2D RCV ACC, [DPTR]
                when "0101110" => data <= x"10"; -- 2E MOV A, ACC ; conservar el byte mientras se prepara DPTR
                when "0101111" => data <= x"18"; -- 2F MOV ACC, 0x81 ; direccion de destino en RAM
                when "0110000" => data <= x"81"; -- 30
                when "0110001" => data <= x"28"; -- 31 MOV DPTR, ACC
                when "0110010" => data <= x"08"; -- 32 MOV ACC, A
                when "0110011" => data <= x"30"; -- 33 MOV [DPTR], ACC
                when "0110100" => data <= x"18"; -- 34 MOV ACC, 0x42 ; registro de control: confirmar interrupcion
                when "0110101" => data <= x"42"; -- 35
                when "0110110" => data <= x"28"; -- 36 MOV DPTR, ACC
                when "0110111" => data <= x"18"; -- 37 MOV ACC, 0x02
                when "0111000" => data <= x"02"; -- 38
                when "0111001" => data <= x"A0"; -- 39 SND [DPTR], ACC
                when "0111010" => data <= x"78"; -- 3A RET
                when others => data <= (others => 'X');
            end case;
        else
            data <= (others => 'Z');
        end if;
    end process;
end architecture Behavioral;
