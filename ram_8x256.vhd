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
        -- -- Bloco 1: instruções ALU (endereços 0-13) -------------------------
        -- Estado dos registradores ao final deste bloco:
        --   A = 0x7F,  B = 1
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

        -- -- Bloco 2: instruções de memória (endereços 14-26) -----------------
        -- Estado dos registradores ao início deste bloco:
        --   A = 0x7F,  B = 1
        -- Estado dos registradores/memória ao final deste bloco:
        --   A=42, B=42, C=42, D=0x41, RAM[0x40]=42, RAM[0x41]=42, SP=0xFE
        14  => x"83",  -- LD  A, #42    -> 1000 00 11 -> byte 1/2 (imediato p/ A)
        15  => x"2A",  --                  immediate = 42         -> A = 42
        16  => x"82",  -- ST  A, 0x40   -> 1000 00 10 -> byte 1/2 (store imediato)
        17  => x"40",  --                  addr = 0x40            -> RAM[0x40] = 42
        18  => x"20",  -- inc A         -> 0010 00 00 -> A = 43
        19  => x"87",  -- LD  B, #0x40  -> 1000 01 11 -> byte 1/2 (imediato p/ B)
        20  => x"40",  --                  immediate = 0x40       -> B = 0x40
        21  => x"91",  -- LDR A, [B]    -> 1001 00 01 -> A = RAM[B=0x40] = 42  (load indireto)
        22  => x"B8",  -- MOV C, A      -> 1011 10 00 -> C = A = 42
        23  => x"8F",  -- LD  D, #0x41  -> 1000 11 11 -> byte 1/2 (imediato p/ D)
        24  => x"41",  --                  immediate = 0x41       -> D = 0x41 (endereço p/ STR)
        25  => x"AB",  -- STR C, [D]    -> 1010 10 11 -> RAM[D=0x41] = C = 42  (store indireto)
        26  => x"88",  -- PUSH C        -> 1000 10 00 -> RAM[SP=0xFE]=42, SP=0xFD
        27  => x"85",  -- POP  B        -> 1000 01 01 -> B = RAM[SP+1=0xFE]=42, SP=0xFE

        -- -- Bloco 3: instruções de salto (endereços 27-37) -------------------
        -- Estado dos registradores ao início deste bloco:
        --   A=42, B=42, C=42
        -- Estado dos registradores/flags ao final deste bloco:
        --   A=0, B=42, C=42, D=36, flags="01001" (EQUAL+ZERO)
        28  => x"C0",  -- JMP 0x33      -> 1100 0000 -> byte 1/2 (salto incondicional)
        29  => x"33",  --                  alvo = 50              -> pula o TRAP em 30 e 50
        30  => x"FF",  -- nunca deve chegar aqui, pulamos para 0x33
        50  => x"21",  -- dec A         -> 0010 00 01 -> não deve executar
        51  => x"8F",  -- LD  D, #57    -> 1000 11 11 -> byte 1/2 (alvo dos branches)
        52  => x"39",  --                  immediate = 36         -> D = 36
        53  => x"11",  -- sub A,B       -> 0001 00 01 -> A=42-42=0 -> ZERO=1, EQUAL=1
        54  => x"CE",  -- BZ  D         -> 1100 11 10 -> ZERO=1 -> PC=REG[D]=36
        55  => x"24",  -- inc B         -> 0010 01 00 -> pulado pelo BZ
        56  => x"24",  -- inc B         -> 0010 01 00 -> pulado pelo BZ
        57  => x"CF",  -- BNZ D         -> 1100 11 11 -> ZERO=1 -> cai p/ 37
        58  => x"F0",  -- HALT          -> 1111 0000 -> trava a CPU

        --16#40# => x"2A",  -- posição 0x40: valor inicial para LDR ler (sobrescrito pelo ST)
        255    => x"AA",  -- reservada para LCD
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
