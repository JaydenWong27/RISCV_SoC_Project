#=============================================================================
# Download the bitstream to the A7-Lite over JTAG (volatile -- lost on power
# cycle). Run after build.tcl:
#
#   vivado -mode batch -source vivado/program.tcl
#=============================================================================

set root [file normalize [file dirname [info script]]/..]
set bit  "$root/vivado/build/soc_top.bit"

if {![file exists $bit]} {
    error "Bitstream not found at $bit -- run vivado/build.tcl first."
}

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "\nProgrammed [get_property PART $dev] with $bit\n"

close_hw_target
disconnect_hw_server
close_hw_manager
