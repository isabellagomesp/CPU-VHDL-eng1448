library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Módulo: lcd_controller
-- Descrição: Controlador para LCD HD44780 em modo 4 bits (D4-D7).
--            Segue a mesma lógica do laboratório 7:
--              Fase 1 (init): sequência de inicialização com nibble único,
--                             idêntica ao lcd_init.vhd do laboratório.
--              Fase 2 (write loop): envia os 34 bytes do frame em loop contínuo,
--                             atualizando a cada refresh.
--
--            Conteúdo exibido (conforme enunciado):
--              Linha 1: "IR: AAAA        "  -> nome da instrução atual (4 chars)
--              Linha 2: "POS255:     DDD "  -> valor decimal de RAM[255]
--
--            Usa o clock rápido da FPGA (50 MHz). Não usa clk_cpu.
--            sf_ce0 mantido em '1' para desabilitar a StrataFlash.
--------------------------------------------------------------------------------
entity lcd_controller is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        ir     : in  std_logic_vector(7 downto 0);
        flags  : in  std_logic_vector(4 downto 0);
        mem255 : in  std_logic_vector(7 downto 0);
        lcd_rs : out std_logic;
        lcd_rw : out std_logic;
        lcd_e  : out std_logic;
        lcd_d  : out std_logic_vector(3 downto 0);  -- barramento 4 bits (D4-D7)
        sf_ce0 : out std_logic
    );
end lcd_controller;

architecture rtl of lcd_controller is

    -- =========================================================================
    -- Estados da FSM (mesma estrutura do laboratório 7)
    -- =========================================================================
    type state_t is (
        -- Inicialização: nibble único (antes do modo 4 bits)
        ST_WAIT_POWER,
        ST_SEND_3_1, ST_WAIT_3_1,
        ST_SEND_3_2, ST_WAIT_3_2,
        ST_SEND_3_3, ST_WAIT_3_3,
        ST_SEND_2,   ST_WAIT_2,
        -- Configuração: modo 4 bits ativo, 2 nibbles por byte
        ST_CONF_SEND, ST_CONF_WAIT,
        -- Loop de escrita: prepara byte e o envia em 2 nibbles
        ST_WR_PREP,
        ST_WR_SEND_HI, ST_WR_WAIT_HI,
        ST_WR_SEND_LO, ST_WR_WAIT_LO
    );
    signal state : state_t := ST_WAIT_POWER;

    signal counter    : integer := 0;
    signal conf_index : integer range 0 to 7 := 0;

    -- Passo atual do frame (0 a 33):
    --   0      -> comando 0x80 (endereço linha 1)
    --   1..16  -> 16 bytes de dados da linha 1
    --   17     -> comando 0xC0 (endereço linha 2)
    --   18..33 -> 16 bytes de dados da linha 2
    signal disp_step : integer range 0 to 33 := 0;

    -- Byte atual sendo enviado e seu rs (0=cmd, 1=dado)
    signal cur_rs   : std_logic := '0';
    signal cur_byte : std_logic_vector(7 downto 0) := (others => '0');

    -- =========================================================================
    -- Sequência de configuração (idêntica ao lab 7 – lcd_init.vhd)
    -- =========================================================================
    type conf_array is array (0 to 7) of std_logic_vector(3 downto 0);
    constant conf_data : conf_array := (
        x"2", x"8",  -- 0x28: Function Set  (4-bit, 2 linhas, 5x8)
        x"0", x"6",  -- 0x06: Entry Mode Set (incrementa, sem shift)
        x"0", x"C",  -- 0x0C: Display ON, cursor OFF, sem blink
        x"0", x"1"   -- 0x01: Clear Display
    );

    -- =========================================================================
    -- Dígitos decimais de mem255 (calculados combinatoriamente)
    -- =========================================================================
    signal d_h : integer range 0 to 2;  -- centenas
    signal d_t : integer range 0 to 9;  -- dezenas
    signal d_o : integer range 0 to 9;  -- unidades

    -- =========================================================================
    -- Nome da instrução: 4 bytes ASCII empacotados (31..24 = char mais à esq.)
    -- =========================================================================
    signal inst_name : std_logic_vector(31 downto 0);

begin

    lcd_rw <= '0';  -- sempre escrita
    sf_ce0 <= '1';  -- desabilita StrataFlash para liberar D4-D7

    -- =========================================================================
    -- Processo: INST_DECODE
    -- Decodifica IR -> nome de 4 caracteres ASCII da instrução atual
    -- =========================================================================
    INST_DECODE: process(ir)
    begin
        case ir(7 downto 4) is
            when "0000" => inst_name <= x"41444420"; -- "ADD "
            when "0001" => inst_name <= x"53554220"; -- "SUB "
            when "0010" =>
                if ir(1 downto 0) = "01" then inst_name <= x"44454320"; -- "DEC "
                else                          inst_name <= x"494E4320"; -- "INC "
                end if;
            when "0011" => inst_name <= x"414E4420"; -- "AND "
            when "0100" => inst_name <= x"4F522020"; -- "OR  "
            when "0101" => inst_name <= x"4E4F5420"; -- "NOT "
            when "0110" => inst_name <= x"584F5220"; -- "XOR "
            when "0111" =>
                case ir(1 downto 0) is
                    when "00"   => inst_name <= x"524F4C20"; -- "ROL "
                    when "01"   => inst_name <= x"524F5220"; -- "ROR "
                    when "10"   => inst_name <= x"4C534C20"; -- "LSL "
                    when others => inst_name <= x"4C535220"; -- "LSR "
                end case;
            when "1000" =>
                case ir(1 downto 0) is
                    when "00"   => inst_name <= x"50555348"; -- "PUSH"
                    when "01"   => inst_name <= x"504F5020"; -- "POP "
                    when "10"   => inst_name <= x"53542020"; -- "ST  "
                    when others => inst_name <= x"4C442020"; -- "LD  "
                end case;
            when "1001" => inst_name <= x"4C445220"; -- "LDR "
            when "1010" => inst_name <= x"53545220"; -- "STR "
            when "1011" => inst_name <= x"4D4F5620"; -- "MOV "
            when "1100" =>
                if    ir(3 downto 0) = "0000" then inst_name <= x"4A4D5020"; -- "JMP "
                elsif ir(1 downto 0) = "01"   then inst_name <= x"4A4D5052"; -- "JMPR"
                elsif ir(1 downto 0) = "10"   then inst_name <= x"425A2020"; -- "BZ  "
                else                               inst_name <= x"424E5A20"; -- "BNZ "
                end if;
            when "1101" =>
                case ir(1 downto 0) is
                    when "00"   => inst_name <= x"42435320"; -- "BCS "
                    when "01"   => inst_name <= x"42434320"; -- "BCC "
                    when "10"   => inst_name <= x"42455120"; -- "BEQ "
                    when others => inst_name <= x"424E4551"; -- "BNEQ"
                end case;
            when "1110" =>
                if ir(1 downto 0) = "00" then inst_name <= x"42475420"; -- "BGT "
                else                          inst_name <= x"424C5420"; -- "BLT "
                end if;
            when "1111" => inst_name <= x"48414C54"; -- "HALT"
            when others => inst_name <= x"3F3F3F3F"; -- "????"
        end case;
    end process;

    -- =========================================================================
    -- Processo: DEC_CONVERT
    -- Converte mem255 (0-255) em três dígitos decimais
    -- =========================================================================
    DEC_CONVERT: process(mem255)
        variable val     : integer range 0 to 255;
        variable rem_val : integer range 0 to 99;
        variable tens    : integer range 0 to 9;
    begin
        val := to_integer(unsigned(mem255));

        -- Centena (0 a 2): comparação + subtração (evita operador DIVIDE, não sintetizável p/ divisor != potência de 2)
        if val >= 200 then
            d_h     <= 2;
            rem_val := val - 200;
        elsif val >= 100 then
            d_h     <= 1;
            rem_val := val - 100;
        else
            d_h     <= 0;
            rem_val := val;
        end if;

        -- Dezena e unidade (0 a 99): subtração repetida de 10 (loop de bound constante, sintetizável)
        tens := 0;
        for i in 0 to 9 loop
            if rem_val >= 10 then
                rem_val := rem_val - 10;
                tens    := tens + 1;
            end if;
        end loop;

        d_t <= tens;
        d_o <= rem_val;
    end process;

    -- =========================================================================
    -- Processo: FSM_MAIN
    -- Máquina de estados principal: init (igual ao lab 7) + loop de escrita
    -- =========================================================================
    FSM_MAIN: process(clk, reset)
        variable v_pos : integer range 0 to 15;
    begin
        if reset = '1' then
            state      <= ST_WAIT_POWER;
            counter    <= 0;
            conf_index <= 0;
            disp_step  <= 0;
            lcd_rs     <= '0';
            lcd_e      <= '0';
            lcd_d      <= (others => '0');
            cur_rs     <= '0';
            cur_byte   <= (others => '0');

        elsif rising_edge(clk) then
            -- Saídas padrão a cada ciclo (evita latches)
            lcd_rs <= '0';
            lcd_e  <= '0';

            case state is

                -- =============================================================
                -- INIT: aguarda 15 ms (750 000 ciclos a 50 MHz) – igual ao lab
                -- =============================================================
                when ST_WAIT_POWER =>
                    if counter = 750000 then
                        counter <= 0;
                        state   <= ST_SEND_3_1;
                    else
                        counter <= counter + 1;
                    end if;

                -- =============================================================
                -- INIT: envia nibble 0x3 (1ª vez), espera 205 000 ciclos (~4 ms)
                -- =============================================================
                when ST_SEND_3_1 =>
                    lcd_d <= x"3"; lcd_e <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WAIT_3_1;
                    else counter <= counter + 1; end if;

                when ST_WAIT_3_1 =>
                    if counter = 205000 then counter <= 0; state <= ST_SEND_3_2;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- INIT: envia nibble 0x3 (2ª vez), espera 5 000 ciclos (~100 µs)
                -- =============================================================
                when ST_SEND_3_2 =>
                    lcd_d <= x"3"; lcd_e <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WAIT_3_2;
                    else counter <= counter + 1; end if;

                when ST_WAIT_3_2 =>
                    if counter = 5000 then counter <= 0; state <= ST_SEND_3_3;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- INIT: envia nibble 0x3 (3ª vez), espera 2 000 ciclos (~40 µs)
                -- =============================================================
                when ST_SEND_3_3 =>
                    lcd_d <= x"3"; lcd_e <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WAIT_3_3;
                    else counter <= counter + 1; end if;

                when ST_WAIT_3_3 =>
                    if counter = 2000 then counter <= 0; state <= ST_SEND_2;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- INIT: envia nibble 0x2 (seleciona modo 4 bits)
                -- =============================================================
                when ST_SEND_2 =>
                    lcd_d <= x"2"; lcd_e <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WAIT_2;
                    else counter <= counter + 1; end if;

                when ST_WAIT_2 =>
                    if counter = 2000 then counter <= 0; state <= ST_CONF_SEND;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- CONF: envia os 8 nibbles de configuração (idêntico ao lab)
                -- =============================================================
                when ST_CONF_SEND =>
                    lcd_d <= conf_data(conf_index); lcd_e <= '1';
                    if counter = 12 then counter <= 0; state <= ST_CONF_WAIT;
                    else counter <= counter + 1; end if;

                when ST_CONF_WAIT =>
                    lcd_d <= conf_data(conf_index); lcd_e <= '0';
                    if conf_index = 7 then
                        -- Último byte é Clear Display: espera ~1.64 ms (82 000 ciclos)
                        if counter = 82000 then
                            counter    <= 0;
                            conf_index <= 0;
                            disp_step  <= 0;
                            state      <= ST_WR_PREP;
                        else
                            counter <= counter + 1;
                        end if;
                    elsif conf_index mod 2 = 0 then
                        -- Entre nibble alto e baixo do mesmo byte: 50 ciclos
                        if counter = 50 then
                            counter    <= 0;
                            conf_index <= conf_index + 1;
                            state      <= ST_CONF_SEND;
                        else
                            counter <= counter + 1;
                        end if;
                    else
                        -- Após byte completo: 2 000 ciclos (~40 µs)
                        if counter = 2000 then
                            counter    <= 0;
                            conf_index <= conf_index + 1;
                            state      <= ST_CONF_SEND;
                        else
                            counter <= counter + 1;
                        end if;
                    end if;

                -- =============================================================
                -- WRITE LOOP: prepara o byte/rs para o passo atual
                --
                -- Linha 1 (disp_step 1..16): "IR: AAAA        "
                --   pos 0='I' 1='R' 2=':' 3=' ' 4..7=nome(4 chars) 8..15=' '
                --
                -- Linha 2 (disp_step 18..33): "POS255:     DDD "
                --   pos 0='P' 1='O' 2='S' 3='2' 4='5' 5='5' 6=':' 7..11=' '
                --       12=centenas 13=dezenas 14=unidades 15=' '
                -- =============================================================
                when ST_WR_PREP =>
                    if disp_step = 0 then
                        cur_rs   <= '0';
                        cur_byte <= x"80";          -- cmd: início da linha 1

                    elsif disp_step <= 16 then
                        cur_rs <= '1';
                        v_pos  := disp_step - 1;
                        case v_pos is
                            when 0      => cur_byte <= x"49";                  -- 'I'
                            when 1      => cur_byte <= x"52";                  -- 'R'
                            when 2      => cur_byte <= x"3A";                  -- ':'
                            when 3      => cur_byte <= x"20";                  -- ' '
                            when 4      => cur_byte <= inst_name(31 downto 24);-- char 0
                            when 5      => cur_byte <= inst_name(23 downto 16);-- char 1
                            when 6      => cur_byte <= inst_name(15 downto 8); -- char 2
                            when 7      => cur_byte <= inst_name(7 downto 0);  -- char 3
                            when others => cur_byte <= x"20";                  -- ' '
                        end case;

                    elsif disp_step = 17 then
                        cur_rs   <= '0';
                        cur_byte <= x"C0";          -- cmd: início da linha 2

                    else
                        cur_rs <= '1';
                        v_pos  := disp_step - 18;
                        case v_pos is
                            when 0  => cur_byte <= x"50";  -- 'P'
                            when 1  => cur_byte <= x"4F";  -- 'O'
                            when 2  => cur_byte <= x"53";  -- 'S'
                            when 3  => cur_byte <= x"32";  -- '2'
                            when 4  => cur_byte <= x"35";  -- '5'
                            when 5  => cur_byte <= x"35";  -- '5'
                            when 6  => cur_byte <= x"3A";  -- ':'
                            when 7  => cur_byte <= x"20";  -- ' '
                            when 8  => cur_byte <= x"20";  -- ' '
                            when 9  => cur_byte <= x"20";  -- ' '
                            when 10 => cur_byte <= x"20";  -- ' '
                            when 11 => cur_byte <= x"20";  -- ' '
                            -- Dígito decimal: ASCII = x"3" & nibble do dígito
                            when 12 => cur_byte <= x"3" & std_logic_vector(to_unsigned(d_h, 4));
                            when 13 => cur_byte <= x"3" & std_logic_vector(to_unsigned(d_t, 4));
                            when 14 => cur_byte <= x"3" & std_logic_vector(to_unsigned(d_o, 4));
                            when others => cur_byte <= x"20"; -- ' '
                        end case;
                    end if;
                    state <= ST_WR_SEND_HI;

                -- =============================================================
                -- WRITE: envia nibble alto (igual ao send_nibble do lab)
                -- =============================================================
                when ST_WR_SEND_HI =>
                    lcd_rs <= cur_rs;
                    lcd_d  <= cur_byte(7 downto 4);
                    lcd_e  <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WR_WAIT_HI;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- WRITE: espera entre nibbles (igual ao wait_nibble do lab)
                -- =============================================================
                when ST_WR_WAIT_HI =>
                    lcd_rs <= cur_rs;
                    lcd_d  <= cur_byte(7 downto 4);
                    if counter = 2000 then counter <= 0; state <= ST_WR_SEND_LO;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- WRITE: envia nibble baixo
                -- =============================================================
                when ST_WR_SEND_LO =>
                    lcd_rs <= cur_rs;
                    lcd_d  <= cur_byte(3 downto 0);
                    lcd_e  <= '1';
                    if counter = 12 then counter <= 0; state <= ST_WR_WAIT_LO;
                    else counter <= counter + 1; end if;

                -- =============================================================
                -- WRITE: espera após byte completo; avança para próximo passo
                -- =============================================================
                when ST_WR_WAIT_LO =>
                    lcd_rs <= cur_rs;
                    lcd_d  <= cur_byte(3 downto 0);
                    if counter = 2000 then
                        counter <= 0;
                        if disp_step = 33 then
                            disp_step <= 0;   -- reinicia o frame
                        else
                            disp_step <= disp_step + 1;
                        end if;
                        state <= ST_WR_PREP;
                    else
                        counter <= counter + 1;
                    end if;

            end case;
        end if;
    end process;

end rtl;
