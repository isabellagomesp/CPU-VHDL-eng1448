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

    signal ram : RAM_t := (
        0   => x"20",  -- inc A     -> 0010 00 00 -> A = 1                 
        1   => x"20",  -- inc A     -> 0010 00 00 -> A = 2
        2   => x"24",  -- inc B     -> 0010 01 00 -> B = 1
        3   => x"01",  -- add A,B   -> 0000 00 01 -> A = 2 + 1 = 3 -> GREATER = 1
        4   => x"11",  -- sub A,B   -> 0001 00 01 -> A = 3 - 1 = 2 
        5   => x"21",  -- dec A     -> 0010 00 01 -> A = 1
        6   => x"31",  -- and A,B   -> 0011 00 01 -> A = 1&1 = 1
        7   => x"41",  -- or  A,B   -> 0100 00 01 -> A = 1|1 = 1
        8   => x"61",  -- xor A,B   -> 0110 00 01 -> A = 1ˆ1 = 0 -> ZERO = 1  
        9   => x"50",  -- not A     -> 0101 00 00 -> A = ~0 = 0xFF
        10  => x"70",  -- rol A     -> 0111 00 00 -> A = 0xFF 
        11  => x"71",  -- ror A     -> 0111 00 01 -> A = 0xFF  
        12  => x"72",  -- lsl A     -> 0111 00 10 -> A = 0xFE -> CARRY = 1     
        13  => x"73",  -- lsr A     -> 0111 00 11 -> A = 0x7F 
        14  => x"F0",  -- halt      -> instrução que termina o programa
        255 => x"AA",  -- 255 da RAM é reservada para comunicação com o LCD
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
