library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Módulo: main (top-level)
-- Descrição: Integra CPU + RAM + divisor de clock + Controlador LCD.
--            A CPU e a RAM rodam no CLOCK LENTO (clk_cpu), gerado pelo divisor,
--            para que a execução seja observável a olho nu. O CLOCK RÁPIDO da
--            FPGA (CLK) fica disponível para o módulo de LCD (etapa 8),
--            que não deve usar o clock lento.
--------------------------------------------------------------------------------
entity main is
    generic (
        -- Fator de divisão do clock. Padrão p/ FPGA de 50 MHz -> ~1 Hz na CPU.
        -- Use 1 em simulação (pass-through) para rodar a CPU em velocidade total.
        CLK_DIV_FACTOR : positive := 25_000_000
    );
    port(
        CLK        : in  std_logic;  -- clock rápido da FPGA (p/ o LCD da etapa 8)
        RESET      : in  std_logic;
        
        -- Sinais de monitoramento (mantidos do seu código original)
        current_ir : out std_logic_vector(7 downto 0);
        alu_leds   : out std_logic_vector(4 downto 0);
        POS_255    : out std_logic_vector(7 downto 0);
        clk_cpu    : out std_logic;  -- clock lento que governa a CPU
        
        -- ==========================================
        -- NOVOS PINOS FÍSICOS - ETAPA 8 (LCD E FLASH)
        -- ==========================================
        lcd_rs     : out std_logic;
        lcd_rw     : out std_logic;
        lcd_e      : out std_logic;
        lcd_d      : out std_logic_vector(7 downto 4);
        sf_ce0     : out std_logic   -- Desativa a memória Flash da Spartan-3E
    );
end main;

architecture structural of main is

    -- ========================================================================
    -- FIOS DE CONEXÃO E SINAIS INTERNOS
    -- ========================================================================
    -- Fios entre CPU e RAM
    signal w_addr       : std_logic_vector(7 downto 0); -- Endereço (MAR)
    signal w_cpu_to_ram : std_logic_vector(7 downto 0); -- Dado para escrever (MBR)
    signal w_ram_to_cpu : std_logic_vector(7 downto 0); -- Dado lido da RAM
    signal w_we         : std_logic;                    -- Write Enable
    
    -- Fios para capturar as saídas e rotear para o LCD e para os Pinos de Debug
    signal w_current_ir : std_logic_vector(7 downto 0);
    signal w_pos_255    : std_logic_vector(7 downto 0);

    -- Fio para o texto traduzido que vai para a tela do LCD
    signal w_inst_txt   : string(1 to 5) := "NOP  ";

    -- Clock lento gerado pelo divisor; alimenta CPU e RAM
    signal w_clk_slow   : std_logic;

begin

    -- ========================================================================
    -- CONFIGURAÇÕES DA PLACA (HARDWARE)
    -- ========================================================================
    -- Espelha os sinais internos para as portas de saída da entidade
    current_ir <= w_current_ir;
    POS_255    <= w_pos_255;
    clk_cpu    <= w_clk_slow;
    
    -- Desativa a memória Flash da placa para liberar os pinos de dados para o LCD
    sf_ce0 <= '1';
    
    -- LCD só recebe dados do nosso controlador (Escrita)
    lcd_rw <= '0';

    -- ========================================================================
    -- DECODIFICADOR DO NOME DA INSTRUÇÃO (Regra 6 do Projeto)
    -- ========================================================================
    DECODER_LCD: process(w_current_ir)
    begin
        -- Lê o OpCode (bits 7 a 4) e traduz para texto (string de 5 caracteres)
        case w_current_ir(7 downto 4) is
            when "0000" => w_inst_txt <= "ADD  ";
            when "0001" => w_inst_txt <= "SUB  ";
            when "0010" => 
                if w_current_ir(1 downto 0) = "00" then w_inst_txt <= "INC  ";
                else w_inst_txt <= "DEC  "; end if;
            when "0011" => w_inst_txt <= "AND  ";
            when "0100" => w_inst_txt <= "OR   ";
            when "0101" => w_inst_txt <= "NOT  ";
            when "0110" => w_inst_txt <= "XOR  ";
            when "0111" =>
                case w_current_ir(1 downto 0) is
                    when "00" => w_inst_txt <= "ROL  ";
                    when "01" => w_inst_txt <= "ROR  ";
                    when "10" => w_inst_txt <= "LSL  ";
                    when others => w_inst_txt <= "LSR  ";
                end case;
            when "1000" =>
                case w_current_ir(1 downto 0) is
                    when "00" => w_inst_txt <= "PUSH ";
                    when "01" => w_inst_txt <= "POP  ";
                    when "10" => w_inst_txt <= "ST   ";
                    when others => w_inst_txt <= "LD   ";
                end case;
            when "1001" => w_inst_txt <= "LDR  ";
            when "1010" => w_inst_txt <= "STR  ";
            when "1011" => w_inst_txt <= "MOV  ";
            when "1100" => 
                case w_current_ir(1 downto 0) is
                    when "00" => w_inst_txt <= "JMP  ";
                    when "01" => w_inst_txt <= "JMPR ";
                    when "10" => w_inst_txt <= "BZ   ";
                    when others => w_inst_txt <= "BNZ  ";
                end case;
            when "1101" =>
                case w_current_ir(1 downto 0) is
                    when "00" => w_inst_txt <= "BCS  ";
                    when "01" => w_inst_txt <= "BCC  ";
                    when "10" => w_inst_txt <= "BEQ  ";
                    when others => w_inst_txt <= "BNEQ ";
                end case;
            when "1110" =>
                if w_current_ir(1 downto 0) = "00" then w_inst_txt <= "BGT  ";
                else w_inst_txt <= "BLT  "; end if;
            when "1111" => w_inst_txt <= "HALT ";
            when others => w_inst_txt <= "NOP  ";
        end case;
    end process;

    -- ========================================================================
    -- INSTANCIAÇÃO DE MÓDULOS
    -- ========================================================================
    
    -- Divisor de clock: CLK (rápido) -> w_clk_slow (lento)
    clkdiv_inst: entity work.clock_divider(rtl)
        generic map(
            DIV_FACTOR => CLK_DIV_FACTOR
        )
        port map(
            clk_in  => CLK,
            reset   => RESET,
            clk_out => w_clk_slow
        );

    -- CPU: Roda no clock lento para podermos observar (Regras 1.a e 1.b)
    cpu_inst: entity work.CPU(Behavioral)
        port map(
            clk        => w_clk_slow,
            reset      => RESET,
            ram_addr   => w_addr,
            ram_din    => w_ram_to_cpu,
            ram_dout   => w_cpu_to_ram,
            ram_we     => w_we,
            current_ir => w_current_ir, -- Sinal capturado internamente
            alu_leds   => alu_leds
        );

    -- RAM: Opera em sincronia com a CPU (Clock lento)
    ram_inst: entity work.RAM_8x256(rtl)
        port map(
            CLK     => w_clk_slow,
            DIN     => w_cpu_to_ram,
            ADDR    => w_addr,
            WE      => w_we,
            DOUT    => w_ram_to_cpu,
            POS_255 => w_pos_255        -- Sinal contínuo da posição 255 (Regra 7)
        );

    -- Controlador do LCD: Opera no Clock Rápido da FPGA (50 MHz)
    lcd_inst: entity work.Controlador_LCD(Behavioral)
        port map(
            clk      => CLK,            -- CLK rápido direto da placa (Regra 1.b)
            reset    => RESET,
            inst_txt => w_inst_txt,     -- Recebe a string traduzida no processo acima
            ram_255  => w_pos_255,      -- Recebe o valor contínuo da RAM
            lcd_rs   => lcd_rs,
            lcd_e    => lcd_e,
            lcd_d    => lcd_d
        );

end structural;