library ieee;
use ieee.std_logic_1164.all;

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
entity GPIO_Perif is
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        valid       : in  std_logic;
        cs          : in  std_logic;
        rw          : in  std_logic;
        addr        : in  std_logic_vector(7 downto 0);
        data_in     : in  std_logic_vector(7 downto 0);
        data_out    : out std_logic_vector(7 downto 0);
        switch_gpio : in  std_logic_vector(7 downto 0);
        LED_gpio    : out std_logic_vector(15 downto 0);
        irq         : out std_logic
    );
end entity GPIO_Perif;

architecture rtl of GPIO_Perif is
    type estados is (ESPERA_PULSACION, ESPERA_LIBERACION, PENDIENTE_ACK, REARME);
    signal estado_actual, estado_siguiente : estados;
    signal fase : std_logic; -- 0: entrada 0; 1: entrada 1
    signal valid_meta, valid_sync : std_logic;
    signal datos_meta, datos_sync : std_logic_vector(7 downto 0);
    signal decodificado, seleccion : std_logic_vector(7 downto 0);
    signal entrada_0, entrada_1 : std_logic_vector(7 downto 0);
    signal salida_baja, salida_alta : std_logic_vector(7 downto 0);
    signal estado_bus : std_logic_vector(7 downto 0);
    signal pendiente, capturar_0, capturar_1, ack_aceptado : std_logic;
begin
    sincronizar : process(clk, rst_n)
    begin
        if rst_n = '0' then
            valid_meta <= '0';
            valid_sync <= '0';
            datos_meta <= (others => '0');
            datos_sync <= (others => '0');
        elsif rising_edge(clk) then
            valid_meta <= valid;
            valid_sync <= valid_meta;
            datos_meta <= switch_gpio;
            datos_sync <= datos_meta;
        end if;
    end process;

    with addr(5 downto 3) select
        decodificado <= "00000001" when "000",
                        "00000010" when "001",
                        "00000100" when "010",
                        "00001000" when "011",
                        "00010000" when "100",
                        "00100000" when "101",
                        "01000000" when "110",
                        "10000000" when "111",
                        "00000000" when others;
    seleccion <= decodificado when cs = '1' else (others => '0');

    capturar_0 <= '1' when estado_actual = ESPERA_LIBERACION and
                           valid_sync = '0' and fase = '0' else '0';
    capturar_1 <= '1' when estado_actual = ESPERA_LIBERACION and
                           valid_sync = '0' and fase = '1' else '0';
    ack_aceptado <= '1' when seleccion(2) = '1' and rw = '1' and
                             data_in = x"02" and pendiente = '1' else '0';

    siguiente : process(estado_actual, valid_sync, fase, ack_aceptado)
    begin
        estado_siguiente <= estado_actual;
        case estado_actual is
            when ESPERA_PULSACION =>
                if valid_sync = '1' then
                    estado_siguiente <= ESPERA_LIBERACION;
                end if;
            when ESPERA_LIBERACION =>
                if valid_sync = '0' then
                    if fase = '0' then
                        estado_siguiente <= ESPERA_PULSACION;
                    else
                        estado_siguiente <= PENDIENTE_ACK;
                    end if;
                end if;
            when PENDIENTE_ACK =>
                if ack_aceptado = '1' then
                    estado_siguiente <= REARME;
                end if;
            when REARME =>
                -- Una pulsacion iniciada mientras habia pendiente se descarta.
                if valid_sync = '0' then
                    estado_siguiente <= ESPERA_PULSACION;
                end if;
        end case;
    end process;

    registros : process(clk, rst_n)
    begin
        if rst_n = '0' then
            estado_actual <= REARME;
            fase <= '0';
            entrada_0 <= (others => '0');
            entrada_1 <= (others => '0');
            salida_baja <= (others => '0');
            salida_alta <= (others => '0');
            pendiente <= '0';
        elsif rising_edge(clk) then
            estado_actual <= estado_siguiente;
            if capturar_0 = '1' then
                entrada_0 <= datos_sync;
                fase <= '1';
            end if;
            if capturar_1 = '1' then
                entrada_1 <= datos_sync;
                pendiente <= '1';
            elsif ack_aceptado = '1' then
                pendiente <= '0';
                fase <= '0';
            end if;

            -- Salidas independientes de la FSM y del ACK de las entradas.
            if rw = '1' and seleccion(3) = '1' then
                salida_baja <= data_in;
            end if;
            if rw = '1' and seleccion(4) = '1' then
                salida_alta <= data_in;
            end if;
        end if;
    end process;

    estado_bus <= "000000" & pendiente & '0';
    irq <= pendiente;
    LED_gpio <= salida_alta & salida_baja;

    -- MUX combinacional: leer no modifica registros ni reconoce la IRQ.
    data_out <= entrada_0 when rw = '0' and seleccion(0) = '1' else
                entrada_1 when rw = '0' and seleccion(1) = '1' else
                estado_bus when rw = '0' and seleccion(2) = '1' else
                (others => '0');
end architecture rtl;
