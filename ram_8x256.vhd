library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity RAM_8x256 is
    port(
        CLK     : in  std_logic;
        DIN     : in  std_logic_vector(7 downto 0);  -- Dado de entrada 
        ADDR    : in  std_logic_vector(7 downto 0);  -- Endereço
        WE      : in  std_logic;                     -- Write Enable (1 = escrita)
        DOUT    : out std_logic_vector(7 downto 0);  -- Dado de saída 
        POS_255 : out std_logic_vector(7 downto 0)   -- Posição 255 sempre exposta (reservada para I/O / LCD)
    );
end RAM_8x256;

architecture rtl of RAM_8x256 is

    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);

    -- Endereço de leitura registrado (atualizado na borda de descida do clock)
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

    -- Inicialização com valores de teste (substitui a dependência do NASM)
    -- Posição   0 => 0x12
    -- Posição   1 => 0x34
    -- Posição  12 => 0x56
    -- Posição 255 => 0xAA  — I/O / LCD
    -- Demais posições => 0x00
    signal ram : RAM_t := (
        0   => x"12",
        1   => x"34",
        12  => x"56",
        255 => x"AA",
        others => (others => '0')
    );

begin

    process(CLK) is
    begin
        if falling_edge(CLK) then
            if WE = '1' then
                ram(to_integer(unsigned(ADDR))) <= DIN;  -- Escrita síncrona
            end if;
            read_address <= ADDR;  -- Registra o endereço para leitura no próximo ciclo
        end if;
    end process;

    -- Leitura usa o endereço registrado (1 ciclo de latência após o falling_edge)
    DOUT    <= ram(to_integer(unsigned(read_address)));

    -- Posição 255 sempre visível externamente (usada pela CPU para comunicação com LCD)
    POS_255 <= ram(255);

end architecture;


-- Substituir a inicialização da RAM pelo programa real
    -- usar o NASM para montar um arquivo .asm e gerar os bytes que vão inicializar o signal ram. 
    -- testinst.asm e o trabalho_final.asm 
    -- ver direito como usar isso e como integrar ao codigo
-- Testar a leitura do programa 
    -- verificar no testbench que a CPU consegue fazer fetch das instruções a partir da RAM com o programa real(NAMS)
-- Integrar RAM + CPU 
    -- instanciar a RAM_8x256 dentro da CPU 
    --  MAR -> ADDR, MBR -> DIN/DOUT e o sinal WE controlado pela FSM.