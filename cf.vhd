---------------------------------------------------------------------
-- Clock e Reset
---------------------------------------------------------------------

NET "clk" LOC = "C9" | IOSTANDARD = LVCMOS33;

NET "clk" PERIOD = 20.0ns HIGH 40%; -- talvez mude

NET "reset" LOC = "V16" | IOSTANDARD = LVTTL | PULLDOWN ;

---------------------------------------------------------------------
-- Mapeamento dos LEDs
---------------------------------------------------------------------

NET "alu_leds<0>" LOC = "F12" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Zero
NET "alu_leds<1>" LOC = "E12" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Greater
NET "alu_leds<2>" LOC = "E11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Smaller
NET "alu_leds<3>" LOC = "F11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Equal
NET "alu_leds<4>" LOC = "C11" | IOSTANDARD = LVTTL | SLEW = SLOW | DRIVE = 8; # Carry

---------------------------------------------------------------------
-- Display LCD
---------------------------------------------------------------------

NET "lcd_rs" LOC = "L18" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_rw" LOC = "L17" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_e"  LOC = "M18" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;

NET "lcd_d<4>" LOC = "R15" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<5>" LOC = "R16" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<6>" LOC = "P17" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;
NET "lcd_d<7>" LOC = "M15" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;

NET "sf_ce0" LOC = "D16" | IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW;