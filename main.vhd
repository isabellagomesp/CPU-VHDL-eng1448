library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Módulo: main (top-level)
-- Descrição: Integra CPU + RAM + divisor de clock.
--            A CPU e a RAM rodam no CLOCK LENTO (clk_cpu), gerado pelo divisor,
--            para que a execução seja observável a olho nu. O CLOCK RÁPIDO da
--            FPGA (CLK) fica disponível para o futuro módulo de LCD (etapa 8),
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
        current_ir : out std_logic_vector(7 downto 0);
        alu_leds   : out std_logic_vector(4 downto 0);
        POS_255    : out std_logic_vector(7 downto 0);
        clk_cpu    : out std_logic   -- clock lento que governa a CPU (exposto p/ depuração / LED de "heartbeat")
    );
end main;

architecture structural of main is

    -- fios de conexão entre CPU e RAM
    signal w_addr   : std_logic_vector(7 downto 0); -- leva o endereço de memória que a CPU quer acessar (MAR) até o pino ADDR da RAM
    signal w_cpu_to_ram : std_logic_vector(7 downto 0); -- leva o dado que a CPU quer escrever na RAM (MBR) até o pino DIN
    signal w_ram_to_cpu : std_logic_vector(7 downto 0); --  leva o dado que a RAM leu de volta para a CPU (pino DOUT → ram_din)
    signal w_we     : std_logic; -- leva o sinal de controle que diz se a operação é leitura ou escrita (Write Enable)

    -- clock lento gerado pelo divisor; alimenta CPU e RAM
    signal w_clk_slow : std_logic;

begin

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

    -- expõe o clock lento (pode ser ligado a um LED para ver a CPU "pulsando")
    clk_cpu <= w_clk_slow;

    cpu_inst: entity work.CPU(Behavioral)
        port map(
            clk        => w_clk_slow,   -- CPU roda no clock lento
            reset      => RESET,
            ram_addr   => w_addr,
            ram_din    => w_ram_to_cpu,
            ram_dout   => w_cpu_to_ram,
            ram_we     => w_we,
            current_ir => current_ir,
            alu_leds   => alu_leds
        );

    ram_inst: entity work.RAM_8x256(rtl)
        port map(
            CLK     => w_clk_slow,      -- RAM compartilha o clock lento da CPU (protocolo MAR/MBR)
            DIN     => w_cpu_to_ram,
            ADDR    => w_addr,
            WE      => w_we,
            DOUT    => w_ram_to_cpu,
            POS_255 => POS_255
        );

end structural;