LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- Declaração da Entidade
entity CPU is {
    clk   : in std_logic;
    reset : in std_logic;

    -- Sinais controlados pela FSM
    ram_addr   : out std_logic_vector(7 downto 0); -- Endereço enviado para a RAM
    ram_din    : in  std_logic_vector(7 downto 0); -- Dado lido vindo da RAM
    ram_dout   : out std_logic_vector(7 downto 0); -- Dado enviado para escrita na RAM
    ram_we     : out std_logic;                    -- Habilitação de escrita na RAM (Write Enable)
    
    current_ir : out std_logic_vector(7 downto 0); -- Envia o IR atual para decodificação do LCD
    alu_leds   : out std_logic_vector(4 downto 0)
}

architecture Behavioral of CPU is

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

begin
    -- Processo responsável pela atualização síncrona dos registradores
    REGISTERS_UPDATE: process(clk, reset)
    begin
        if reset = '1' then
            -- Condição de Reset Assíncrono (zerar a máquina)
            PC  <= (others => '0');
            IR  <= (others => '0');
            MAR <= (others => '0');
            MBR <= (others => '0');
            SP  <= x"FE"; -- Reinicializa o SP para 254
            REG <= (others => (others => '0'));
            
        elsif rising_edge(clk) then
            
            -- 1. Atualização do Banco de Registradores (A, B, C, D)
            if reg_write_en = '1' then
                -- O índice (reg_dest) vem da decodificação da instrução (Rx ou Ry)
                REG(to_integer(unsigned(reg_dest))) <= reg_data_in;
            end if;

            -- 2. Atualização dos Registradores Específicos
            -- A FSM da Etapa 4 irá controlar esses enables ('_en')
            
            if PC_en = '1' then
                PC <= next_PC; -- next_PC pode ser PC+1 ou endereço de salto
            end if;

            if IR_en = '1' then
                IR <= next_IR; -- Recebe o dado lido da memória na fase de Fetch
            end if;

            if MAR_en = '1' then
                MAR <= next_MAR; -- Recebe o endereço para acessar a memória
            end if;

            if MBR_en = '1' then
                MBR <= next_MBR; -- Recebe o dado indo/vindo da memória
            end if;
            
            if SP_inc = '1' then
                SP <= std_logic_vector(unsigned(SP) + 1); -- POP incrementa [cite: 27]
            elsif SP_dec = '1' then
                SP <= std_logic_vector(unsigned(SP) - 1); -- PUSH decrementa [cite: 26]
            end if;

        end if;
    end process;