---------------------------------------------------------------------
-- Arquivo de Constraints (UCF)
-- Placa: Nexys2 / Spartan-3E 500K
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Clock e Reset
---------------------------------------------------------------------
NET "CLK"   LOC = "C9"  | IOSTANDARD = LVCMOS33;
NET "CLK"   PERIOD = 20.0ns HIGH 40%;

NET "RESET" LOC = "V16" | IOSTANDARD = LVTTL | PULLDOWN;

---------------------------------------------------------------------
-- LEDs da ALU (flags: Zero, Greater, Smaller, Equal, Carry)
---------------------------------------------------------------------
NET "alu_leds<0>" LOC = "F12" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Zero
NET "alu_leds<1>" LOC = "E12" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Greater
NET "alu_leds<2>" LOC = "E11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Smaller
NET "alu_leds<3>" LOC = "F11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Equal
NET "alu_leds<4>" LOC = "C11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Carry

---------------------------------------------------------------------
-- Display LCD HD44780 (modo 4 bits: D4-D7)
-- lcd_d<0> -> pino D4 do LCD
-- lcd_d<3> -> pino D7 do LCD
---------------------------------------------------------------------
NET "lcd_rs"  LOC = "L18" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_rw"  LOC = "L17" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_e"   LOC = "M18" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;

NET "lcd_d<0>" LOC = "R15" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<1>" LOC = "R16" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<2>" LOC = "P17" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<3>" LOC = "M15" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;

NET "sf_ce0"  LOC = "D16" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
