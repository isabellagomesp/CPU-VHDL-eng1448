library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main_tb is
end main_tb;

architecture Behavioral of main_tb is

    signal CLK        : std_logic := '0';
    signal RESET      : std_logic := '1';
    signal current_ir : std_logic_vector(7 downto 0);
    signal alu_leds   : std_logic_vector(4 downto 0);
    signal POS_255    : std_logic_vector(7 downto 0);

begin

    uut: entity work.main(structural)
        port map(
            CLK        => CLK,
            RESET      => RESET,
            current_ir => current_ir,
            alu_leds   => alu_leds,
            POS_255    => POS_255
        );

    -- Clock de 10 ns (borda de subida em 5, 15, 25, ...)
    CLK <= not CLK after 5 ns;

    -- Legenda dos sinais observáveis:
    --   current_ir : opcode da instrução em execução (carregado no FETCH)
    --   alu_leds   : flags_reg(4 downto 0) = CARRY | EQUAL | SMALLER | GREATER | ZERO

    -- Número de ciclos por tipo de instrução:
    --   ALU / MOV / LDR (1 byte): 4 ciclos  FETCH→D1→EXECUTE→WRITE_BACK
    --   LD  #imm        (2 bytes): 5 ciclos  FETCH→D1→D2→EXECUTE→WRITE_BACK
    --   ST  addr        (2 bytes): 4 ciclos  FETCH→D1→D2→EXECUTE
    --   JMP 0x--        (2 bytes): 4 ciclos  FETCH→D1→D2→EXECUTE
    --   branch          (1 byte) : 3 ciclos  FETCH→D1→EXECUTE  (sem WRITE_BACK)

    process
    begin
        RESET <= '1';
        wait for 20 ns;
        RESET <= '0';

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 1 — Instruções ALU (endereços 0–13)
        -- Estado ao final: A=0x7F, B=1
        -- ════════════════════════════════════════════════════════════

        -- Instrução 0: inc A   opcode 0x20
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  (A: 0 → 1)
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 1: inc A   opcode 0x20
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  (A: 1 → 2)
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 2: inc B   opcode 0x24
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  (B: 0 → 1)
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 3: add A,B   opcode 0x01
        -- A=2, B=1 → A=3, GREATER=1 → flags="00010"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=3)

        -- Instrução 4: sub A,B   opcode 0x11
        -- A=3, B=1 → A=2
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=2)

        -- Instrução 5: dec A   opcode 0x21
        -- A=2 → A=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=1)

        -- Instrução 6: and A,B   opcode 0x31
        -- A=1, B=1 → A=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 7: or A,B   opcode 0x41
        -- A=1, B=1 → A=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 8: xor A,B   opcode 0x61
        -- A=1, B=1 → A=0, ZERO=1 → flags="00001"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=0)

        -- Instrução 9: not A   opcode 0x50
        -- A=0 → A=0xFF
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=0xFF)

        -- Instrução 10: rol A   opcode 0x70
        -- A=0xFF → A=0xFF (todos 1s, rotação não muda)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 11: ror A   opcode 0x71
        -- A=0xFF → A=0xFF
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK

        -- Instrução 12: lsl A   opcode 0x72
        -- A=0xFF → A=0xFE, CARRY=1 → flags="10000"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=0xFE)

        -- Instrução 13: lsr A   opcode 0x73
        -- A=0xFE → A=0x7F, CARRY=0 → flags="00000"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags
        wait until rising_edge(CLK);                 -- WRITE_BACK (A=0x7F)

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 2 — Instruções de memória (endereços 14–27)
        -- Estado inicial: A=0x7F, B=1
        -- Estado ao final: A=42, B=42, C=42, D=0x41,
        --                  RAM[0x40]=42, RAM[0x41]=42, SP=0xFE
        -- ════════════════════════════════════════════════════════════

        -- Instrução 14+15: LD A, #42   opcode 0x83
        -- 5 ciclos -> A=42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=42
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=42

        -- Instrução 16+17: ST A, 0x40   opcode 0x82
        -- 4 ciclos -> RAM[0x40]=42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x82
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MAR=0x40, MBR=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1

        -- Instrução 18: inc A   opcode 0x20
        -- 4 ciclos -> A=43
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x20
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=43

        -- Instrução 19+20: LD B, #0x40   opcode 0x87
        -- 5 ciclos -> B=0x40
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x40
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=0x40

        -- Instrução 21: LDR A, [B]   opcode 0x91
        -- 4 ciclos -> A=RAM[0x40]=42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x91
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=REG[B]=0x40
        wait until rising_edge(CLK);                 -- EXECUTE  : RAM lê 0x40
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=42

        -- Instrução 22: MOV C, A   opcode 0xB8
        -- 4 ciclos -> C=42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xB8
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: C=42

        -- Instrução 23+24: LD D, #0x41   opcode 0x8F
        -- 5 ciclos -> D=0x41
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x41
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=0x41

        -- Instrução 25: STR C, [D]   opcode 0xAB
        -- 3 ciclos -> RAM[0x41]=42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xAB
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=REG[D]=0x41, MBR=REG[C]=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1

        -- Instrução 26: PUSH C   opcode 0x88
        -- 3 ciclos -> RAM[0xFE]=42, SP=0xFD
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x88
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=SP=0xFE, MBR=REG[C]=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1, SP=0xFD

        -- Instrução 27: POP B   opcode 0x85
        -- 4 ciclos -> B=42, SP=0xFE
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x85
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=SP+1=0xFE
        wait until rising_edge(CLK);                 -- EXECUTE  : SP=0xFE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=42

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 3 — Instruções de salto (endereços 28–59)
        -- Estado inicial: A=42, B=42, C=42
        -- Estado ao final: A=0, D=57, flags="01001" (EQUAL+ZERO)
        -- ════════════════════════════════════════════════════════════

        -- Instrução 28+29: JMP 0x33 (=51)   opcode 0xC0
        -- 4 ciclos -> PC=51, pula TRAP em 30 e vão 31-50
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xC0
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x33 (=51)
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=51

        -- Instrução 51+52: LD D, #57   opcode 0x8F
        -- 5 ciclos -> D=57 (alvo dos branches)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=57
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=57

        -- Instrução 53: sub A,B   opcode 0x11
        -- 4 ciclos -> A=42-42=0, ZERO=1, EQUAL=1 → flags="01001"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (ZERO=1, EQUAL=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0

        -- Instrução 54: BZ D (TOMADO)   opcode 0xCE
        -- 3 ciclos -> ZERO=1 -> PC=57, pula TRAPs em 55 e 56
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xCE
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=57

        -- Instrução 57: BNZ D (NAO TOMADO)   opcode 0xCF
        -- 3 ciclos -> ZERO=1 -> condição falsa -> cai p/ 58
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xCF
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : MAR=58

        -- Instrução 58+59: JMP 0x80   opcode 0xC0
        -- 4 ciclos -> PC=128 (salta para o Bloco 4)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xC0
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x80 (=128)
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=128

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 4 — BCS, BCC, BEQ, BNEQ, BGT, BLT (endereços 128–180)
        -- Estado inicial: A=0, B=42, flags="01001" (EQUAL+ZERO)
        -- ════════════════════════════════════════════════════════════

        -- Instrução 128+129: LD A, #0xFF
        -- 5 ciclos -> A=0xFF
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0xFF
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0xFF

        -- Instrução 130+131: LD B, #1
        -- 5 ciclos -> B=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=1

        -- Instrução 132: add A,B
        -- 4 ciclos -> A=0x00, CARRY=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x01
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (CARRY=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0

        -- Instrução 133+134: LD D, #137
        -- 5 ciclos -> D=137
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=137
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=137

        -- Instrução 135: BCS D (TOMADO)
        -- 3 ciclos -> CARRY=1 -> PC=137, pula trap 136
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xDC
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=137

        -- Instrução 137+138: LD B, #1
        -- 5 ciclos -> B=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=1

        -- Instrução 139: add A,B
        -- 4 ciclos -> A=1, CARRY=0  (A=0+B=1)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x01
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (CARRY=0)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=1

        -- Instrução 140+141: LD D, #144
        -- 5 ciclos -> D=144
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=144
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=144

        -- Instrução 142: BCC D (TOMADO)
        -- 3 ciclos -> CARRY=0 -> PC=144, pula trap 143
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xDD
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=144

        -- Instrução 144+145: LD A, #5
        -- 5 ciclos -> A=5
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=5
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=5

        -- Instrução 146+147: LD B, #5
        -- 5 ciclos -> B=5
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=5
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=5

        -- Instrução 148: sub A,B
        -- 4 ciclos -> A=0, EQUAL=1, ZERO=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (EQUAL=1, ZERO=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0

        -- Instrução 149+150: LD D, #153
        -- 5 ciclos -> D=153
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=153
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=153

        -- Instrução 151: BEQ D (TOMADO)
        -- 3 ciclos -> EQUAL=1 -> PC=153, pula trap 152
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xDE
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=153

        -- Instrução 153+154: LD A, #7
        -- 5 ciclos -> A=7
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=7
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=7

        -- Instrução 155+156: LD B, #3
        -- 5 ciclos -> B=3
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=3
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=3

        -- Instrução 157: sub A,B
        -- 4 ciclos -> A=4, EQUAL=0, GREATER=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (EQUAL=0, GREATER=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=4

        -- Instrução 158+159: LD D, #162
        -- 5 ciclos -> D=162
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=162
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=162

        -- Instrução 160: BNEQ D (TOMADO)
        -- 3 ciclos -> EQUAL=0 -> PC=162, pula trap 161
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xDF
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=162

        -- Instrução 162+163: LD A, #9
        -- 5 ciclos -> A=9
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=9
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=9

        -- Instrução 164+165: LD B, #2
        -- 5 ciclos -> B=2
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=2
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=2

        -- Instrução 166: sub A,B
        -- 4 ciclos -> A=7, GREATER=1, SMALLER=0
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (GREATER=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=7

        -- Instrução 167+168: LD D, #171
        -- 5 ciclos -> D=171
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=171
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=171

        -- Instrução 169: BGT D (TOMADO)
        -- 3 ciclos -> GREATER=1 -> PC=171, pula trap 170
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xEC
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=171

        -- Instrução 171+172: LD A, #2
        -- 5 ciclos -> A=2
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=2
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=2

        -- Instrução 173+174: LD B, #9
        -- 5 ciclos -> B=9
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=9
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=9

        -- Instrução 175: sub A,B
        -- 4 ciclos -> A=0xF9, SMALLER=1, GREATER=0
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags (SMALLER=1)
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0xF9

        -- Instrução 176+177: LD D, #180
        -- 5 ciclos -> D=180
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=180
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=180

        -- Instrução 178: BLT D (TOMADO)
        -- 3 ciclos -> SMALLER=1 -> PC=180, pula trap 179
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xED
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=180

        -- Instrução 180: HALT   opcode 0xF0
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xF0 (trava aqui)

        wait;
    end process;

end Behavioral;
