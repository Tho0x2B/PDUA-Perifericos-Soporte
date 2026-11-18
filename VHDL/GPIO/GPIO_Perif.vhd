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
    TYPE state_t IS (WAIT_PRESS, WAIT_RELEASE, WAIT_ACK, REARM);
    SIGNAL state            : state_t;
    SIGNAL next_state       : state_t;
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

    -- Decodificador one-hot 3 a 8: EN = cs, entradas A5..A3.
    -- Mapa E/S (R: rw=0, W: rw=1); A2..A0 son alias de cada interfaz.
    -- Y0 / 000 / 0x00..0x07: R entrada_0[7:0] (X).
    -- Y1 / 001 / 0x08..0x0F: R entrada_1[7:0] (Y).
    -- Y2 / 010 / 0x10..0x17: R estado[7:0], [1]=pendiente, otros bits=0;
    --                       W control[7:0], 0x02=ACK.
    -- Y3 / 011 / 0x18..0x1F: W salida_baja[7:0] -> LED_gpio[7:0].
    -- Y4 / 100 / 0x20..0x27: W salida_alta[7:0] -> LED_gpio[15:8].
    -- Y5 / 101 / 0x28..0x2F, Y6 / 110 / 0x30..0x37,
    -- Y7 / 111 / 0x38..0x3F: sin interfaz.
    -- Lecturas no implementadas devuelven 0; escrituras sin interfaz no actuan.
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

    capturar_0   <= '1' WHEN state = WAIT_RELEASE AND
                             valid_sync = '0' AND fase = '0' ELSE '0';
    capturar_1   <= '1' WHEN state = WAIT_RELEASE AND
                             valid_sync = '0' AND fase = '1' ELSE '0';
    ack_aceptado <= '1' WHEN seleccion(2) = '1' AND rw = '1' AND
                             data_in = X"02" AND pendiente = '1' ELSE '0';

    control : PROCESS(state, valid_sync, fase, ack_aceptado)
    BEGIN
        next_state <= state;
        CASE state IS
            WHEN WAIT_PRESS =>
                IF valid_sync = '1' THEN
                    next_state <= WAIT_RELEASE;
                END IF;
            WHEN WAIT_RELEASE =>
                IF valid_sync = '0' THEN
                    IF fase = '0' THEN
                        next_state <= WAIT_PRESS;
                    ELSE
                        next_state <= WAIT_ACK;
                    END IF;
                END IF;
            WHEN WAIT_ACK =>
                IF ack_aceptado = '1' THEN
                    next_state <= REARM;
                END IF;
            WHEN REARM =>
                -- Una pulsacion iniciada mientras habia pendiente se descarta.
                IF valid_sync = '0' THEN
                    next_state <= WAIT_PRESS;
                END IF;
        END CASE;
    END PROCESS;

    registros : PROCESS(clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state         <= REARM;
            fase          <= '0';
            entrada_0     <= (OTHERS => '0');
            entrada_1     <= (OTHERS => '0');
            salida_baja   <= (OTHERS => '0');
            salida_alta   <= (OTHERS => '0');
            pendiente     <= '0';
        ELSIF RISING_EDGE(clk) THEN
            state <= next_state;
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
