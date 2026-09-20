#=============================================================================
# MicroPhase A7-Lite  --  AMD/Xilinx Artix-7 XC7A100T-2FTG256
# Constraints for soc_top / soc_top_bringup
#=============================================================================
#
# PIN STATUS
#   VERIFIED on this board:  clk = N11, rst (KEY1) = T13, LED1 = P11
#   TODO:                    uart_tx, uart_rx, LED2, pwm_out
#
#-----------------------------------------------------------------------------
# Note on A7-LITE_R11.pdf
#
# The board schematic PDF and MicroPhase's online manual both describe the
# FGG484 variant (device symbol XC7A35T-2FGG484I; CLK_50M=J19, LED1=M18,
# LED2=N18, KEY1=AA1, KEY2=W1, UART_TX=V2, UART_RX=U2). Those ball names use
# columns up to 22 and do not exist on FTG256, which is a 16x16 grid: rows A-T
# (no I, O or Q), columns 1-16. That documentation does not apply to this chip
# and none of its pins are used here.
#
# Because pin FUNCTION is per-package, the FGG484 roles of N11/T13/P11 say
# nothing about their roles on FTG256. Vivado validates the three pins below
# against xc7a100tftg256-2 and will error if any is not a user I/O there.
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Clock -- 50 MHz on-board oscillator                               [VERIFIED]
#-----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN N11 IOSTANDARD LVCMOS33} [get_ports clk]

create_clock -name sys_clk -period 20.000 [get_ports clk]

# If placement reports "clock net driven by a non-clock-capable pin", N11 is
# not MRCC/SRCC on this package. Check with:
#   create_project -in_memory -part xc7a100tftg256-2
#   get_property PIN_FUNC [get_package_pins N11]
# and list every clock-capable ball with:
#   foreach p [lsort [get_package_pins]] {
#       set f [get_property PIN_FUNC $p]
#       if {[string match *RCC* $f]} { puts "$p $f" }
#   }

#-----------------------------------------------------------------------------
# Reset -- KEY1, active-low push button                            [VERIFIED]
#-----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst]

# Asynchronous to sys_clk; soc_top synchronizes it with a 2-FF chain.
set_false_path -from [get_ports rst]

#-----------------------------------------------------------------------------
# GPIO -- bit 0 drives LED1                                        [VERIFIED]
#
# soc_top instantiates wb_gpio with ACTIVE_LOW_MASK(8'h00), i.e. LEDs assumed
# active-high. If LED1 lights inverted on hardware, change that mask to 8'h03.
#-----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN P11 IOSTANDARD LVCMOS33} [get_ports {gpio_pins[0]}]

# TODO: LED2 -- trace it, then uncomment.
# set_property -dict {PACKAGE_PIN <TODO_LED2> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[1]}]

# TODO: expansion-header GPIO, if you want any brought out.
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[2]}]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[3]}]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[4]}]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[5]}]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[6]}]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD LVCMOS33} [get_ports {gpio_pins[7]}]

#-----------------------------------------------------------------------------
# UART -- 115200 8N1                                                    [TODO]
#
# The board carries a CH340E USB-UART bridge, so once these two balls are
# traced the USB port gives you a serial console with no extra hardware.
#-----------------------------------------------------------------------------
# set_property -dict {PACKAGE_PIN <TODO_UART_TX> IOSTANDARD LVCMOS33} [get_ports uart_tx]
# set_property -dict {PACKAGE_PIN <TODO_UART_RX> IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_rx]

#-----------------------------------------------------------------------------
# PWM output                                                            [TODO]
#-----------------------------------------------------------------------------
# set_property -dict {PACKAGE_PIN <TODO_PWM> IOSTANDARD LVCMOS33} [get_ports pwm_out]

#-----------------------------------------------------------------------------
# NOTE: the UART async false-paths are applied in vivado/build.tcl, not here.
# XDC files do not support Tcl 'if' (Vivado raises "Command 'if' is not
# supported in the xdc constraint file"), and the constraint must be skipped
# for the soc_top_bringup top, which has no UART ports.
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Configuration
#-----------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Leave genuinely unused balls floating rather than weakly driven.
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]

# Uncomment to generate a .bin for programming the on-board QSPI flash.
# set_property CONFIG_MODE SPIx4 [current_design]
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
# set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
