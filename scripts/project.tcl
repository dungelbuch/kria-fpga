# Creates the Vivado project in build/ from the sources in src/ and the packaged IP cores in
# build/cores/ (see core.tcl).
#   src/bd/<bd_name>.tcl   block design, written with the helpers from bd_utils.tcl
#   src/hdl/               HDL sources, including the top level that wraps the block design
#   src/constraints/       constraints
# Usage: vivado -mode batch -source scripts/project.tcl

source [file join [file dirname [info script]] settings.tcl]

if {[package vcompare [version -short] $vivado_version] < 0} {
    error "Vivado $vivado_version or newer required, running [version -short]"
}

create_project $proj_name $build_dir -part $part -force
set_property board_part $board_part [current_project]
set_property board_connections $board_conn [current_project]
set_property target_language Verilog [current_project]
set_property enable_vhdl_2008 1 [current_project]
set_property mem.enable_memory_map_generation 1 [current_project]

# User IP cores
set_property ip_repo_paths $cores_dir [current_project]
update_ip_catalog

# Block design
source [file join $root_dir scripts bd_utils.tcl]
source [file join $root_dir src parameters.tcl]
create_bd_design $bd_name
source [file join $root_dir src bd $bd_name.tcl]
validate_bd_design
save_bd_design
set bd_file [get_files $bd_name.bd]
generate_target all $bd_file

# HDL and constraint files
set hdl_files [glob -nocomplain [file join $root_dir src hdl *.v] [file join $root_dir src hdl *.sv] [file join $root_dir src hdl *.vhd]]
if {[llength $hdl_files]} { add_files -norecurse $hdl_files }
set vhd_files [get_files -quiet -filter {FILE_TYPE == VHDL} [file join $root_dir src hdl *]]
if {[llength $vhd_files]} { set_property FILE_TYPE {VHDL 2008} $vhd_files }
set xdc_files [glob -nocomplain [file join $root_dir src constraints *.xdc]]
if {[llength $xdc_files]} { add_files -fileset constrs_1 -norecurse $xdc_files }

set_property top $top_name [current_fileset]
update_compile_order -fileset sources_1

set_property strategy $synth_strategy [get_runs synth_1]
set_property strategy $impl_strategy [get_runs impl_1]
# Also write a .bin file, which is what fpgautil/xmutil load on the Kria
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

close_project
puts "Project created: [file join $build_dir $proj_name.xpr]"
