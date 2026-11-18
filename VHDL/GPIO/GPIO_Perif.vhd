LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- GPIO de dos capturas de 8 bits y salida de 16 bits.
-- E/S 0x00..0x3F: A5..A3 seleccionan interfaz; A2..A0 son alias.
--   0x00..0x07 R: entrada 0    0x08..0x0F R: entrada 1
--   0x10..0x17 R: estado [1]=pendiente, demas bits=0
--              W: 0x02 reconoce las dos entradas y rearma la captura
--   0x18..0x1F W: salida baja  0x20..0x27 W: salida alta
--   0x28..0x3F: sin interfaz; lectura=0, escritura sin efecto.
-- Un mismo valid carga ambos bytes, uno por pulsacion/liberacion.
-- Las entradas deben permanecer estables alrededor de la liberacion.
-- Los sincronizadores no implementan antirrebote mecanico.
ENTITY GPIO_Perif IS
    PORT (
        clk         : IN  STD_LOGIC;
        rst_n       : IN  STD_LOGIC;
        valid       : IN  STD_LOGIC;
        cs          : IN  STD_LOGIC;
        rw          : IN  STD_LOGIC;
        addr        : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_in     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_out    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        switch_gpio : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        LED_gpio    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        irq         : OUT STD_LOGIC
    );
END ENTITY GPIO_Perif;

ARCHITECTURE rtl OF GPIO_Perif IS
    TYPE estados IS (ESPERA_PULSACION, ESPERA_LIBERACION, PENDIENTE_ACK, REARME);
    SIGNAL estado_actual    : estados;
    SIGNAL estado_siguiente : estados;
    SIGNAL fase             : STD_LOGIC; -- 0: entrada 0; 1: entrada 1
    SIGNAL valid_meta       : STD_LOGIC;
    SIGNAL valid_sync       : STD_LOGIC;
    SIGNAL datos_meta       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL datos_sync       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL decodificado     : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL seleccion        : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL entrada_0        : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL entrada_1        : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL salida_baja      : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL salida_alta      : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL estado_bus       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL pendiente        : STD_LOGIC;
    SIGNAL capturar_0       : STD_LOGIC;
    SIGNAL capturar_1       : STD_LOGIC;
    SIGNAL ack_aceptado     : STD_LOGIC;
BEGIN
    sincronizar : PROCESS(clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            valid_meta    <= '0';
            valid_sync    <= '0';
            datos_meta    <= (OTHERS => '0');
            datos_sync    <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            valid_meta    <= valid;
            valid_sync    <= valid_meta;
            datos_meta    <= switch_gpio;
            datos_sync    <= datos_meta;
        END IF;
    END PROCESS;

    WITH addr(5 DOWNTO 3) SELECT
        decodificado <= "00000001" WHEN "000",
                        "00000010" WHEN "001",
                        "00000100" WHEN "010",
                        "00001000" WHEN "011",
                        "00010000" WHEN "100",
                        "00100000" WHEN "101",
                        "01000000" WHEN "110",
                        "10000000" WHEN "111",
                        "00000000" WHEN OTHERS;
    seleccion <= decodificado WHEN cs = '1' ELSE (OTHERS => '0');

    capturar_0   <= '1' WHEN estado_actual = ESPERA_LIBERACION AND
                             valid_sync = '0' AND fase = '0' ELSE '0';
    capturar_1   <= '1' WHEN estado_actual = ESPERA_LIBERACION AND
                             valid_sync = '0' AND fase = '1' ELSE '0';
    ack_aceptado <= '1' WHEN seleccion(2) = '1' AND rw = '1' AND
                             data_in = X"02" AND pendiente = '1' ELSE '0';

    siguiente : PROCESS(estado_actual, valid_sync, fase, ack_aceptado)
    BEGIN
        estado_siguiente <= estado_actual;
        CASE estado_actual IS
            WHEN ESPERA_PULSACION =>
                IF valid_sync = '1' THEN
                    estado_siguiente <= ESPERA_LIBERACION;
                END IF;
            WHEN ESPERA_LIBERACION =>
                IF valid_sync = '0' THEN
                    IF fase = '0' THEN
                        estado_siguiente <= ESPERA_PULSACION;
                    ELSE
                        estado_siguiente <= PENDIENTE_ACK;
                    END IF;
                END IF;
            WHEN PENDIENTE_ACK =>
                IF ack_aceptado = '1' THEN
                    estado_siguiente <= REARME;
                END IF;
            WHEN REARME =>
                -- Una pulsacion iniciada mientras habia pendiente se descarta.
                IF valid_sync = '0' THEN
                    estado_siguiente <= ESPERA_PULSACION;
                END IF;
        END CASE;
    END PROCESS;

    registros : PROCESS(clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            estado_actual <= REARME;
            fase          <= '0';
            entrada_0     <= (OTHERS => '0');
            entrada_1     <= (OTHERS => '0');
            salida_baja   <= (OTHERS => '0');
            salida_alta   <= (OTHERS => '0');
            pendiente     <= '0';
        ELSIF RISING_EDGE(clk) THEN
            estado_actual <= estado_siguiente;
            IF capturar_0 = '1' THEN
                entrada_0   <= datos_sync;
                fase        <= '1';
            END IF;
            IF capturar_1 = '1' THEN
                entrada_1   <= datos_sync;
                pendiente   <= '1';
            ELSIF ack_aceptado = '1' THEN
                pendiente   <= '0';
                fase        <= '0';
            END IF;

            -- Salidas independientes de la FSM y del ACK de las entradas.
            IF rw = '1' AND seleccion(3) = '1' THEN
                salida_baja <= data_in;
            END IF;
            IF rw = '1' AND seleccion(4) = '1' THEN
                salida_alta <= data_in;
            END IF;
        END IF;
    END PROCESS;

    estado_bus <= "000000" & pendiente & '0';
    irq        <= pendiente;
    LED_gpio   <= salida_alta & salida_baja;

    -- MUX combinacional: leer no modifica registros ni reconoce la IRQ.
    data_out <= entrada_0  WHEN rw = '0' AND seleccion(0) = '1' ELSE
                entrada_1  WHEN rw = '0' AND seleccion(1) = '1' ELSE
                estado_bus WHEN rw = '0' AND seleccion(2) = '1' ELSE
                (OTHERS => '0');
END ARCHITECTURE rtl;
