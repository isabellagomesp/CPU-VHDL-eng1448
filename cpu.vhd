LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- Declaração da Entidade
entity CPU is
    port (
    clk   : in std_logic;
    reset : in std_logic;

    -- Interface com a Memória RAM
    ram_addr   : out std_logic_vector(7 downto 0); -- Endereço enviado para a RAM
    ram_din    : in  std_logic_vector(7 downto 0); -- Dado lido vindo da RAM
    ram_dout   : out std_logic_vector(7 downto 0); -- Dado enviado para escrita na RAM
    ram_we     : out std_logic;                    -- Habilitação de escrita na RAM (Write Enable)
    
    current_ir : out std_logic_vector(7 downto 0); -- Envia o IR atual para decodificação do LCD
    alu_leds   : out std_logic_vector(4 downto 0)
    );
end CPU;

architecture Behavioral of CPU is

    -- Declaração de estados da FSM
    type state_type is (FETCH, DECODE_1, DECODE_2, EXECUTE, WRITE_BACK);
    signal current_state, next_state : state_type := FETCH;

    -- Definição de tipo para o Banco de Registradores (4 registradores de 8 bits)
    type reg_array is array (0 to 3) of std_logic_vector(7 downto 0);
    
    -- Sinais dos Registradores de Propósito Geral (A=00, B=01, C=10, D=11)
    signal REG : reg_array := (others => (others => '0'));

    -- Sinais dos Registradores Específicos (todos com 8 bits)
    signal PC  : std_logic_vector(7 downto 0) := (others => '0'); -- Program Counter (PC)
    signal IR  : std_logic_vector(7 downto 0) := (others => '0'); -- Instruction Register (IR)
    signal MAR : std_logic_vector(7 downto 0) := (others => '0'); -- Memory Address Register (MAR)
    signal MBR : std_logic_vector(7 downto 0) := (others => '0'); -- Memory Buffer Register (MBR)
    
    -- Inicialização do Stack Pointer: Posição 254 (0xFE)
    -- A posição 255 é reservada para I/O (LCD)
    signal SP  : std_logic_vector(7 downto 0) := x"FE"; 

    -- Sinais de controle (serão gerados pela FSM na Etapa 4)
    signal reg_write_en : std_logic := '0'; -- Habilita escrita nos GPRs
    signal reg_dest     : std_logic_vector(1 downto 0); -- Seleciona qual GPR (0 a 3) vai receber o dado
    signal reg_data_in  : std_logic_vector(7 downto 0); -- Dado a ser escrito no GPR
    
    -- Enables de Escrita (Autorizam a atualização do registrador no clock)
    signal PC_en  : std_logic := '0';
    signal IR_en  : std_logic := '0';
    signal MAR_en : std_logic := '0';
    signal MBR_en : std_logic := '0';

    -- Sinais de Próximo Estado (O valor que será carregado quando o Enable estiver '1')
    signal next_PC  : std_logic_vector(7 downto 0) := (others => '0');
    signal next_IR  : std_logic_vector(7 downto 0) := (others => '0');
    signal next_MAR : std_logic_vector(7 downto 0) := (others => '0');
    signal next_MBR : std_logic_vector(7 downto 0) := (others => '0');

    -- Controles específicos do Stack Pointer
    signal SP_inc : std_logic := '0'; -- Usado pelo comando POP
    signal SP_dec : std_logic := '0'; -- Usado pelo comando PUSH

    -- Registrador interno para retenção e persistência das flags nos LEDs
    signal flags_reg    : std_logic_vector(4 downto 0) := (others => '0');
    signal update_flags : std_logic := '0';

    -- Componente ALU
    component alu is 
        port( A     : in  STD_LOGIC_VECTOR(7 downto 0);
              B     : in  STD_LOGIC_VECTOR(7 downto 0);
              CMD   : in  STD_LOGIC_VECTOR(3 downto 0);
              C_IN  : in  STD_LOGIC;
              C_OUT : out STD_LOGIC;
              FLAGS : out STD_LOGIC_VECTOR(4 downto 0);
              S     : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- Sinais de Controle ALU
    signal alu_operando_A : std_logic_vector(7 downto 0);
    signal alu_operando_B : std_logic_vector(7 downto 0);
    signal alu_comando    : std_logic_vector(3 downto 0);
    signal alu_resultado  : std_logic_vector(7 downto 0);
    signal alu_carry_out  : std_logic;
    signal alu_flags      : std_logic_vector(4 downto 0);

begin
    -- Instanciação da ALU
    U_ALU: alu port map(
        A     => alu_operando_A,
        B     => alu_operando_B,
        CMD   => alu_comando,
        C_IN  => '0',
        C_OUT => alu_carry_out,
        FLAGS => alu_flags,
        S     => alu_resultado
    );

    current_ir <= IR;          -- Espelha permanentemente o IR para leitura do LCD
    alu_leds   <= flags_reg;   -- Exibe nos LEDs as flags retidas de forma síncrona

    alu_operando_A <= REG(to_integer(unsigned(IR(3 downto 2)))); -- Rx
    alu_operando_B <= REG(to_integer(unsigned(IR(1 downto 0)))); -- Ry
    alu_comando    <= IR(7 downto 4);                            -- OpCode define a operação

    -- Processo responsável pela atualização síncrona dos registradores
    REGISTERS_UPDATE: process(clk, reset)
        begin
            if reset = '1' then
                PC        <= (others => '0');
                IR        <= (others => '0');
                MAR       <= (others => '0');
                MBR       <= (others => '0');
                SP        <= x"FE"; -- Reinicializa o Stack Pointer para 254
                REG       <= (others => (others => '0'));
                flags_reg <= (others => '0');
                
            elsif rising_edge(clk) then
                
                -- Atualização do Banco de Registradores Gerais
                if reg_write_en = '1' then
                    REG(to_integer(unsigned(reg_dest))) <= reg_data_in;
                end if;

                -- Atualizações controladas por enables da Unidade de Controle
                if PC_en = '1' then
                    PC <= next_PC;
                end if;

                if IR_en = '1' then
                    IR <= next_IR;
                end if;

                if MAR_en = '1' then
                    MAR <= next_MAR;
                end if;

                if MBR_en = '1' then
                    MBR <= next_MBR;
                end if;
                
                -- Controle de incremento/decremento da pilha
                if SP_inc = '1' then
                    SP <= std_logic_vector(unsigned(SP) + 1);
                elsif SP_dec = '1' then
                    SP <= std_logic_vector(unsigned(SP) - 1);
                end if;

                -- Latch síncrono das flags da ALU (Garante a persistência requisitada)
                if update_flags = '1' then
                    flags_reg <= alu_flags;
                end if;
            end if;
    end process;

    -- Processo responsável pela lógica de controle da FSM
    FSM_UPDATE: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= FETCH; -- Estado inicial da máquina
        elsif rising_edge(clk) then
            current_state <= next_state; -- Transição para o próximo estado
        end if;
    end process;

    -- Processo responsável por determinar o próximo estado e os sinais de controle
    FSM_LOGIC: process(current_state, IR, alu_flags, MBR, PC, REG, ram_din)
    begin
        next_state <= current_state; -- Valor padrão (permanece no mesmo estado)
        update_flags <= '0';

        -- Sinais de escrita e roteamento dos registradores
        reg_write_en <= '0';
        reg_dest     <= (others => '0');
        reg_data_in  <= (others => '0');
        
        -- Enable dos registradores específicos
        PC_en  <= '0';
        IR_en  <= '0';
        MAR_en <= '0';
        MBR_en <= '0';

        -- Valores a serem carregados nos Registradores Específicos
        next_PC  <= (others => '0');
        next_IR  <= (others => '0');
        next_MAR <= (others => '0');
        next_MBR <= (others => '0');
        
        -- Controles do Stack Pointer
        SP_inc <= '0';
        SP_dec <= '0';

        -- Controles da Memória RAM
        ram_we   <= '0';
        ram_addr <= (others => '0');
        ram_dout <= (others => '0');

        case current_state is
            when FETCH =>
                ram_addr <= PC; -- Envia o endereço do PC para a RAM
                next_IR <= ram_din; -- O dado lido da RAM será o próximo IR
                IR_en <= '1'; -- Habilita a escrita no IR
                next_PC <= std_logic_vector(unsigned(PC) + 1); -- Incrementa o PC para a próxima instrução
                PC_en <= '1'; -- Habilita a escrita no PC
                next_state <= DECODE_1; -- Transição para o estado de Decodificação 1

            when DECODE_1 =>
                if (IR(7 downto 4) = "1000" and (IR(1 downto 0) = "10" or IR(1 downto 0) = "11")) or 
                   (IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000") then
                    
                    next_state <= DECODE_2;   -- Precisa ir na RAM buscar o complemento (0x--)
                else
                    next_state <= EXECUTE;    -- Instrução de 1 byte, pode executar direto
                end if;

            when DECODE_2 =>
                ram_addr   <= PC;        -- O PC já aponta para a posição do dado/endereço (0x--) 
                next_MBR   <= ram_din;   -- Guarda o valor lido temporariamente no MBR
                MBR_en     <= '1';
                
                -- Incrementa o PC novamente para apontar para a próxima instrução real do programa
                next_PC    <= std_logic_vector(unsigned(PC) + 1);
                PC_en      <= '1';
                
                next_state <= EXECUTE;

            when EXECUTE =>
                -- ADD Rx, Ry (OpCode: 0000)
                if IR(7 downto 4) = "0000" then
                    update_flags <= '1';        -- Comanda o salvamento das flags geradas nesta instrução
                    next_state   <= WRITE_BACK;

                -- JMP 0x-- (OpCode: 1100 0000)
                elsif IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000" then
                    next_PC      <= MBR;        -- Carrega o endereço alvo guardado no MBR para o PC
                    PC_en        <= '1';
                    next_state   <= FETCH;

                -- ST Rx, 0x-- (OpCode: 1000 xx 11)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
                    ram_addr     <= MBR;        -- Destino da escrita fornecido pelo MBR
                    ram_dout     <= REG(to_integer(unsigned(IR(3 downto 2)))); -- Dado lido do registrador Rx
                    ram_we       <= '1';        -- Dispara pulso de escrita na RAM
                    next_state   <= FETCH;

                else
                    next_state   <= FETCH;      -- Prevenção para instruções ainda não mapeadas
                end if;

            when WRITE_BACK =>
                -- Ativação do Enable de escrita e definição do destino do dado a ser salvo
                reg_write_en <= '1';
                reg_dest     <= IR(3 downto 2); -- Na sua arquitetura, Rx fica sempre nestes bits 

                -- Condição 1: A instrução foi uma soma (ADD) ou subtração (SUB) 
                if IR(7 downto 4) = "0000" or IR(7 downto 4) = "0001" then 
                    reg_data_in <= alu_resultado;

                -- Condição 2: A instrução foi um Load da RAM (LDR Rx, [Ry] -> OpCode 1001) 
                elsif IR(7 downto 4) = "1001" then
                    -- A RAM já recebeu o endereço no estado EXECUTE e agora está respondendo
                    reg_data_in <= ram_din;

                -- Condição 3: A instrução foi um Move (MOV Rx, Ry -> OpCode 1011) 
                elsif IR(7 downto 4) = "1011" then
                    -- Copia o dado diretamente de Ry
                    reg_data_in <= REG(to_integer(unsigned(IR(1 downto 0)))); 

                -- Condição 4: A instrução foi um Load imediato (LD Rx, 0x-- -> OpCode 1000 Rx 10) 
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    -- O valor 0x-- foi lido da RAM no estado DECODE_2 e aguardou no MBR
                    reg_data_in <= MBR;
                    
                end if;
                                
                next_state <= FETCH; -- Fim do ciclo de instrução. Busca o próximo comando.

            when others =>
                next_state <= FETCH; -- Retorna ao estado inicial em caso de erro
        end case;
    end process;
        