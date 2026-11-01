# Writes the bitstream (.bit and .bin) to output/, running synthesis and implementation first if
# they are out of date.
# Usage: vivado -mode batch -source scripts/bitstream.tcl

source [file join [file dirname [info script]] settings.tcl]

open_kria_project
run_to synth_1 synth_design
run_to impl_1 write_bitstream

set run_dir [get_property DIRECTORY [get_runs impl_1]]
file mkdir $output_dir
file copy -force [file join $run_dir $top_name.bit] [file join $output_dir $proj_name.bit]
file copy -force [file join $run_dir $top_name.bin] [file join $output_dir $proj_name.bit.bin]
if {[file exists [file join $run_dir $top_name.ltx]]} {
    file copy -force [file join $run_dir $top_name.ltx] [file join $output_dir $proj_name.ltx]
}
close_project
puts "Bitstream written to [file join $output_dir $proj_name.bit]"
