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

--    signal ram : RAM_t := (
--        -- -- Bloco 1: instruções ALU (endereços 0-13) -------------------------
--        -- Estado dos registradores ao final deste bloco:
--        --   A = 0x7F,  B = 1
--        0   => x"20",  -- inc A     -> 0010 00 00 -> A = 1                 
--        1   => x"20",  -- inc A     -> 0010 00 00 -> A = 2
--        2   => x"24",  -- inc B     -> 0010 01 00 -> B = 1
--        3   => x"01",  -- add A,B   -> 0000 00 01 -> A = 2 + 1 = 3 -> GREATER = 1
--        4   => x"11",  -- sub A,B   -> 0001 00 01 -> A = 3 - 1 = 2 
--        5   => x"21",  -- dec A     -> 0010 00 01 -> A = 1
--        6   => x"31",  -- and A,B   -> 0011 00 01 -> A = 1&1 = 1
--        7   => x"41",  -- or  A,B   -> 0100 00 01 -> A = 1|1 = 1
--        8   => x"61",  -- xor A,B   -> 0110 00 01 -> A = 1ˆ1 = 0 -> ZERO = 1  
--        9   => x"50",  -- not A     -> 0101 00 00 -> A = ~0 = 0xFF
--        10  => x"70",  -- rol A     -> 0111 00 00 -> A = 0xFF 
--        11  => x"71",  -- ror A     -> 0111 00 01 -> A = 0xFF  
--        12  => x"72",  -- lsl A     -> 0111 00 10 -> A = 0xFE -> CARRY = 1     
--        13  => x"73",  -- lsr A     -> 0111 00 11 -> A = 0x7F 
--
--        -- -- Bloco 2: instruções de memória (endereços 14-26) -----------------
--        -- Estado dos registradores ao início deste bloco:
--        --   A = 0x7F,  B = 1
--        -- Estado dos registradores/memória ao final deste bloco:
--        --   A=42, B=42, C=42, D=0x41, RAM[0x40]=42, RAM[0x41]=42, SP=0xFE
--        14  => x"83",  -- LD  A, #42    -> 1000 00 11 -> byte 1/2 (imediato p/ A)
--        15  => x"2A",  --                  immediate = 42         -> A = 42
--        16  => x"82",  -- ST  A, 0x40   -> 1000 00 10 -> byte 1/2 (store imediato)
--        17  => x"40",  --                  addr = 0x40            -> RAM[0x40] = 42
--        18  => x"20",  -- inc A         -> 0010 00 00 -> A = 43
--        19  => x"87",  -- LD  B, #0x40  -> 1000 01 11 -> byte 1/2 (imediato p/ B)
--        20  => x"40",  --                  immediate = 0x40       -> B = 0x40
--        21  => x"91",  -- LDR A, [B]    -> 1001 00 01 -> A = RAM[B=0x40] = 42  (load indireto)
--        22  => x"B8",  -- MOV C, A      -> 1011 10 00 -> C = A = 42
--        23  => x"8F",  -- LD  D, #0x41  -> 1000 11 11 -> byte 1/2 (imediato p/ D)
--        24  => x"41",  --                  immediate = 0x41       -> D = 0x41 (endereço p/ STR)
--        25  => x"AB",  -- STR C, [D]    -> 1010 10 11 -> RAM[D=0x41] = C = 42  (store indireto)
--        26  => x"88",  -- PUSH C        -> 1000 10 00 -> RAM[SP=0xFE]=42, SP=0xFD
--        27  => x"85",  -- POP  B        -> 1000 01 01 -> B = RAM[SP+1=0xFE]=42, SP=0xFE
--
--        -- -- Bloco 3: instruções de salto (endereços 27-37) -------------------
--        -- Estado dos registradores ao início deste bloco:
--        --   A=42, B=42, C=42
--        -- Estado dos registradores/flags ao final deste bloco:
--        --   A=0, B=42, C=42, D=36, flags="01001" (EQUAL+ZERO)
--        28  => x"C0",  -- JMP 0x33      -> 1100 0000 -> byte 1/2 (salto incondicional)
--        29  => x"33",  --                  alvo = 50              -> pula o TRAP em 30 e 50
--        30  => x"FF",  -- nunca deve chegar aqui, pulamos para 0x33
--        50  => x"21",  -- dec A         -> 0010 00 01 -> não deve executar
--        51  => x"8F",  -- LD  D, #57    -> 1000 11 11 -> byte 1/2 (alvo dos branches)
--        52  => x"39",  --                  immediate = 36         -> D = 36
--        53  => x"11",  -- sub A,B       -> 0001 00 01 -> A=42-42=0 -> ZERO=1, EQUAL=1
--        54  => x"CE",  -- BZ  D         -> 1100 11 10 -> ZERO=1 -> PC=REG[D]=36
--        55  => x"24",  -- inc B         -> 0010 01 00 -> pulado pelo BZ
--        56  => x"24",  -- inc B         -> 0010 01 00 -> pulado pelo BZ
--        57  => x"CF",  -- BNZ D         -> 1100 11 11 -> ZERO=1 -> NAO tomado -> cai p/ 58
--        58  => x"C0",  -- JMP 0x80      -> 1100 0000 -> byte 1/2 (salta p/ o Bloco 4)
--        59  => x"80",  --                  alvo = 128 (0x80) -> pula o vao 60-127
--
--             -- -- Bloco 4: BCS, BCC, BEQ, BNEQ, BGT, BLT (enderecos 128-180) ----------
--        -- Um teste por instrucao: branch TOMADO pula um TRAP logo em seguida.
--        -- Flags ALU: (4)=CARRY (3)=EQUAL (2)=SMALLER (1)=GREATER (0)=ZERO
--
--        -- == BCS: CARRY=1 ==========================================
--        128 => x"83",  -- LD A,#0xFF
--        129 => x"FF",
--        130 => x"87",  -- LD B,#1
--        131 => x"01",
--        132 => x"01",  -- add A,B   -> A=0x00, CARRY=1
--        133 => x"8F",  -- LD D,#137
--        134 => x"89",  --   137 = 0x89
--        135 => x"DC",  -- BCS D     -> CARRY=1 -> TOMADO -> 137 (pula trap 136)
--        136 => x"20",  -- deve ser pulado
--
--        -- == BCC: CARRY=0 ==========================================
--        137 => x"87",  -- LD B,#1
--        138 => x"01",
--        139 => x"01",  -- add A,B   -> A=1, CARRY=0  (A=0 da instrucao anterior)
--        140 => x"8F",  -- LD D,#144
--        141 => x"90",  --   144 = 0x90
--        142 => x"DD",  -- BCC D     -> CARRY=0 -> TOMADO -> 144 (pula trap 143)
--        143 => x"20",  -- deve ser pulado
--
--        -- == BEQ: EQUAL=1 -> TOMADO ==========================================
--        144 => x"83",  -- LD A,#5
--        145 => x"05",
--        146 => x"87",  -- LD B,#5
--        147 => x"05",
--        148 => x"11",  -- sub A,B   -> A=0, EQUAL=1, ZERO=1
--        149 => x"8F",  -- LD D,#153
--        150 => x"99",  --   153 = 0x99
--        151 => x"DE",  -- BEQ D     -> EQUAL=1 -> TOMADO -> 153 (pula trap 152)
--        152 => x"20",  -- deve ser pulado
--
--        -- == BNEQ: EQUAL=0 =========================================
--        153 => x"83",  -- LD A,#7
--        154 => x"07",
--        155 => x"87",  -- LD B,#3
--        156 => x"03",
--        157 => x"11",  -- sub A,B   -> A=4, EQUAL=0, GREATER=1
--        158 => x"8F",  -- LD D,#162
--        159 => x"A2",  --   162 = 0xA2
--        160 => x"DF",  -- BNEQ D    -> EQUAL=0 -> TOMADO -> 162 (pula trap 161)
--        161 => x"20",  -- TRAP (deve ser pulado)
--
--        -- == BGT: GREATER=1 ========================================
--        162 => x"83",  -- LD A,#9
--        163 => x"09",
--        164 => x"87",  -- LD B,#2
--        165 => x"02",
--        166 => x"11",  -- sub A,B   -> A=7, GREATER=1, SMALLER=0
--        167 => x"8F",  -- LD D,#171
--        168 => x"AB",  --   171 = 0xAB
--        169 => x"EC",  -- BGT D     -> GREATER=1 -> TOMADO -> 171 (pula trap 170)
--        170 => x"20",  -- deve ser pulado
--
--        -- == BLT: SMALLER=1 ========================================
--        171 => x"83",  -- LD A,#2
--        172 => x"02",
--        173 => x"87",  -- LD B,#9
--        174 => x"09",
--        175 => x"11",  -- sub A,B   -> A=0xF9, SMALLER=1, GREATER=0
--        176 => x"8F",  -- LD D,#180
--        177 => x"B4",  --   180 = 0xB4
--        178 => x"ED",  -- BLT D     -> SMALLER=1 -> TOMADO -> 180 (pula trap 179)
--        179 => x"20",  -- TRAP (deve ser pulado)
--
--        180 => x"F0",  -- HALT      -> 1111 0000 -> trava a CPU
--        255    => x"AA",  -- reservada para LCD
--        others => (others => '0')
--    );

    -- fib.asm
    signal ram : RAM_t := (
        0   => "10000011", --  11:                   ld ra, 0
        1   => "00000000", --  11:                   0
        2   => "10000000", --  12:                   push ra
        3   => "10000000", --  13:                   push ra
        4   => "10000000", --  14:                   push ra
        5   => "10000001", --  17:                   pop ra
        6   => "10000001", --  18:                   pop ra
        7   => "10000001", --  19:                   pop ra
        8   => "00100000", --  21:                   inc ra
        9   => "10000000", --  23:                   push ra
        10  => "10000000", --  24:                   push ra
        11  => "10000000", --  25:                   push ra
        12  => "10001111", --  27:                   ld rd, @loop_count
        13  => "00000011", --  27:                   3
        14  => "00111100", --  28:                   and rd, ra
        15  => "10001111", --  29:                   ld rd, @end_loop
        16  => "00100100", --  29:                   36
        17  => "11011110", --  30:                   beq rd
        18  => "10001111", --  33:                   ld rd, @fib_stop
        19  => "01100000", --  33:                   96
        20  => "00111100", --  34:                   and rd, ra
        21  => "10001111", --  35:                   ld rd, @loop
        22  => "00000101", --  35:                   5
        23  => "11101101", --  36:                   blt rd
        24  => "10000101", --  38:                   pop rb
        25  => "10000001", --  39:                   pop ra
        26  => "10000000", --  40:                   push ra
        27  => "10001001", --  41:                   pop rc
        28  => "00000001", --  43:                   add ra, rb
        29  => "10001111", --  44:                   ld rd, @io
        30  => "11111111", --  44:                   255
        31  => "10100011", --  45:                   str ra, [rd]
        32  => "10000000", --  47:                   push ra
        33  => "10001000", --  48:                   push rc
        34  => "11000000", --  50:                   jmp @loop_fib
        35  => "00010010", --  50:                   18
        36  => "10000001", --  55:                   pop ra
        37  => "10000001", --  56:                   pop ra
        38  => "10000001", --  57:                   pop ra
        39  => "10000011", --  59:                   ld ra, @shift_init_value
        40  => "11111110", --  59:                   254
        41  => "10001111", --  63:                   ld rd, @io
        42  => "11111111", --  63:                   255
        43  => "10100011", --  64:                   str ra, [rd]
        44  => "01110011", --  65:                   lsr ra
        45  => "10001111", --  67:                   ld rd, 0
        46  => "00000000", --  67:                   0
        47  => "00111100", --  68:                   and rd, ra
        48  => "10001111", --  69:                   ld rd, @shift_loop
        49  => "00101001", --  69:                   41
        50  => "11011111", --  70:                   bneq rd
        51  => "10000011", --  72:                   ld ra, 10
        52  => "00001010", --  72:                   10
        53  => "10000000", --  73:                   push ra
        54  => "10000000", --  74:                   push ra
        55  => "00001100", --  76:                   add rd, ra
        56  => "10001111", --  80:                   ld rd, @end_fib_loop2
        57  => "01000111", --  80:                   71
        58  => "11011100", --  81:                   bcs rd
        59  => "10000101", --  83:                   pop rb
        60  => "10000001", --  84:                   pop ra
        61  => "10000000", --  85:                   push ra
        62  => "10001001", --  86:                   pop rc
        63  => "00000001", --  88:                   add ra, rb
        64  => "10001111", --  89:                   ld rd, @io
        65  => "11111111", --  89:                   255
        66  => "10100011", --  90:                   str ra, [rd]
        67  => "10000000", --  92:                   push ra
        68  => "10001000", --  93:                   push rc
        69  => "11000000", --  95:                   jmp @fib_loop2
        70  => "00111000", --  95:                   56
        71  => "10001101", --  99:                   pop rd
        72  => "10001101", -- 100:                   pop rd
        73  => "10000011", -- 102:                   ld ra, @dec_init_value
        74  => "00001010", -- 102:                   10
        75  => "01110010", -- 103:                   lsl ra
        76  => "10001111", -- 104:                   ld rd, @io
        77  => "11111111", -- 104:                   255
        78  => "10001011", -- 105:                   ld rc, @end_dec_loop
        79  => "01010101", -- 105:                   85
        80  => "11001010", -- 109:                   bz rc
        81  => "10100011", -- 111:                   str ra, [rd]
        82  => "00100001", -- 112:                   dec ra
        83  => "11000000", -- 114:                   jmp @dec_loop
        84  => "01010000", -- 114:                   80
        85  => "11110000", -- 118:                   halt
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
