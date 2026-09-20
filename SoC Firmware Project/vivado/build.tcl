#=============================================================================
# Non-project batch build for the RV32I SoC on the MicroPhase A7-Lite.
#
#   vivado -mode batch -source vivado/build.tcl
#
# Run it from the "SoC Firmware Project" directory. Outputs land in vivado/build/.
#=============================================================================

# Safety interlock. While any top-level port lacks a PACKAGE_PIN, Vivado will
# happily auto-place it on an arbitrary ball -- including driven outputs, which
# can end up fighting something the board already drives. Analysis runs are
# still useful in that state, so the flow completes but refuses to emit a
# bitstream. Set this to 1 only if you have decided the auto-placement is safe.
set allow_unconstrained_bitstream 0

set part      "xc7a100tftg256-2"

# Top module. Pass "bringup" to build soc_top_bringup instead -- the same SoC
# but exposing only clk, rst and LED1, so nothing is left for Vivado to place
# on an arbitrary ball:
#   vivado -mode batch -source vivado/build.tcl -tclargs bringup
set top "soc_top"
if {[llength $argv] > 0 && [lindex $argv 0] eq "bringup"} {
    set top "soc_top_bringup"
}
puts "### building top: $top"
set root      [file normalize [file dirname [info script]]/..]
set build_dir "$root/vivado/build"

file mkdir $build_dir

# $readmemh in wb_bram.v resolves relative to Vivado's working directory, so
# stage the firmware image next to the build outputs and run from there.
file copy -force "$root/firmware/firmware.hex" "$build_dir/firmware.hex"
cd $build_dir

#-----------------------------------------------------------------------------
# Sources
#-----------------------------------------------------------------------------
read_verilog [list \
    "$root/rtl/core/rv32i_alu.v" \
    "$root/rtl/core/rv32i_core.v" \
    "$root/rtl/core/rv32i_decode.v" \
    "$root/rtl/core/rv32i_hazard.v" \
    "$root/rtl/core/rv32i_regfile.v" \
    "$root/rtl/bus/wb_interconnect.v" \
    "$root/rtl/peripherals/wb_bram.v" \
    "$root/rtl/peripherals/wb_gpio.v" \
    "$root/rtl/peripherals/wb_pwm.v" \
    "$root/rtl/peripherals/wb_timer.v" \
    "$root/rtl/peripherals/wb_uart.v" \
    "$root/rtl/top/soc_top.v" \
    "$root/rtl/top/soc_top_bringup.v" \
]

read_xdc [list "$root/vivado/a7lite.xdc"]

#-----------------------------------------------------------------------------
# Synthesis
#-----------------------------------------------------------------------------
synth_design -top $top -part $part
# UART lines are asynchronous to sys_clk. Applied here rather than in the XDC
# because XDC does not allow Tcl 'if', and soc_top_bringup has no UART ports.
if {[llength [get_ports -quiet uart_rx]]} { set_false_path -from [get_ports uart_rx] }
if {[llength [get_ports -quiet uart_tx]]} { set_false_path -to   [get_ports uart_tx] }

# Record which ports lack a PACKAGE_PIN. This MUST happen before
# place_design: with UCIO-1 downgraded, placement auto-assigns a pin to every
# port, so a check after routing would always come back clean.
set unconstrained {}
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq ""} {
        lappend unconstrained [get_property NAME $port]
    }
}
if {[llength $unconstrained] > 0} {
    puts "### [llength $unconstrained] unconstrained port(s): [lsort $unconstrained]"
}

write_checkpoint -force post_synth.dcp
report_utilization -file post_synth_util.rpt

# gpio_pins[7:2] and pwm_out are unconstrained until the header pins are
# chosen. Downgrade the "unconstrained I/O" check so bring-up builds complete;
# remove this line once every port has a PACKAGE_PIN.
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

#-----------------------------------------------------------------------------
# Implementation
#-----------------------------------------------------------------------------
opt_design
place_design
phys_opt_design
route_design

write_checkpoint -force post_route.dcp
report_timing_summary -file post_route_timing.rpt
report_utilization    -file post_route_util.rpt
report_drc            -file post_route_drc.rpt

#-----------------------------------------------------------------------------
# Bitstream
#-----------------------------------------------------------------------------
set wns [get_property SLACK [get_timing_paths -delay_type max]]

puts "\n================================================================"
puts "  Worst negative slack (setup): $wns ns"
if {$wns < 0} {
    puts "  *** TIMING NOT MET at 50 MHz ***"
}

if {[llength $unconstrained] > 0 && !$allow_unconstrained_bitstream} {
    puts ""
    puts "  NO BITSTREAM WRITTEN."
    puts "  [llength $unconstrained] port(s) have no PACKAGE_PIN and were"
    puts "  placed on arbitrary balls. Flashing that risks driving a pin the"
    puts "  board already drives. Fill these in vivado/a7lite.xdc:"
    foreach u [lsort $unconstrained] { puts "      $u" }
    puts ""
    puts "  Synthesis, placement, routing and timing above are all valid --"
    puts "  use them to check the design while you trace the remaining pins."
    puts "================================================================\n"
} else {
    write_bitstream -force $top.bit
    puts "  Bitstream: $build_dir/$top.bit"
    puts "================================================================\n"
}
