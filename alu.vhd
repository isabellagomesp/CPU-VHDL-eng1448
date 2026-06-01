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
                temp := unsigned('0' & A) + unsigned('0' & B); -- '0'adiciona um bit extra na frente

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

            -- INC: A + 1 -> = opcode 0010
            when "0010" =>
                temp := unsigned('0' & A) + 1;
                
                --resultado 
                S <= STD_LOGIC_VECTOR(temp(7 downto 0));

                --carry
                C_OUT <= temp(8);

                if temp(7 downto 0) = 0 then -- operacao so depende de 1 opeando, entao unicas flags uteis sao:
                    FLAGS(0) <= '1'; -- zero
                end if;

                FLAGS(4) <= temp(8); -- carry

            --DEC: A - 1 -> opcode 0011
            when "0011" =>
                temp := unsigned('0' & A) - 1;
                
                --resultado 
                S <= STD_LOGIC_VECTOR(temp(7 downto 0));

                --carry
                C_OUT <= temp(8);

                if temp(7 downto 0) = 0 then -- operacao so depende de 1 opeando, entao unicas flags uteis sao:
                    FLAGS(0) <= '1';  -- zero
                end if;

                FLAGS(4) <= temp(8); -- carry
        
        -- operadores bit a bit -> não usa 9 bits -> não usa temp -> não tem carry
        -- não comparamos valores então greater, smaller e equal não fazem sentido
            -- AND = opcode 0100
            when "0100" =>
                S <= A and B;

                if (A and B) = x"00" then -- se a operacao foi zero -> x00 = 00000000
                    FLAGS(0) <= '1';
                end if;

            -- OR = opcode 0101
            when "0101" =>
                S <= A or B;

                if (A or B) = x"00" then -- se a operacao foi zero -> x00 = 00000000
                    FLAGS(0) <= '1';
                end if;

            -- not = opcode 0110
            when "0110" =>
                S <= not A;

                if (not A) = x"00" then -- se a operacao foi zero -> x00 = 00000000
                    FLAGS(0) <= '1';
                end if;

            -- XOR = opcode 0111
            when "0111" =>
                S <= A xor B;

                if (A xor B) = x"00" then -- se a operacao foi zero -> x00 = 00000000
                    FLAGS(0) <= '1';
                end if;
				
			-- ROL = opcode 1000 -> rotate left
			when "1000" => 
				S <= A(6 downto 0) & A(7); -- bit da esquerda gira para a direita
				
				if (A(6 downto 0) & A(7)) = x"00" then
					FLAGS(0) <= '1';
				end if;
				
			-- ROT = opcode 1001 -> rotate right 
			when "1001" => 
				S <= A(7) & A(7 downto 1); -- bit da direita gira para a esquera
				
				if (A(7) & A(7 downto 1)) = x"00" then
					FLAGS(0) <= '1';
				end if;
				
			-- LSL = opcode 1010 -> logical shift left
			when "1010" => 
				S <= A(6 downto 0) & '0'; -- bit mais a esquerda sai e entra o 0
				
				if (A(6 downto 0) & '0') = x"00" then
					FLAGS(0) <= '1';
				end if;
				
				FLAGS(4) <= A(7); -- bit que saiu vira carry
				
			-- LSR = opcode 1011 -> logical shift right 
			when "1011" => 
				S <= '0' & A(7 downto 1); --bit mais a direita sai e entra o 0
				
				if ('0' & A(7 downto 1)) = x"00" then
					FLAGS(0) <= '1';
				end if;
				
				FLAGS(4) <= A(0);

            when others => null;
        end case;
    end process;
	
end Behavioral; 



                
                



