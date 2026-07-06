library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Módulo: clock_divider
-- Descrição: Divisor de clock. Gera um clock de saída mais lento a partir do
--            clock rápido da FPGA, para que a CPU execute devagar (permitindo
--            observar PC/IR/REGs/flags a olho nu nos LEDs/LCD).
--
--            Funcionamento: conta as bordas de subida do clock de entrada.
--            Quando o contador chega em DIV_FACTOR-1, inverte a saída e zera o
--            contador. Como a saída inverte a cada DIV_FACTOR bordas, um período
--            completo dela leva 2*DIV_FACTOR bordas:
--
--                frequência de saída = clk_in / (2 * DIV_FACTOR)
--
--            Ex.: 50 MHz com DIV_FACTOR = 25_000_000  ->  clk_out = 1 Hz
--------------------------------------------------------------------------------
entity clock_divider is
    generic (
        DIV_FACTOR : positive := 1_000_000  -- nº de bordas de clk_in por meio-período de clk_out
    );
    port (
        clk_in  : in  std_logic;  -- clock rápido (da FPGA)
        reset   : in  std_logic;
        clk_out : out std_logic  -- clock lento (para a CPU/RAM)
        
    );
end clock_divider;

architecture rtl of clock_divider is
    signal counter : integer range 0 to DIV_FACTOR - 1 := 0;
    signal clk_reg : std_logic := '0';
begin

    process(clk_in, reset)
    begin
        if reset = '1' then
            counter <= 0;
            clk_reg <= '0';
        elsif rising_edge(clk_in) then
            if counter = DIV_FACTOR - 1 then
                counter <= 0;
                clk_reg <= not clk_reg;  -- meio-período concluído: inverte a saída
               
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    clk_out <= clk_reg;

end architecture;

--------------------------------------------------------------------------------
-- EXEMPLO 
-- Clock de entrada sobe a cada 10 ns:
--
--   borda de clk_in   counter   clk_reg (saída)
--      1ª              0 -> 1      0
--      2ª              1 -> 0      0 -> 1
--      3ª              0 -> 1      1
--      4ª              1 -> 0      1 -> 0
--
-- A saída inverte a cada 2 bordas. Como um período completo (sobe e desce)
-- leva 4 bordas, a saída fica 4x mais lenta que a entrada.
-- Fórmula geral:  frequência de saída = clk_in / (2 * DIV_FACTOR)
--
-- Na FPGA, com DIV_FACTOR = 25_000_000 e clock de 50 MHz, dá clk_out = 1 Hz.
--------------------------------------------------------------------------------
