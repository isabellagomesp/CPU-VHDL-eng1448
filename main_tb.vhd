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
    --   branch / JMPR   (1 byte) : 3 ciclos  FETCH→D1→EXECUTE  (sem WRITE_BACK)

    process
    begin
        RESET <= '1';
        wait for 20 ns;
        RESET <= '0';

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 1 — Instruções ALU (endereços 0–13)
        -- ════════════════════════════════════════════════════════════

        -- Instrução 0: inc A 
        -- opcode 0010 00 00 = 0x20
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE  (A: 0 → 1)
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- Instrução 1: inc A 
        -- opcode 0010 00 00 = 0x20
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE  (A: 1 → 2)
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 2: inc B 
        -- opcode 0010 01 00 = 0x24
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE  (B: 0 → 1)
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 3: add A,B 
        -- opcode 0000 00 01 = 0x01
        -- A=2, B=1 → resultado=3, GREATER=1 → flags="00010"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags 
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 3)

        -- ── Instrução 4: sub A,B 
        -- opcode 0001 00 01 = 0x11
        -- A=3, B=1 → resultado=2
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 2)

        -- ── Instrução 5: dec A 
        -- opcode 0010 00 01 = 0x21
        -- A=2 → resultado=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 1)

        -- ── Instrução 6: and A,B 
        -- opcode 0011 00 01 = 0x31
        -- A=1, B=1 → resultado=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 7: or A,B 
        -- opcode 0100 00 01 = 0x41
        -- A=1, B=1 → resultado=1
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 8: xor A,B 
        -- opcode 0110 00 01 = 0x61
        -- A=1, B=1 → resultado=0 → ZERO=1 → flags="00001"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags 
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 0)

        -- ── Instrução 9: not A 
        -- opcode 0101 00 00 = 0x50
        -- A=0 → resultado=0xFF
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 0xFF)

        -- ── Instrução 10: rol A 
        -- opcode 0111 00 00 = 0x70
        -- A=0xFF → rol → A=0xFF (todos os bits são 1, rodar não muda nada)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 11: ror A 
        -- opcode 0111 00 01 = 0x71
        -- A=0xFF → ror → A=0xFF
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK);  -- EXECUTE
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ── Instrução 12: lsl A 
        -- opcode 0111 00 10 = 0x72
        -- A=0xFF=11111111 → lsl → 0xFE=11111110, bit7=1 sai como CARRY
        -- flags: CARRY=1 → "10000"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags 
        wait until rising_edge(CLK);  -- WRITE_BACK  (A vira 0xFE)

        -- ── Instrução 13: lsr A 
        -- opcode 0111 00 11 = 0x73
        -- A=0xFE=11111110 → lsr → 0x7F=01111111, bit0=0 sai como CARRY=0
        -- flags: todas zeradas → "00000"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH
        wait until rising_edge(CLK);  -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE: flags 
        wait until rising_edge(CLK);  -- WRITE_BACK

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 2 — Instruções de memória (endereços 14–26)
        -- Estado inicial:  A=0x7F, B=1
        -- Estado ao final: A=42, B=42, C=42, D=0x41,
        --                  RAM[0x40]=42, RAM[0x41]=42, SP=0xFE
        -- ════════════════════════════════════════════════════════════

        -- ── Instrução 14+15: LD A, #42
        -- opcode 1000 00 11 = 0x83   | byte 2 = 0x2A (imediato)
        -- 5 ciclos -> A = 42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x83
        wait until rising_edge(CLK);                 -- DECODE_1 : busca imm (0x2A)
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=42
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=42

        -- ── Instrução 16+17: ST A, 0x40   (store imediato)
        -- opcode 1000 00 10 = 0x82   | byte 2 = 0x40 (endereço)
        -- 4 ciclos -> RAM[0x40] = 42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x82
        wait until rising_edge(CLK);                 -- DECODE_1 : busca addr (0x40)
        wait until rising_edge(CLK);                 -- DECODE_2 : MAR=0x40, MBR=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1

        -- ── Instrução 18+19: LD B, #0x40
        -- opcode 1000 01 11 = 0x87   | byte 2 = 0x40 (imediato)
        -- 5 ciclos -> B = 0x40
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x87
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x40
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=0x40

        -- ── Instrução 20: LDR A, [B]   (load indireto)
        -- opcode 1001 00 01 = 0x91
        -- 4 ciclos -> A = RAM[B=0x40] = 42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x91
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=REG[B]=0x40
        wait until rising_edge(CLK);                 -- EXECUTE  : RAM lê 0x40
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=42

        -- ── Instrução 21: MOV C, A
        -- opcode 1011 10 00 = 0xB8
        -- 4 ciclos -> C = A = 42
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xB8
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: C=42

        -- ── Instrução 22+23: LD D, #0x41
        -- opcode 1000 11 11 = 0x8F   | byte 2 = 0x41 (imediato)
        -- 5 ciclos -> D = 0x41 (endereço usado pelo STR)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x41
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=0x41

        -- ── Instrução 24: STR C, [D]   (store indireto)
        -- opcode 1010 10 11 = 0xAB
        -- 3 ciclos -> RAM[D=0x41] = C = 42   (sem WRITE_BACK)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xAB
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=REG[D]=0x41, MBR=REG[C]=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1

        -- ── Instrução 25: PUSH C   (empilha)
        -- opcode 1000 10 00 = 0x88
        -- 3 ciclos -> RAM[SP=0xFE]=42, SP=0xFD   (sem WRITE_BACK)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x88
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=SP=0xFE, MBR=REG[C]=42
        wait until rising_edge(CLK);                 -- EXECUTE  : ram_we=1, SP=0xFD

        -- ── Instrução 26: POP B   (desempilha)
        -- opcode 1000 01 01 = 0x85
        -- 4 ciclos -> B = RAM[SP+1=0xFE] = 42, SP=0xFE
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x85
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=SP+1=0xFE
        wait until rising_edge(CLK);                 -- EXECUTE  : SP=0xFE
        wait until rising_edge(CLK);                 -- WRITE_BACK: B=42

        -- ════════════════════════════════════════════════════════════
        -- BLOCO 3 — Instruções de salto (endereços 27–37)
        -- Estado inicial:  A=42, B=42, C=42
        -- Estado ao final: A=0, B=42, C=42, D=36, flags="01001" (EQUAL+ZERO)
        -- ════════════════════════════════════════════════════════════
        -- Ciclos por tipo de salto:
        --   JMP 0x-- (2 bytes)        : 4 ciclos  FETCH→D1→D2→EXECUTE
        --   branch tomado/não tomado  : 3 ciclos  FETCH→D1→EXECUTE  (sem WRITE_BACK)

        -- ── Instrução 27+28: JMP 0x1E   (salto incondicional)
        -- opcode 1100 0000 = 0xC0   | byte 2 = 0x1E (alvo = 30)
        -- 4 ciclos -> PC=30, pula o TRAP (dec A) em 29
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xC0
        wait until rising_edge(CLK);                 -- DECODE_1 : MAR=PC (busca alvo)
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x1E (=30)
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=30, MAR=30

        -- ── Instrução 30+31: LD D, #36
        -- opcode 1000 11 11 = 0x8F   | byte 2 = 0x24 (=36)
        -- 5 ciclos -> D=36 (alvo dos branches)
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x8F
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- DECODE_2 : MBR=0x24
        wait until rising_edge(CLK);                 -- EXECUTE
        wait until rising_edge(CLK);                 -- WRITE_BACK: D=36

        -- ── Instrução 32: sub A,B
        -- opcode 0001 00 01 = 0x11
        -- 4 ciclos -> A=42-42=0 -> ZERO=1, EQUAL=1 -> flags="01001"
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0x11
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK); wait for 1 ns;  -- EXECUTE  : flags
        wait until rising_edge(CLK);                 -- WRITE_BACK: A=0

        -- ── Instrução 33: BZ D   (TOMADO)
        -- opcode 1100 11 10 = 0xCE
        -- 3 ciclos -> ZERO=1 -> PC=REG[D]=36, pula os TRAPs (inc B) em 34 e 35
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xCE
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : PC=36, MAR=36

        -- ── Instrução 36: BNZ D   (NÃO tomado)
        -- opcode 1100 11 11 = 0xCF
        -- 3 ciclos -> ZERO=1 -> condição falsa -> segue para o HALT em 37
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xCF
        wait until rising_edge(CLK);                 -- DECODE_1
        wait until rising_edge(CLK);                 -- EXECUTE  : MAR=PC (=37)

        -- ── Instrução 37: HALT
        -- opcode 1111 0000 = 0xF0
        wait until rising_edge(CLK); wait for 1 ns;  -- FETCH    : current_ir=0xF0 (trava aqui)

        wait;
    end process;

end Behavioral;
