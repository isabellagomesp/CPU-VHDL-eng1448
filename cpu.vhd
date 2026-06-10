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
    ram_addr <= MAR;
    ram_dout <= MBR;

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
    FSM_LOGIC: process(current_state, IR, alu_flags, MBR, PC, MAR, REG, ram_din)
    begin
        -- Valores Padrão Absolutos
        next_state   <= current_state; 
        update_flags <= '0';
        ram_we       <= '0'; 

        reg_write_en <= '0';
        reg_dest     <= (others => '0');
        reg_data_in  <= (others => '0');
        
        PC_en  <= '0';
        IR_en  <= '0';
        MAR_en <= '0';
        MBR_en <= '0';

        next_PC  <= (others => '0');
        next_IR  <= (others => '0');
        next_MAR <= (others => '0');
        next_MBR <= (others => '0');
        
        SP_inc <= '0';
        SP_dec <= '0';

        -- Máquina de Estados
        case current_state is
            
            when FETCH =>
                -- O MAR já contém o endereço do PC devido à inicialização ou ao estado anterior (Antecipação)
                next_IR    <= ram_din;      
                IR_en      <= '1';
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= DECODE_1;

            when DECODE_1 =>
                if (IR(7 downto 4) = "1000" and (IR(1 downto 0) = "10" or IR(1 downto 0) = "11")) or 
                   (IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000") then
                    
                    -- ANTECIPAÇÃO: Prepara o MAR com o PC (que já aponta para o 2º byte) para usar no DECODE_2
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= DECODE_2; 
                else
                    next_state <= EXECUTE;
                end if;

            when DECODE_2 =>
                -- O MAR já está a apontar para o 2º byte graças à antecipação no DECODE_1.
                -- A memória já colocou o valor no ram_din.
                
                -- Se for ST Rx, 0x-- (OpCode: 1000 xx 11)
                if IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
                    -- ANTECIPAÇÃO PARA EXECUTE: O MAR vai receber o endereço alvo e o MBR recebe o dado a salvar
                    next_MAR <= ram_din; 
                    MAR_en   <= '1';
                    next_MBR <= REG(to_integer(unsigned(IR(3 downto 2)))); 
                    MBR_en   <= '1';
                else
                    -- Para LD e JMP, guardamos simplesmente o valor imediato no MBR
                    next_MBR <= ram_din;      
                    MBR_en   <= '1';
                end if;
                
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= EXECUTE;

            when EXECUTE =>
                -- ADD Rx, Ry (OpCode: 0000)
                if IR(7 downto 4) = "0000" then
                    update_flags <= '1';    
                    next_state   <= WRITE_BACK;

                -- JMP 0x-- (OpCode: 1100 0000)
                elsif IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000" then
                    next_PC      <= MBR;    
                    PC_en        <= '1';
                    
                    -- ANTECIPAÇÃO: Prepara o MAR para o FETCH da nova morada (salto)
                    next_MAR     <= MBR; 
                    MAR_en       <= '1';
                    next_state   <= FETCH;

                -- ST Rx, 0x-- (OpCode: 1000 xx 11)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
                    -- O MAR já tem a morada da memória e o MBR tem o dado (preparados no DECODE_2)
                    ram_we       <= '1'; 
                    
                    -- ANTECIPAÇÃO: Devolve o PC ao MAR para o próximo FETCH
                    next_MAR     <= PC;
                    MAR_en       <= '1';
                    next_state   <= FETCH;

                else
                    -- ANTECIPAÇÃO GERAL: Prepara o MAR com o PC atual para o FETCH seguinte
                    next_MAR     <= PC;
                    MAR_en       <= '1';
                    next_state   <= FETCH; 
                end if;

            when WRITE_BACK =>
                reg_write_en <= '1';
                reg_dest     <= IR(3 downto 2); 

                -- ADD ou SUB
                if IR(7 downto 4) = "0000" or IR(7 downto 4) = "0001" then 
                    reg_data_in <= alu_resultado;

                -- LDR Rx, [Ry]
                elsif IR(7 downto 4) = "1001" then
                    reg_data_in <= ram_din;

                -- MOV Rx, Ry
                elsif IR(7 downto 4) = "1011" then
                    reg_data_in <= REG(to_integer(unsigned(IR(1 downto 0)))); 

                -- LD Rx, 0x--
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    reg_data_in <= MBR;
                end if;
                
                next_MAR   <= PC;
                MAR_en     <= '1';                
                next_state <= FETCH; 

            when others =>
                next_state <= FETCH;
        end case;
    end process;
end Behavioral;