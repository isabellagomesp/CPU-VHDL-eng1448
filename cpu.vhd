LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

--------------------------------------------------------------------------------
-- Módulo: CPU (Central Processing Unit)
-- Descrição: Implementação da Unidade Central de Processamento.
--            Suporta instruções aritméticas, lógicas, manipulação de pilha (Stack), 
--            acesso à memória RAM estática e saltos incondicionais/condicionais.
--            A interface com a memória é estritamente controlada pelos 
--            registradores MAR (Address) e MBR (Data).
--------------------------------------------------------------------------------
entity CPU is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;

        -- Interface de comunicação com a Memória RAM Externa
        ram_addr   : out std_logic_vector(7 downto 0);
        ram_din    : in  std_logic_vector(7 downto 0);
        ram_dout   : out std_logic_vector(7 downto 0);
        ram_we     : out std_logic;
        
        -- Interface de Periféricos e Monitoramento (I/O)
        current_ir : out std_logic_vector(7 downto 0);
        alu_leds   : out std_logic_vector(4 downto 0)
    );
end CPU;

architecture Behavioral of CPU is

    -- ========================================================================
    -- DEFINIÇÃO DE TIPOS E ESTADOS DA UNIDADE DE CONTROLE (FSM)
    -- ========================================================================
    type state_type is (FETCH, DECODE_1, DECODE_2, EXECUTE, WRITE_BACK);
    signal current_state, next_state : state_type := FETCH;

    -- ========================================================================
    -- DECLARAÇÃO DOS REGISTRADORES INTERNOS (DATAPATH)
    -- ========================================================================
    -- Banco de Registradores de Propósito Geral (GPR): A(0), B(1), C(2), D(3)
    type reg_array is array (0 to 3) of std_logic_vector(7 downto 0);
    signal REG : reg_array := (others => (others => '0'));

    -- Registradores de Função Especial (SFR)
    signal PC  : std_logic_vector(7 downto 0) := (others => '0'); -- Program Counter
    signal IR  : std_logic_vector(7 downto 0) := (others => '0'); -- Instruction Register
    signal MAR : std_logic_vector(7 downto 0) := (others => '0'); -- Memory Address Register
    signal MBR : std_logic_vector(7 downto 0) := (others => '0'); -- Memory Buffer Register
    
    -- Stack Pointer inicializado no topo da área permitida da memória (0xFE)
    signal SP  : std_logic_vector(7 downto 0) := x"FE"; 

    -- ========================================================================
    -- SINAIS DE CONTROLE DO DATAPATH
    -- ========================================================================
    -- Controles do Banco de Registradores
    signal reg_write_en : std_logic := '0';
    signal reg_dest     : std_logic_vector(1 downto 0);
    signal reg_data_in  : std_logic_vector(7 downto 0);
    
    -- Enables de Escrita e Barramento de Próximo Estado para SFRs
    signal PC_en, IR_en, MAR_en, MBR_en         : std_logic := '0';
    signal next_PC, next_IR, next_MAR, next_MBR : std_logic_vector(7 downto 0) := (others => '0');

    -- Sinais de manipulação da Pilha (Stack)
    signal SP_inc, SP_dec : std_logic := '0';

    -- Registrador de Estado para retenção das Flags da ALU
    signal flags_reg    : std_logic_vector(4 downto 0) := (others => '0');
    signal update_flags : std_logic := '0';

    -- ========================================================================
    -- COMPONENTES EXTERNOS
    -- ========================================================================
    -- Unidade Lógica e Aritmética (ALU)
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

    -- Barramentos de interconexão com a ALU
    signal alu_operando_A : std_logic_vector(7 downto 0);
    signal alu_operando_B : std_logic_vector(7 downto 0);
    signal alu_comando    : std_logic_vector(3 downto 0);
    signal alu_resultado  : std_logic_vector(7 downto 0);
    signal alu_carry_out  : std_logic;
    signal alu_flags      : std_logic_vector(4 downto 0);

begin

    -- ========================================================================
    -- ROTEAMENTO ESTRUTURAL CONTÍNUO
    -- ========================================================================
    -- Roteamento restrito de acesso à memória via MAR/MBR
    ram_addr <= MAR;
    ram_dout <= MBR;

    -- Espelhamento de sinais internos para I/O
    current_ir <= IR;          
    alu_leds   <= flags_reg;   

    -- Alimentação contínua da ALU baseada nos campos Rx e Ry do Instruction Register
    alu_operando_A <= REG(to_integer(unsigned(IR(3 downto 2)))); 
    alu_operando_B <= REG(to_integer(unsigned(IR(1 downto 0)))); 

    ---------------------------------------------------------------------------
    -- Processo: ALU_CMD_DECODER
    -- Descrição: Decodificador combinacional que traduz os bits de OpCode da
    --            arquitetura (Instruction Register) para os comandos internos 
    --            suportados pela entidade ALU.
    ---------------------------------------------------------------------------
    ALU_CMD_DECODER: process(IR)
    begin
        case IR(7 downto 4) is
            when "0000" => alu_comando <= "0000"; -- Instrução: ADD
            when "0001" => alu_comando <= "0001"; -- Instrução: SUB
            when "0010" => 
                if IR(1 downto 0) = "00" then alu_comando <= "0010"; -- Instrução: INC
                else alu_comando <= "0011"; -- Instrução: DEC
                end if;
            when "0011" => alu_comando <= "0100"; -- Instrução: AND
            when "0100" => alu_comando <= "0101"; -- Instrução: OR
            when "0101" => alu_comando <= "0110"; -- Instrução: NOT
            when "0110" => alu_comando <= "0111"; -- Instrução: XOR
            when "0111" =>
                case IR(1 downto 0) is
                    when "00" => alu_comando <= "1000"; -- Instrução: ROL
                    when "01" => alu_comando <= "1001"; -- Instrução: ROR
                    when "10" => alu_comando <= "1010"; -- Instrução: LSL
                    when others => alu_comando <= "1011"; -- Instrução: LSR
                end case;
            when others => alu_comando <= "0000"; -- Padrão (NOP estrutural)
        end case;
    end process;

    -- Instanciação da Unidade Lógica e Aritmética
    U_ALU: alu port map(
        A     => alu_operando_A,
        B     => alu_operando_B,
        CMD   => alu_comando,
        C_IN  => '0',
        C_OUT => alu_carry_out,
        FLAGS => alu_flags,
        S     => alu_resultado
    );

    ---------------------------------------------------------------------------
    -- Processo: REGISTERS_UPDATE
    -- Descrição: Atualização síncrona do Datapath. Realiza as transferências 
    --            de dados entre registradores e manipula ponteiros (SP/PC) 
    --            na borda de subida do clock, baseando-se nos sinais de enable.
    ---------------------------------------------------------------------------
    REGISTERS_UPDATE: process(clk, reset)
    begin
        if reset = '1' then
            PC        <= (others => '0');
            IR        <= (others => '0');
            MAR       <= (others => '0');
            MBR       <= (others => '0');
            SP        <= x"FE"; 
            REG       <= (others => (others => '0'));
            flags_reg <= (others => '0');
            
        elsif rising_edge(clk) then
            
            -- Banco de Registradores de Propósito Geral
            if reg_write_en = '1' then
                REG(to_integer(unsigned(reg_dest))) <= reg_data_in;
            end if;

            -- Registradores de Função Especial
            if PC_en = '1'  then PC  <= next_PC;  end if;
            if IR_en = '1'  then IR  <= next_IR;  end if;
            if MAR_en = '1' then MAR <= next_MAR; end if;
            if MBR_en = '1' then MBR <= next_MBR; end if;
            
            -- Lógica de manipulação do Stack Pointer (SP)
            if SP_inc = '1' then
                SP <= std_logic_vector(unsigned(SP) + 1);
            elsif SP_dec = '1' then
                SP <= std_logic_vector(unsigned(SP) - 1);
            end if;

            -- Armazenamento persistente do status (Flags) gerado pela ALU
            if update_flags = '1' then
                flags_reg <= alu_flags;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Processo: FSM_UPDATE
    -- Descrição: Atualização síncrona do estado atual da Unidade de Controle.
    ---------------------------------------------------------------------------
    FSM_UPDATE: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= FETCH; 
        elsif rising_edge(clk) then
            current_state <= next_state; 
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Processo: FSM_LOGIC
    -- Descrição: Lógica combinacional da Unidade de Controle. Responsável por
    --            gerar os sinais de controle (Enables, Multiplexadores lógicos, 
    --            sinais de R/W) para orquestrar a execução das instruções.
    ---------------------------------------------------------------------------
    FSM_LOGIC: process(current_state, IR, alu_flags, MBR, PC, MAR, REG, ram_din, SP, flags_reg)
    begin
        -- Inicialização de valores padrão (Prevenção de latches indesejados)
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

        -- FSM: Decodificação de Ciclos
        case current_state is
            
            -- Fase de Busca de Instrução (Instruction Fetch)
            when FETCH =>
                next_IR    <= ram_din;      
                IR_en      <= '1';
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= DECODE_1;

            -- Fase de Decodificação Primária (Instruction Decode & Lookahead)
            when DECODE_1 =>
                -- Identificação de instruções com tamanho de 2 Bytes (Imediatos ou Salto)
                if (IR(7 downto 4) = "1000" and (IR(1 downto 0) = "10" or IR(1 downto 0) = "11")) or 
                   (IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000") then
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= DECODE_2; 
                
                -- Memory Store Indireto (STR Rx, [Ry])
                elsif IR(7 downto 4) = "1010" then
                    next_MAR   <= REG(to_integer(unsigned(IR(1 downto 0)))); 
                    MAR_en     <= '1';
                    next_MBR   <= REG(to_integer(unsigned(IR(3 downto 2)))); 
                    MBR_en     <= '1';
                    next_state <= EXECUTE;

                -- Memory Load Indireto (LDR Rx, [Ry])
                elsif IR(7 downto 4) = "1001" then
                    next_MAR   <= REG(to_integer(unsigned(IR(1 downto 0)))); 
                    MAR_en     <= '1';
                    next_state <= EXECUTE;

                -- Empilhamento de Dados (PUSH Rx)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "00" then
                    next_MAR   <= SP; 
                    MAR_en     <= '1';
                    next_MBR   <= REG(to_integer(unsigned(IR(3 downto 2)))); 
                    MBR_en     <= '1';
                    next_state <= EXECUTE;

                -- Desempilhamento de Dados (POP Rx)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
                    next_MAR   <= std_logic_vector(unsigned(SP) + 1); 
                    MAR_en     <= '1';
                    next_state <= EXECUTE;

                -- Operações intrínsecas (Registrador-Registrador, 1 Byte)
                else
                    next_state <= EXECUTE;
                end if;

            -- Fase de Decodificação Secundária (Operando Imediato)
            when DECODE_2 =>
                -- Memory Store Imediato (ST Rx, 0x--)
                if IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    next_MAR <= ram_din; 
                    MAR_en   <= '1';
                    next_MBR <= REG(to_integer(unsigned(IR(3 downto 2)))); 
                    MBR_en   <= '1';
                -- Memory Load Imediato (LD) e Saltos
                else
                    next_MBR <= ram_din;      
                    MBR_en   <= '1';
                end if;
                
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= EXECUTE;

            -- Fase de Execução (Execution & Branching)
            when EXECUTE =>
                
                -- Classe: Operações Lógicas e Aritméticas
                if IR(7 downto 4) <= "0111" then
                    update_flags <= '1';    
                    next_state   <= WRITE_BACK;

                -- Classe: Acesso à Memória (Leitura - LDR / POP)
                elsif IR(7 downto 4) = "1001" or (IR(7 downto 4) = "1000" and IR(1 downto 0) = "01") then
                    if IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
                        SP_inc <= '1'; -- POP: Liberação de espaço na pilha
                    end if;
                -- LDR Rx, [Ry] (1001)
                elsif IR(7 downto 4) = "1001" then
                    next_state <= WRITE_BACK;

                -- POP Rx (1000 xx 01)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
                    SP_inc     <= '1'; -- POP: Libera espaço na pilha incrementando o SP 
                    next_state <= WRITE_BACK;

                -- LD Rx, #imm (OpCode: 1000 xx 11) - BUG 1 RESOLVIDO
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= WRITE_BACK;

                -- Classe: Acesso à Memória (Escrita - STR / PUSH)
                elsif IR(7 downto 4) = "1010" or (IR(7 downto 4) = "1000" and IR(1 downto 0) = "00") then
                    ram_we     <= '1'; 
                    if IR(7 downto 4) = "1000" and IR(1 downto 0) = "00" then
                        SP_dec <= '1'; -- PUSH: Alocação de espaço na pilha
                    end if;
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= FETCH;

                -- Memory Store Imediato (ST Rx, 0x--)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    ram_we     <= '1'; 
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= FETCH;

                -- Classe: Movimentação de Dados Internos (MOV)
                elsif IR(7 downto 4) = "1011" then
                    next_state <= WRITE_BACK;

                -- Classe: Controle de Fluxo de Execução (Jumps & Branches)
                elsif IR(7 downto 4) = "1100" or IR(7 downto 4) = "1101" or IR(7 downto 4) = "1110" then
                    
                    -- Salto Incondicional Imediato (JMP 0x--)
                    if IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000" then
                        next_PC    <= MBR;    
                        PC_en      <= '1';
                        next_MAR   <= MBR; 
                        MAR_en     <= '1';
                        
                    -- Saltos Condicionais e Diretos via Registrador
                    else
                        if (IR(7 downto 4) = "1100" and IR(1 downto 0) = "01") or                                  -- JMPR
                           (IR(7 downto 4) = "1100" and IR(1 downto 0) = "10" and flags_reg(0) = '1') or           -- BZ
                           (IR(7 downto 4) = "1100" and IR(1 downto 0) = "11" and flags_reg(0) = '0') or           -- BNZ
                           (IR(7 downto 4) = "1101" and IR(1 downto 0) = "00" and flags_reg(4) = '1') or           -- BCS
                           (IR(7 downto 4) = "1101" and IR(1 downto 0) = "01" and flags_reg(4) = '0') or           -- BCC
                           (IR(7 downto 4) = "1101" and IR(1 downto 0) = "10" and flags_reg(3) = '1') or           -- BEQ
                           (IR(7 downto 4) = "1101" and IR(1 downto 0) = "11" and flags_reg(3) = '0') or           -- BNEQ
                           (IR(7 downto 4) = "1110" and IR(1 downto 0) = "00" and flags_reg(1) = '1') or           -- BGT
                           (IR(7 downto 4) = "1110" and IR(1 downto 0) = "01" and flags_reg(2) = '1') then         -- BLT
                            
                            -- Resolução da Condição: True (Altera o Program Counter)
                            next_PC  <= REG(to_integer(unsigned(IR(3 downto 2))));
                            PC_en    <= '1';
                            next_MAR <= REG(to_integer(unsigned(IR(3 downto 2))));
                            MAR_en   <= '1';
                        else
                            -- Resolução da Condição: False (Mantém fluxo sequencial)
                            next_MAR <= PC;
                            MAR_en   <= '1';
                        end if;
                    end if;
                    
                    next_state <= FETCH;

                -- Classe: Parada de Execução (HALT)
                elsif IR(7 downto 4) = "1111" then
                    next_state <= current_state; 

                else
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= FETCH; 
                end if;

            -- Fase de Escrita em Banco de Registradores (Write-Back)
            when WRITE_BACK =>
                reg_write_en <= '1';
                reg_dest     <= IR(3 downto 2); 

                -- Origem do Dado: Saída Lógica/Aritmética
                if IR(7 downto 4) <= "0111" then 
                    reg_data_in <= alu_resultado;

                -- Origem do Dado: Memória RAM (LDR, POP)
                elsif IR(7 downto 4) = "1001" or (IR(7 downto 4) = "1000" and IR(1 downto 0) = "01") then
                    reg_data_in <= ram_din; 

                -- Origem do Dado: Movimentação Interna GPR (MOV)
                elsif IR(7 downto 4) = "1011" then
                    reg_data_in <= REG(to_integer(unsigned(IR(1 downto 0)))); 

                -- Origem do Dado: Imediato Arquivado em MBR (LD 0x--)
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
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
