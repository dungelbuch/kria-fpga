# Implements the design up to route_design, running synthesis first if it is out of date.
# Usage: vivado -mode batch -source scripts/impl.tcl

source [file join [file dirname [info script]] settings.tcl]

open_kria_project
run_to synth_1 synth_design
run_to impl_1 route_design

# Fail on timing violations rather than producing a bitstream that may not work
open_run impl_1
report_timing_summary -file [file join $build_dir reports timing_summary.rpt]
report_utilization -file [file join $build_dir reports utilization.rpt]
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "Timing: WNS = $wns ns, WHS = $whs ns"
if {($wns ne "" && $wns < 0) || ($whs ne "" && $whs < 0)} {
    error "Timing not met (WNS = $wns ns, WHS = $whs ns), see [file join $build_dir reports timing_summary.rpt]"
}
close_project
