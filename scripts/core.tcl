# Packages a user IP core from ip_cores/<core_name> into build/cores/<core_name>, so it can be
# placed in the block design.
#
# The core folder contains:
#   hdl/*.vhd|v|sv     HDL sources
#   core_config.tcl    sets core properties and bus interfaces (uses core_parameter below)
#   core_ext.tcl       optional, adds Xilinx IPs from the catalog to the core
#   *.xdc              optional, core constraints
#
# The core name ends with the version, e.g. axis_ram_writer_v2_0 becomes version 2.0.
# Usage: vivado -mode batch -source scripts/core.tcl -tclargs <core_name>

source [file join [file dirname [info script]] settings.tcl]
source [file join $root_dir src parameters.tcl]

set core_name [lindex $argv 0]
set core_src  [file join $ip_src_dir $core_name]
set core_dir  [file join $cores_dir $core_name]
set prj_dir   [file join $cores_dir .prj $core_name]

if {![file isdirectory $core_src]} {
    error "IP core $core_name not found in $ip_src_dir"
}
set version [string trimleft [join [lrange [split $core_name _] end-1 end] .] v]

file delete -force $core_dir $prj_dir
create_project -part $part $core_name $prj_dir -force
set_property target_language Verilog [current_project]
set_property enable_vhdl_2008 1 [current_project]

set hdl_files [glob -nocomplain [file join $core_src hdl *.vhd] [file join $core_src hdl *.v] [file join $core_src hdl *.sv]]
if {[llength $hdl_files] == 0} {
    error "No HDL sources found in [file join $core_src hdl]"
}
add_files -fileset sources_1 -norecurse $hdl_files
set xdc_files [glob -nocomplain [file join $core_src *.xdc]]
if {[llength $xdc_files]} { add_files -fileset constrs_1 -norecurse $xdc_files }
update_compile_order -fileset sources_1

# Xilinx IPs used inside the core
if {[file exists [file join $core_src core_ext.tcl]]} {
    source [file join $core_src core_ext.tcl]
}

ipx::package_project -import_files -root_dir $core_dir
set core [ipx::current_core]

set_property VERSION $version $core
set_property NAME $core_name $core
set_property LIBRARY $ip_library $core
set_property SUPPORTED_FAMILIES $ip_supported_families $core
set_property VENDOR $ip_vendor $core
set_property VENDOR_DISPLAY_NAME $ip_vendor_disp_name $core
set_property COMPANY_URL $ip_company_url $core

# Sets display name and description of a core parameter, called from core_config.tcl
proc core_parameter {name display_name description} {
    set core [ipx::current_core]

    set parameter [ipx::get_user_parameters $name -of_objects $core]
    set_property DISPLAY_NAME $display_name $parameter
    set_property DESCRIPTION $description $parameter

    set parameter [ipgui::get_guiparamspec -name $name -component $core]
    set_property DISPLAY_NAME $display_name $parameter
    set_property TOOLTIP $description $parameter
}

source [file join $core_src core_config.tcl]

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
close_project

puts "Packaged $ip_vendor:$ip_library:$core_name:$version in $core_dir"
