# Exports the hardware platform (XSA, including the bitstream) for Vitis/PetaLinux to output/.
# Needs a generated bitstream (see bitstream.tcl).
# Usage: vivado -mode batch -source scripts/export_xsa.tcl

source [file join [file dirname [info script]] settings.tcl]

open_kria_project
if {![run_done [get_runs impl_1] write_bitstream]} {
    error "No up to date bitstream, run 'make bit' first"
}
open_run impl_1
file mkdir $output_dir
write_hw_platform -fixed -include_bit -force -file [file join $output_dir $proj_name.xsa]
close_project
puts "Hardware platform written to [file join $output_dir $proj_name.xsa]"
