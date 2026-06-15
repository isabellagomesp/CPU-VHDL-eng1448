LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- ============================================================================
-- DECLARAÇÃO DA ENTIDADE CPU
-- ============================================================================
entity CPU is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;

        -- Interface com a Memória RAM
        ram_addr   : out std_logic_vector(7 downto 0);
        ram_din    : in  std_logic_vector(7 downto 0);
        ram_dout   : out std_logic_vector(7 downto 0);
        ram_we     : out std_logic;
        
        -- Interface com Periféricos Externos
        current_ir : out std_logic_vector(7 downto 0);
        alu_leds   : out std_logic_vector(4 downto 0)
    );
end CPU;

-- ============================================================================
-- ARQUITETURA COMPORTAMENTAL
-- ============================================================================
architecture Behavioral of CPU is

    -- Declaração dos 5 estados originais
    type state_type is (FETCH, DECODE_1, DECODE_2, EXECUTE, WRITE_BACK);
    signal current_state, next_state : state_type := FETCH;

    -- Banco de Registradores
    type reg_array is array (0 to 3) of std_logic_vector(7 downto 0);
    signal REG : reg_array := (others => (others => '0'));

    -- Registradores Específicos (SFRs)
    signal PC  : std_logic_vector(7 downto 0) := (others => '0');
    signal IR  : std_logic_vector(7 downto 0) := (others => '0');
    signal MAR : std_logic_vector(7 downto 0) := (others => '0');
    signal MBR : std_logic_vector(7 downto 0) := (others => '0');
    signal SP  : std_logic_vector(7 downto 0) := x"FE"; 

    -- Sinais de controle do Banco de Registradores
    signal reg_write_en : std_logic := '0';
    signal reg_dest     : std_logic_vector(1 downto 0);
    signal reg_data_in  : std_logic_vector(7 downto 0);
    
    -- Enables e Próximos Estados dos SFRs
    signal PC_en, IR_en, MAR_en, MBR_en : std_logic := '0';
    signal next_PC, next_IR, next_MAR, next_MBR : std_logic_vector(7 downto 0) := (others => '0');

    -- Controles da Pilha
    signal SP_inc, SP_dec : std_logic := '0';

    -- Registrador interno de Flags
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

    -- Sinais da ALU
    signal alu_operando_A : std_logic_vector(7 downto 0);
    signal alu_operando_B : std_logic_vector(7 downto 0);
    signal alu_comando    : std_logic_vector(3 downto 0);
    signal alu_resultado  : std_logic_vector(7 downto 0);
    signal alu_carry_out  : std_logic;
    signal alu_flags      : std_logic_vector(4 downto 0);

begin

    -- ========================================================================
    -- CONEXÕES ESTRUTURAIS (Fora de qualquer process)
    -- ========================================================================
    ram_addr <= MAR;
    ram_dout <= MBR;

    current_ir <= IR;          
    alu_leds   <= flags_reg;   

    alu_operando_A <= REG(to_integer(unsigned(IR(3 downto 2)))); 
    alu_operando_B <= REG(to_integer(unsigned(IR(1 downto 0)))); 

    -- ========================================================================
    -- PROCESSO COMBINACIONAL: TRADUTOR DO COMANDO DA ALU (Correção do Erro 1)
    -- ========================================================================
    ALU_CMD_DECODER: process(IR)
    begin
        case IR(7 downto 4) is
            when "0000" => alu_comando <= "0000"; -- add
            when "0001" => alu_comando <= "0001"; -- sub
            when "0010" => 
                if IR(1 downto 0) = "00" then alu_comando <= "0010"; -- inc
                else alu_comando <= "0011"; -- dec
                end if;
            when "0011" => alu_comando <= "0100"; -- and
            when "0100" => alu_comando <= "0101"; -- or
            when "0101" => alu_comando <= "0110"; -- not
            when "0110" => alu_comando <= "0111"; -- xor
            when "0111" =>
                case IR(1 downto 0) is
                    when "00" => alu_comando <= "1000"; -- rol
                    when "01" => alu_comando <= "1001"; -- ror
                    when "10" => alu_comando <= "1010"; -- lsl
                    when others => alu_comando <= "1011"; -- lsr
                end case;
            when others => alu_comando <= "0000";
        end case;
    end process;

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

    -- ========================================================================
    -- PROCESSO SÍNCRONO: DATAPATH (Registradores)
    -- ========================================================================
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
            if reg_write_en = '1' then
                REG(to_integer(unsigned(reg_dest))) <= reg_data_in;
            end if;

            if PC_en = '1' then PC <= next_PC; end if;
            if IR_en = '1' then IR <= next_IR; end if;
            if MAR_en = '1' then MAR <= next_MAR; end if;
            if MBR_en = '1' then MBR <= next_MBR; end if;
            
            if SP_inc = '1' then
                SP <= std_logic_vector(unsigned(SP) + 1);
            elsif SP_dec = '1' then
                SP <= std_logic_vector(unsigned(SP) - 1);
            end if;

            if update_flags = '1' then
                flags_reg <= alu_flags;
            end if;
        end if;
    end process;

    -- ========================================================================
    -- PROCESSO SÍNCRONO: TRANSIÇÃO DE ESTADOS DA FSM
    -- ========================================================================
    FSM_UPDATE: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= FETCH; 
        elsif rising_edge(clk) then
            current_state <= next_state; 
        end if;
    end process;

    -- ========================================================================
    -- PROCESSO COMBINACIONAL: LÓGICA DE CONTROLE DA FSM
    -- ========================================================================
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
                next_IR    <= ram_din;      
                IR_en      <= '1';
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= DECODE_1;

            when DECODE_1 =>
                if (IR(7 downto 4) = "1000" and (IR(1 downto 0) = "10" or IR(1 downto 0) = "11")) or 
                   (IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000") then
                    
                    next_MAR   <= PC;
                    MAR_en     <= '1';
                    next_state <= DECODE_2; 
                else
                    next_state <= EXECUTE;
                end if;

            when DECODE_2 =>
                
                -- Se for ST Rx, 0x-- (OpCode: 1000 xx 10) - CORREÇÃO DE LD/ST
                if IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    next_MAR <= ram_din; 
                    MAR_en   <= '1';
                    next_MBR <= REG(to_integer(unsigned(IR(3 downto 2)))); 
                    MBR_en   <= '1';
                else
                    -- LD e JMP
                    next_MBR <= ram_din;      
                    MBR_en   <= '1';
                end if;
                
                next_PC    <= std_logic_vector(unsigned(PC) + 1); 
                PC_en      <= '1';
                next_state <= EXECUTE;

            when EXECUTE =>
                -- Qualquer instrução ALU (OpCodes 0000 a 0111) - CORREÇÃO DE FLAGS E WRITE_BACK
                if IR(7 downto 4) <= "0111" then
                    update_flags <= '1';    
                    next_state   <= WRITE_BACK;

                -- JMP 0x-- (OpCode: 1100 0000)
                elsif IR(7 downto 4) = "1100" and IR(3 downto 0) = "0000" then
                    next_PC      <= MBR;    
                    PC_en        <= '1';
                    
                    next_MAR     <= MBR; 
                    MAR_en       <= '1';
                    next_state   <= FETCH;

                -- ST Rx, 0x-- (OpCode: 1000 xx 10) - CORREÇÃO DE LD/ST
                elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "10" then
                    ram_we       <= '1'; 
                    
                    next_MAR     <= PC;
                    MAR_en       <= '1';
                    next_state   <= FETCH;

                else
                    next_MAR     <= PC;
                    MAR_en       <= '1';
                    next_state   <= FETCH; 
                end if;

            when WRITE_BACK =>
                reg_write_en <= '1';
                reg_dest     <= IR(3 downto 2); 

                -- Qualquer instrução ALU (OpCodes 0000 a 0111) - CORREÇÃO DE GRAVAÇÃO
                if IR(7 downto 4) <= "0111" then 
                    reg_data_in <= alu_resultado;

                -- LDR Rx, [Ry]
                elsif IR(7 downto 4) = "1001" then
                    reg_data_in <= ram_din;

                -- MOV Rx, Ry
                elsif IR(7 downto 4) = "1011" then
                    reg_data_in <= REG(to_integer(unsigned(IR(1 downto 0)))); 

                -- LD Rx, 0x-- (OpCode 1000 xx 11) - CORREÇÃO DE LD/ST
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