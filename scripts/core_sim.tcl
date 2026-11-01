# Creates a Vivado simulation project for a single IP core in build/sim_cores/<core_name>_sim.
# The core's sim/ folder holds the testbench and a sim_config.tcl, which adds further sources and
# sets simulation properties. The libraries in ip_cores/xlibs are added as well.
# Usage: vivado -mode batch -source scripts/core_sim.tcl -tclargs <core_name>

source [file join [file dirname [info script]] settings.tcl]
source [file join $root_dir src parameters.tcl]

set core_name    [lindex $argv 0]
set core_src     [file join $ip_src_dir $core_name]
set project_name ${core_name}_sim
# Used by the sim_config.tcl scripts
set ip_location  $ip_src_dir

create_project $project_name [file join $build_dir sim_cores $project_name] -part $part -force
set_property board_part $board_part [current_project]
set_property target_language VHDL [current_project]

# Custom libraries and utility functions
set custom_libs [glob -nocomplain [file join $ip_src_dir xlibs *.vhd]]
if {[llength $custom_libs]} { add_files -fileset sources_1 -norecurse $custom_libs }

# Core sources and the Xilinx IPs it uses
if {[file isdirectory [file join $core_src hdl]]} {
    add_files -norecurse -scan_for_includes [file join $core_src hdl]
}
if {[file exists [file join $core_src core_ext.tcl]]} {
    source [file join $core_src core_ext.tcl]
}
update_compile_order -fileset sources_1

# Simulation sources and configuration
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse -scan_for_includes [file join $core_src sim]
source [file join $core_src sim sim_config.tcl]
update_compile_order -fileset sim_1
# Testbenches locate their test vectors relative to the repository
set_property generic "repo_path=\"$root_dir\"" [get_filesets sim_1]

set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

close_project
puts "Simulation project created: [file join $build_dir sim_cores $project_name $project_name.xpr]"
