library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RAM_8x256_tb is
end RAM_8x256_tb;

architecture Behavioral of RAM_8x256_tb is

    signal CLK     : std_logic := '0';
    signal DIN     : std_logic_vector(7 downto 0) := (others => '0');
    signal ADDR    : std_logic_vector(7 downto 0) := (others => '0');
    signal WE      : std_logic := '0';
    signal DOUT    : std_logic_vector(7 downto 0);
    signal POS_255 : std_logic_vector(7 downto 0);

begin

    uut: entity work.RAM_8x256(rtl)
        port map (
            CLK     => CLK,
            DIN     => DIN,
            ADDR    => ADDR,
            WE      => WE,
            DOUT    => DOUT,
            POS_255 => POS_255
        );

    -- Clock de 10 ns (falling_edge em 5 ns, 15 ns, 25 ns, ...)
    CLK <= not CLK after 5 ns;

    process
    begin

        -- POS_255 é combinacional (ram(255)), já vale AA antes do primeiro clock
        wait for 2 ns;
        assert POS_255 = x"AA"
            report "Erro: POS_255 deveria ser AA na inicializacao"
            severity error;

        -- Ler posição 0 
        ADDR <= x"00";
        WE   <= '0';
        wait until falling_edge(CLK);  -- registra read_address <= 0x00
        wait for 1 ns;                 -- aguarda DOUT atualizar combinacionalmente

        -- Ler posição 1 => esperado 0x34
        ADDR <= x"01";
        wait until falling_edge(CLK);
        wait for 1 ns;

        -- Ler posição 2 => esperado 0x56
        ADDR <= x"02";
        wait until falling_edge(CLK);
        wait for 1 ns;
        assert DOUT = x"56"
            report "Erro: RAM[12] deveria ser 56"
            severity error;

        -- Ler posição vazia => esperado 0x00
        ADDR <= x"05";
        wait until falling_edge(CLK);
        wait for 1 ns;

        -- Escrever 0xCC na posição 10 (0x0A)
        ADDR <= x"0A";
        DIN  <= x"CC";
        WE   <= '1';
        wait until falling_edge(CLK);  -- escrita ocorre aqui
        wait for 1 ns;
        WE <= '0';

        -- Ler posição 10 => deve retornar 0xCC 
        ADDR <= x"0A";
        wait until falling_edge(CLK);
        wait for 1 ns;

        -- Escrever 55 na posição 255 (I/O) — RAM permite; POS_255 deve atualizar
        ADDR <= x"FF";
        DIN  <= x"55";
        WE   <= '1';
        wait until falling_edge(CLK);  -- escrita ocorre aqui; POS_255 atualiza 
        wait for 1 ns;
        WE <= '0';

        wait;
    end process;

end Behavioral;


-- deve aparecer na simulacao
-- ADDR   00    01    02    0A
-- DOUT   12    34    56    CC
-- WE      0     0     0     1
-- DIN     -     -     -     CC
-- POS_255 deve começar em AA e quando escrever deve mudar para 55