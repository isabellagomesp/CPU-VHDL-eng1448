library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
    port(
        CLK        : in  std_logic;
        RESET      : in  std_logic;
        current_ir : out std_logic_vector(7 downto 0);
        alu_leds   : out std_logic_vector(4 downto 0);
        POS_255    : out std_logic_vector(7 downto 0)
    );
end main;

architecture structural of main is

    -- fios de conexão entre CPU e RAM
    signal w_addr   : std_logic_vector(7 downto 0); -- leva o endereço de memória que a CPU quer acessar (MAR) até o pino ADDR da RAM
    signal w_cpu_to_ram : std_logic_vector(7 downto 0); -- leva o dado que a CPU quer escrever na RAM (MBR) até o pino DIN
    signal w_ram_to_cpu : std_logic_vector(7 downto 0); --  leva o dado que a RAM leu de volta para a CPU (pino DOUT → ram_din)
    signal w_we     : std_logic; -- leva o sinal de controle que diz se a operação é leitura ou escrita (Write Enable)

begin
    cpu_inst: entity work.CPU(Behavioral)
        port map(
            clk        => CLK,
            reset      => RESET,
            ram_addr   => w_addr,
            ram_din    => w_ram_to_cpu,
            ram_dout   => w_cpu_to_ram,
            ram_we     => w_we,
            current_ir => current_ir,
            alu_leds   => alu_leds
        );

    ram_inst: entity work.RAM_8x256(rtl)
        port map(
            CLK     => CLK,
            DIN     => w_cpu_to_ram,
            ADDR    => w_addr,
            WE      => w_we,
            DOUT    => w_ram_to_cpu,
            POS_255 => POS_255
        );

end structural;