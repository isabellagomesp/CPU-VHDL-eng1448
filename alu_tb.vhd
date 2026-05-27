library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_tb is
end alu_tb;

architecture Behavioral of alu_tb is

    signal A : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal B : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal CMD : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal C_in : STD_LOGIC := '0';
    signal C_out : STD_LOGIC;
    signal FLAGS : STD_LOGIC_VECTOR(4 downto 0);
    signal S : STD_LOGIC_VECTOR(7 downto 0);

begin

    uut: entity work.alu(Behavioral)
        port map ( A => A,
                   B => B,
                   CMD => CMD,
                   C_in => C_in,
                   C_out => C_out,
                   FLAGS => FLAGS,
                   S => S);
    process
    begin
        -- Teste 1: 3 + 5 = 8
        A <= x"03";
        B <= x"05";
        CMD <= "0000";
        wait for 10 ns;

        -- Teste 2: 255 + 1 = 0 com carry
        A <= x"FF";
        B <= x"01";
        CMD <= "0000";
        wait for 10 ns;

        -- Teste 3: 10 + 20 = 30
        A <= x"0A";
        B <= x"14";
        CMD <= "0000";
        wait for 10 ns;

        -- Teste 4: 10 - 3 = 7
        A <= x"0A";
        B <= x"03";
        CMD <= "0001";
        wait for 10 ns;

        -- Teste 5: 5 - 5 = 0
        A <= x"05";
        B <= x"05";
        CMD <= "0001";
        wait for 10 ns;

        -- Teste 6: 3 - 5 = 254 com underflow
        A <= x"03";
        B <= x"05";
        CMD <= "0001";
        wait for 10 ns;

        -- Teste 7: INC 10 = 11
        A <= x"0A";
        B <= x"00";
        CMD <= "0010";
        wait for 10 ns;

        -- Teste 8: INC 255 = 0 com carry
        A <= x"FF";
        B <= x"00";
        CMD <= "0010";
        wait for 10 ns;

        -- Teste 9: DEC 10 = 9
        A <= x"0A";
        B <= x"00";
        CMD <= "0011";
        wait for 10 ns;

        -- Teste 10: DEC 0 = 255 com underflow
        A <= x"00";
        B <= x"00";
        CMD <= "0011";
        wait for 10 ns;

        wait;
    end process;

end Behavioral;