-- Testar apenas as intruções lógicas e aritmeticas da tabela: 
-- add      sub     inc     dec
-- and      or      not     xor
-- rol      ror     lsl     lsr

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is 
    port( A : in STD_LOGIC_VECTOR(7 downto 0); -- operando A
          B : in STD_LOGIC_VECTOR(7 downto 0); -- operando B
          CMD : in STD_LOGIC_VECTOR(3 downto 0); -- qual operacao fazer
          C_IN : in STD_LOGIC; -- carry de entrada
          C_OUT : out STD_LOGIC; -- carry/overflow
          FLAGS : out STD_LOGIC_VECTOR(4 downto 0); -- flags de operacao 
          S : out STD_LOGIC_VECTOR(7 downto 0)); -- resultado
end alu;

architecture Behavioral of alu is 
begin
    process(A, B, CMD) -- sempre que A, B ou CMD mudarem a alu recalcula a saída
        variable temp : unsigned(8 downto 0); -- a soma é de 8 bits mas pode gerar um carry -> 9 bits
    
    begin
        S <= (others => '0');
        C_OUT <= '0';
        FLAGS <= (others => '0');

        case CMD is
             
            -- ADD = opcode 0000
            when "0000" =>
                --soma com 9 bits para detectar o carry 
                temp := unsigned('0'& A) + unsigned('0' & B); -- '0'adiciona um bit extra na frente

                --resultado
                S <= STD_LOGIC_VECTOR(temp(7 downto 0)); -- pega os 8 bits inferiores

                --carry
                C_OUT <= temp(8);

                --Flags
                --flags(0) -> ZERO
                if temp(7 downto 0) = 0 then 
                    FLAGS(0) <= '1';
                end if;

                --flags(1) -> GREATER
                if unsigned(A) > unsigned(B) then 
                    FLAGS(1) <= '1';
                end if;

                --flags(2) -> SMALLER
                if unsigned(A) < unsigned(B) then 
                    FLAGS(2) <= '1';
                end if;

                --flags(3) -> EQUAL
                if unsigned(A) = unsigned(B) then 
                    FLAGS(3) <= '1';
                end if;

                -- CARRY 
                FLAGS(4) <= temp(8);

            -- SUB = opcode 0001
            when "0001"=>

                --subtração com 9 bits para detectar carry
                temp := unsigned('0' & A) - unsigned('0' & B);

                -- resultado 
                S <= STD_LOGIC_VECTOR(temp(7 downto 0));

                --carry
                C_OUT <= temp(8);

                --Flags
                --flags(0) -> ZERO
                if temp(7 downto 0) = 0 then 
                    FLAGS(0) <= '1';
                end if;

                --flags(1) -> GREATER
                if unsigned(A) > unsigned(B) then 
                    FLAGS(1) <= '1';
                end if;

                --flags(2) -> SMALLER
                if unsigned(A) < unsigned(B) then 
                    FLAGS(2) <= '1';
                end if;

                --flags(3) -> EQUAL
                if unsigned(A) = unsigned(B) then 
                    FLAGS(3) <= '1';
                end if;

                -- CARRY 
                FLAGS(4) <= temp(8);

            when others => null;
        end case;
    end process;
end Behavioral; 



                
                


