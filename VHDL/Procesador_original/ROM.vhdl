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
-- Inicio y vector. Las direcciones de la izquierda pertenecen a ROM.
when "0000000" => data <= "01010000";  -- 0x00: JMP MAIN
when "0000001" => data <= "00000011";  -- 0x01: 0x03; direccion de MAIN
when "0000010" => data <= "00000101";  -- 0x02: Vector de interrupcion: ROM[0x02]=0x05, entrada comun a ISR
when "0000011" => data <= "01010000";  -- 0x03: JMP MAIN
when "0000100" => data <= "00000011";  -- 0x04: 0x03; direccion de MAIN

-- Entrada comun a ISR: conserva ACC y A. DPTR y banderas previas no se restauran.
when "0000101" => data <= "10001000";  -- 0x05: PUSH ACC; ISR: guarda ACC original en la pila
when "0000110" => data <= "00001000";  -- 0x06: MOV ACC, A; copia A a ACC para guardarlo
when "0000111" => data <= "10001000";  -- 0x07: PUSH ACC; guarda A original en la pila
-- Consulta MULT primero; solo consulta GPIO si MULT no tiene resultado pendiente.
when "0001000" => data <= "00011000";  -- 0x08: MOV ACC, 0x50
when "0001001" => data <= "01010000";  -- 0x09: 0x50; E/S: estado del multiplicador
when "0001010" => data <= "00101000";  -- 0x0A: MOV DPTR, ACC
when "0001011" => data <= "10011000";  -- 0x0B: RCV ACC, [DPTR]; lee estado MULT: bit 1=pendiente, bit 0=ocupado
when "0001100" => data <= "00010000";  -- 0x0C: MOV A, ACC; conserva el estado leido para aplicar la mascara
when "0001101" => data <= "00011000";  -- 0x0D: MOV ACC, 0x02
when "0001110" => data <= "00000010";  -- 0x0E: 0x02; mascara del bit 1: pendiente
when "0001111" => data <= "01000000";  -- 0x0F: AND ACC, A; aisla pendiente y actualiza Z
when "0010000" => data <= "01011000";  -- 0x10: JZ REVISAR_GPIO; si MULT no tiene pendiente, consulta GPIO
when "0010001" => data <= "01000110";  -- 0x11: 0x46; direccion de REVISAR_GPIO
-- Lee el resultado bajo del multiplicador y lo almacena en RAM 0x82.
when "0010010" => data <= "00011000";  -- 0x12: MOV ACC, 0x58
when "0010011" => data <= "01011000";  -- 0x13: 0x58; E/S: resultado Z[7:0]
when "0010100" => data <= "00101000";  -- 0x14: MOV DPTR, ACC
when "0010101" => data <= "10011000";  -- 0x15: RCV ACC, [DPTR]; recibe Z[7:0] desde E/S 0x58
when "0010110" => data <= "00010000";  -- 0x16: MOV A, ACC; conserva Z[7:0] mientras prepara DPTR
when "0010111" => data <= "00011000";  -- 0x17: MOV ACC, 0x82
when "0011000" => data <= "10000010";  -- 0x18: 0x82; RAM: destino de Z[7:0]
when "0011001" => data <= "00101000";  -- 0x19: MOV DPTR, ACC
when "0011010" => data <= "00001000";  -- 0x1A: MOV ACC, A
when "0011011" => data <= "00110000";  -- 0x1B: MOV [DPTR], ACC; guarda Z[7:0] en RAM 0x82
-- Lee el resultado alto del multiplicador y lo almacena en RAM 0x83.
when "0011100" => data <= "00011000";  -- 0x1C: MOV ACC, 0x60
when "0011101" => data <= "01100000";  -- 0x1D: 0x60; E/S: resultado Z[15:8]
when "0011110" => data <= "00101000";  -- 0x1E: MOV DPTR, ACC
when "0011111" => data <= "10011000";  -- 0x1F: RCV ACC, [DPTR]; recibe Z[15:8] desde E/S 0x60
when "0100000" => data <= "00010000";  -- 0x20: MOV A, ACC; conserva Z[15:8] mientras prepara DPTR
when "0100001" => data <= "00011000";  -- 0x21: MOV ACC, 0x83
when "0100010" => data <= "10000011";  -- 0x22: 0x83; RAM: destino de Z[15:8]
when "0100011" => data <= "00101000";  -- 0x23: MOV DPTR, ACC
when "0100100" => data <= "00001000";  -- 0x24: MOV ACC, A
when "0100101" => data <= "00110000";  -- 0x25: MOV [DPTR], ACC; guarda Z[15:8] en RAM 0x83

-- Reconoce el resultado del multiplicador despues de conservar sus dos bytes.
when "0100110" => data <= "00011000";  -- 0x26: MOV ACC, 0x50
when "0100111" => data <= "01010000";  -- 0x27: 0x50; E/S: control del multiplicador
when "0101000" => data <= "00101000";  -- 0x28: MOV DPTR, ACC
when "0101001" => data <= "00011000";  -- 0x29: MOV ACC, 0x02
when "0101010" => data <= "00000010";  -- 0x2A: 0x02; comando ACK del multiplicador
when "0101011" => data <= "10100000";  -- 0x2B: SND [DPTR], ACC; escribe ACK 0x02 en E/S 0x50; borra pendiente MULT
-- Transfiere el byte bajo desde RAM al GPIO de salida.
when "0101100" => data <= "00011000";  -- 0x2C: MOV ACC, 0x82
when "0101101" => data <= "10000010";  -- 0x2D: 0x82; RAM: origen de Z[7:0]
when "0101110" => data <= "00101000";  -- 0x2E: MOV DPTR, ACC
when "0101111" => data <= "00100000";  -- 0x2F: MOV ACC, [DPTR]; recupera Z[7:0] de RAM 0x82
when "0110000" => data <= "00010000";  -- 0x30: MOV A, ACC
when "0110001" => data <= "00011000";  -- 0x31: MOV ACC, 0x18
when "0110010" => data <= "00011000";  -- 0x32: 0x18; E/S: salida baja de LEDs del GPIO
when "0110011" => data <= "00101000";  -- 0x33: MOV DPTR, ACC
when "0110100" => data <= "00001000";  -- 0x34: MOV ACC, A
when "0110101" => data <= "10100000";  -- 0x35: SND [DPTR], ACC; escribe Z[7:0] en los LEDs bajos, E/S 0x18
-- Transfiere el byte alto desde RAM al GPIO de salida.
when "0110110" => data <= "00011000";  -- 0x36: MOV ACC, 0x83
when "0110111" => data <= "10000011";  -- 0x37: 0x83; RAM: origen de Z[15:8]
when "0111000" => data <= "00101000";  -- 0x38: MOV DPTR, ACC
when "0111001" => data <= "00100000";  -- 0x39: MOV ACC, [DPTR]; recupera Z[15:8] de RAM 0x83
when "0111010" => data <= "00010000";  -- 0x3A: MOV A, ACC
when "0111011" => data <= "00011000";  -- 0x3B: MOV ACC, 0x20
when "0111100" => data <= "00100000";  -- 0x3C: 0x20; E/S: salida alta de LEDs del GPIO
when "0111101" => data <= "00101000";  -- 0x3D: MOV DPTR, ACC
when "0111110" => data <= "00001000";  -- 0x3E: MOV ACC, A
when "0111111" => data <= "10100000";  -- 0x3F: SND [DPTR], ACC; escribe Z[15:8] en los LEDs altos, E/S 0x20
-- FINAL_ISR: restaura A y ACC y ejecuta RET. No hay mascara de interrupciones.
when "1000000" => data <= "10010000";  -- 0x40: POP ACC; recupera A original de la pila en ACC
when "1000001" => data <= "00010000";  -- 0x41: MOV A, ACC; restaura A; esta instruccion no inhibe interrupciones
when "1000010" => data <= "10010000";  -- 0x42: POP ACC; recupera ACC original de la pila
when "1000011" => data <= "00111000";  -- 0x43: INV ACC; primera inversion temporal de ACC
when "1000100" => data <= "00111000";  -- 0x44: INV ACC; recupera el valor de ACC y actualiza Z/N/P; no restaura C anterior
when "1000101" => data <= "01111000";  -- 0x45: RET; recupera el PC de retorno de la pila

-- REVISAR_GPIO: comprueba si sus dos entradas estan pendientes de atencion.
when "1000110" => data <= "00011000";  -- 0x46: MOV ACC, 0x10
when "1000111" => data <= "00010000";  -- 0x47: 0x10; E/S: estado del GPIO
when "1001000" => data <= "00101000";  -- 0x48: MOV DPTR, ACC
when "1001001" => data <= "10011000";  -- 0x49: RCV ACC, [DPTR]; lee estado GPIO: bit 1=dos entradas pendientes
when "1001010" => data <= "00010000";  -- 0x4A: MOV A, ACC; conserva el estado leido para aplicar la mascara
when "1001011" => data <= "00011000";  -- 0x4B: MOV ACC, 0x02
when "1001100" => data <= "00000010";  -- 0x4C: 0x02; mascara del bit 1: pendiente
when "1001101" => data <= "01000000";  -- 0x4D: AND ACC, A; aisla pendiente GPIO y actualiza Z
when "1001110" => data <= "01011000";  -- 0x4E: JZ FINAL_ISR; si GPIO no tiene pendiente, pasa a FINAL_ISR
when "1001111" => data <= "01000000";  -- 0x4F: 0x40; direccion de FINAL_ISR

-- Lee X del GPIO, lo guarda en RAM 0x80 y despues lo envia al multiplicador.
when "1010000" => data <= "00011000";  -- 0x50: MOV ACC, 0x00
when "1010001" => data <= "00000000";  -- 0x51: 0x00; E/S: entrada 0 del GPIO, utilizada como X
when "1010010" => data <= "00101000";  -- 0x52: MOV DPTR, ACC
when "1010011" => data <= "10011000";  -- 0x53: RCV ACC, [DPTR]; recibe X desde la entrada 0 del GPIO, E/S 0x00
when "1010100" => data <= "00010000";  -- 0x54: MOV A, ACC; conserva X mientras prepara las direcciones
when "1010101" => data <= "00011000";  -- 0x55: MOV ACC, 0x80
when "1010110" => data <= "10000000";  -- 0x56: 0x80; RAM: destino de X
when "1010111" => data <= "00101000";  -- 0x57: MOV DPTR, ACC
when "1011000" => data <= "00001000";  -- 0x58: MOV ACC, A
when "1011001" => data <= "00110000";  -- 0x59: MOV [DPTR], ACC; guarda X en RAM 0x80
when "1011010" => data <= "00011000";  -- 0x5A: MOV ACC, 0x40
when "1011011" => data <= "01000000";  -- 0x5B: 0x40; E/S: registro X del multiplicador
when "1011100" => data <= "00101000";  -- 0x5C: MOV DPTR, ACC
when "1011101" => data <= "00001000";  -- 0x5D: MOV ACC, A
when "1011110" => data <= "10100000";  -- 0x5E: SND [DPTR], ACC; envia X al multiplicador, E/S 0x40

-- Lee Y del GPIO, lo guarda en RAM 0x81 y despues lo envia al multiplicador.
when "1011111" => data <= "00011000";  -- 0x5F: MOV ACC, 0x08
when "1100000" => data <= "00001000";  -- 0x60: 0x08; E/S: entrada 1 del GPIO, utilizada como Y
when "1100001" => data <= "00101000";  -- 0x61: MOV DPTR, ACC
when "1100010" => data <= "10011000";  -- 0x62: RCV ACC, [DPTR]; recibe Y desde la entrada 1 del GPIO, E/S 0x08
when "1100011" => data <= "00010000";  -- 0x63: MOV A, ACC; conserva Y mientras prepara las direcciones
when "1100100" => data <= "00011000";  -- 0x64: MOV ACC, 0x81
when "1100101" => data <= "10000001";  -- 0x65: 0x81; RAM: destino de Y
when "1100110" => data <= "00101000";  -- 0x66: MOV DPTR, ACC
when "1100111" => data <= "00001000";  -- 0x67: MOV ACC, A
when "1101000" => data <= "00110000";  -- 0x68: MOV [DPTR], ACC; guarda Y en RAM 0x81
when "1101001" => data <= "00011000";  -- 0x69: MOV ACC, 0x48
when "1101010" => data <= "01001000";  -- 0x6A: 0x48; E/S: registro Y del multiplicador
when "1101011" => data <= "00101000";  -- 0x6B: MOV DPTR, ACC
when "1101100" => data <= "00001000";  -- 0x6C: MOV ACC, A
when "1101101" => data <= "10100000";  -- 0x6D: SND [DPTR], ACC; envia Y al multiplicador, E/S 0x48


-- Reconoce las entradas del GPIO una vez transferidas y conservadas.
when "1101110" => data <= "00011000";  -- 0x6E: MOV ACC, 0x10
when "1101111" => data <= "00010000";  -- 0x6F: 0x10; E/S: control/ACK del GPIO; comparte direccion con estado
when "1110000" => data <= "00101000";  -- 0x70: MOV DPTR, ACC
when "1110001" => data <= "00011000";  -- 0x71: MOV ACC, 0x02
when "1110010" => data <= "00000010";  -- 0x72: 0x02; comando ACK del GPIO
when "1110011" => data <= "10100000";  -- 0x73: SND [DPTR], ACC; escribe ACK 0x02 en E/S 0x10; permite nuevas capturas GPIO
-- Inicia MULT antes del retorno de esta ISR; el anidamiento sigue siendo posible.
when "1110100" => data <= "00011000";  -- 0x74: MOV ACC, 0x50
when "1110101" => data <= "01010000";  -- 0x75: 0x50; E/S: control del multiplicador
when "1110110" => data <= "00101000";  -- 0x76: MOV DPTR, ACC
when "1110111" => data <= "00011000";  -- 0x77: MOV ACC, 0x01
when "1111000" => data <= "00000001";  -- 0x78: 0x01; comando START del multiplicador
when "1111001" => data <= "10100000";  -- 0x79: SND [DPTR], ACC; escribe START 0x01 en E/S 0x50; MULT puede interrumpir antes del RET
when "1111010" => data <= "01010000";  -- 0x7A: JMP FINAL_ISR
when "1111011" => data <= "01000000";  -- 0x7B: 0x40; direccion de FINAL_ISR
-- Posiciones reservadas, fuera de las rutas de ejecucion del programa.
when "1111100" => data <= "XXXXXXXX";  -- 0x7C: Reservado; no utilizado
when "1111101" => data <= "XXXXXXXX";  -- 0x7D: Reservado; no utilizado
when "1111110" => data <= "XXXXXXXX";  -- 0x7E: Reservado; no utilizado
when "1111111" => data <= "XXXXXXXX";  -- 0x7F: Reservado; no utilizado

         when others => data <= (others => 'X'); 
       end case;
else data <= (others => 'Z');
end if;  
end process;
end;
