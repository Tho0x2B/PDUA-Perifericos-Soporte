library ieee;
use ieee.std_logic_1164.all;

-- Periferico multiplicador (E/S 0x40-0x7F, salida Y1 del decodificador 2 a 4).
-- Los registros se eligen con un decodificador 3 a 8 sobre A2..A0:
--   Y0 (A2..A0 = 000) -> 0x40  X           (W)
--   Y1 (A2..A0 = 001) -> 0x41  Y           (W)
--   Y2 (A2..A0 = 010) -> 0x42  CONTROL (W: 0x01 START, 0x02 ACK)
--                              ESTADO  (R: bit1 = INT pendiente, bit0 = ocupado)
--   Y3 (A2..A0 = 011) -> 0x43  Z[7:0]      (R)
--   Y4 (A2..A0 = 100) -> 0x44  Z[15:8]     (R)
--   Y5..Y7            -> sin conectar
-- Decodificacion parcial: A5..A3 no se usan (0x48 es alias de 0x40).
entity MultPerif is
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        cs       : in  std_logic;
        rw       : in  std_logic;
        addr     : in  std_logic_vector(7 downto 0);
        data_in  : in  std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        irq      : out std_logic
    );
end entity MultPerif;

architecture rtl of MultPerif is
    constant ORDEN_INICIO : std_logic_vector(7 downto 0) := x"01";
    constant ORDEN_ACK   : std_logic_vector(7 downto 0) := x"02";
    constant LATENCIA   : positive := 8;

    signal sel              : std_logic_vector(7 downto 0);  -- salidas del 3 a 8
    signal sel_x            : std_logic;                     -- Y0
    signal sel_y            : std_logic;                     -- Y1
    signal sel_control      : std_logic;                     -- Y2
    signal sel_z_bajo       : std_logic;                     -- Y3
    signal sel_z_alto       : std_logic;                     -- Y4

    signal operando_x       : std_logic_vector(7 downto 0);
    signal operando_y       : std_logic_vector(7 downto 0);
    signal producto         : std_logic_vector(15 downto 0);
    signal resultado        : std_logic_vector(15 downto 0);
    signal ciclos_restantes : natural range 0 to LATENCIA;
    signal ocupado          : std_logic;
    signal pendiente        : std_logic;
begin
    -- Decodificador 3 a 8: EN = cs (Y1 del 2 a 4), entradas A2..A0
    DECO_3A8 : process (cs, addr)
    begin
        sel <= (others => '0');
        if cs = '1' then
            case addr(2 downto 0) is
                when "000"  => sel(0) <= '1';
                when "001"  => sel(1) <= '1';
                when "010"  => sel(2) <= '1';
                when "011"  => sel(3) <= '1';
                when "100"  => sel(4) <= '1';
                when "101"  => sel(5) <= '1';
                when "110"  => sel(6) <= '1';
                when others => sel(7) <= '1';
            end case;
        end if;
    end process DECO_3A8;

    sel_x       <= sel(0); -- Guarda el byte del bus en el registro x primer operando con rw= 1 / con rw= 0 no hace nada, solo devuelve 0x00
    sel_y       <= sel(1); -- Guarda el byte del bus en el registro y segundo operando / con rw = 0 no hace nada
    sel_control <= sel(2); -- va conectado a dos and una con rw y otra con not rw, cuando rw = 1 se ve el registro de control, donde se escribe 0x01 para que inicie, y 0x02 ack para decirle que ya se leyo el resultado. el rw en 0 lee el bit del registro de estado para saber si fue el multiplicador el que mando la senal de interrupcion
    sel_z_bajo  <= sel(3); --  rw = 1 no hace nada/ rw = 0 Pone en el bus el byte bajo del resultado z[7:0]
    sel_z_alto  <= sel(4); -- rw = 1 no hace nada / rw= 0 pone en el bus el byte alto del resultado z[15:8]
    -- sel(5), sel(6) y sel(7) no se usan

    core : entity work.Multiplier
        generic map (N => 8)
        port map (A => operando_x, B => operando_y, Res => producto);

    ocupado <= '1' when ciclos_restantes /= 0 else '0';
    irq  <= pendiente;

    -- Escrituras (sincronas, en el flanco de subida)
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            operando_x       <= (others => '0');
            operando_y       <= (others => '0');
            resultado        <= (others => '0');
            ciclos_restantes <= 0;
            pendiente        <= '0';
        elsif rising_edge(clk) then
            if ciclos_restantes > 0 then
                -- multiplicando: cuenta los 8 ciclos de latencia
                ciclos_restantes <= ciclos_restantes - 1;
                if ciclos_restantes = 1 then
                    resultado        <= producto;
                    pendiente        <= '1';
                end if;
            elsif rw = '1' then
                if pendiente = '1' then
                    -- con resultado pendiente solo se acepta el ACK
                    if sel_control = '1' and data_in = ORDEN_ACK then
                        pendiente        <= '0';
                    end if;
                else
                    -- libre: guarda operandos o arranca la multiplicacion
                    if sel_x = '1' then
                        operando_x       <= data_in;
                    end if;
                    if sel_y = '1' then
                        operando_y       <= data_in;
                    end if;
                    if sel_control = '1' and data_in = ORDEN_INICIO then
                        ciclos_restantes <= LATENCIA;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Lecturas (combinacionales, sin efectos)
    data_out <= "000000" & pendiente & ocupado when rw = '0' and sel_control = '1' else
                resultado(7 downto 0)                  when rw = '0' and sel_z_bajo  = '1' else
                resultado(15 downto 8)                 when rw = '0' and sel_z_alto  = '1' else
                (others => '0');
end architecture rtl;
