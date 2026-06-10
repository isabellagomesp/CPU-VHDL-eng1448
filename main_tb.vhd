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

    process
    begin
        -- RESET 
        RESET <= '1';
        wait for 20 ns;
        RESET <= '0';

        -- Cada instrução ALU de 1 byte passa por 4 bordas de subida:
        --   FETCH → DECODE_1 → EXECUTE → WRITE_BACK

        -- O que verificamos:
        --   • Em FETCH   (+1ns): current_ir deve mostrar o opcode correto
        --   • Em EXECUTE (+1ns): alu_leds deve mostrar as flags corretas

        -- alu_leds = flags_reg(4 downto 0)
        --   bit4 = CARRY  bit = EQUAL  bit2 = SMALLER  bit1 = GREATER  bit0 = ZERO

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

        wait;
    end process;

end Behavioral;