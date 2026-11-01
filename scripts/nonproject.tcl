# Builds the design in non-project mode: the block design, HDL and constraints from src/ are read
# into memory and taken through synthesis, implementation and bitstream generation without a
# Vivado project. Needs the IP cores packaged in build/cores/ (see core.tcl).
#
# Checkpoints and reports go to build/nonproject/, the bitstream (.bit, .bit.bin) and the hardware
# platform (.xsa) to output/nonproject/. A summary of run times, timing, utilization and power is
# printed at the end and written to build/nonproject/summary.txt.
#
# The synthesis and implementation directives follow the strategies in settings.tcl
# (Flow_PerfOptimized_high, Performance_ExtraTimingOpt).
# Usage: vivado -mode batch -source scripts/nonproject.tcl

source [file join [file dirname [info script]] settings.tcl]
source [file join $root_dir src parameters.tcl]

if {[package vcompare [version -short] $vivado_version] < 0} {
    error "Vivado $vivado_version or newer required, running [version -short]"
}

set np_dir      [file join $build_dir nonproject]
set report_dir  [file join $np_dir reports]
set np_out_dir  [file join $output_dir nonproject]
file delete -force $np_dir $np_out_dir
file mkdir $report_dir $np_out_dir
# Keep files that Vivado writes to the working directory (e.g. clockInfo.txt) out of the repository
cd $np_dir
set_param general.maxThreads [expr {min($jobs, 32)}]

# Runs a build step and records its run time for the summary
set step_times {}
proc step {name body} {
    global step_times
    puts "\n######## $name ########"
    set start [clock milliseconds]
    uplevel 1 $body
    lappend step_times $name [expr {([clock milliseconds] - $start) / 1000}]
}

proc format_time {seconds} {
    format "%d:%02d" [expr {$seconds / 60}] [expr {$seconds % 60}]
}

# Returns {used available percent} of a row in the utilization report
proc util_row {report name} {
    if {[regexp -line "^\\|\\s*[string map {( \\( ) \\)} $name]\\*?\\s*\\|\\s*(\\d+)\\s*\\|\\s*\\d+\\s*\\|\\s*\\d+\\s*\\|\\s*(\\d+)\\s*\\|\\s*(\[\\d.<]+)\\s*\\|" \
            $report -> used avail pct]} {
        return [list $used $avail $pct]
    }
    return {- - -}
}

proc slack {type} {
    set path [get_timing_paths -quiet -max_paths 1 -nworst 1 -$type]
    if {[llength $path] == 0} { return "-" }
    return [get_property SLACK $path]
}

# Path relative to the repository
proc relpath {path} {
    global root_dir
    return [string range $path [string length $root_dir/] end]
}

# Prints the summary and writes it to build/nonproject/summary.txt
proc summary {status} {
    global step_times np_dir np_out_dir report_dir proj_name part build_start

    set lines {}
    set sep [string repeat = 72]
    lappend lines $sep "Non-project build summary: $proj_name ($part)" $sep
    lappend lines "Status:       $status"
    lappend lines "Total time:   [format_time [expr {([clock milliseconds] - $build_start) / 1000}]]"
    lappend lines ""

    lappend lines "Step times:"
    foreach {name seconds} $step_times {
        lappend lines [format "  %-24s %8s" $name [format_time $seconds]]
    }

    if {[llength [current_design -quiet]] && [get_property -quiet NAME [current_design]] ne ""} {
        set wns [slack setup]
        set whs [slack hold]
        set timing_ok [expr {[string is double -strict $wns] && $wns >= 0 && [string is double -strict $whs] && $whs >= 0}]
        lappend lines "" "Timing:       [expr {$timing_ok ? "met" : "NOT MET"}]"
        lappend lines [format "  %-24s %8s ns" "WNS (setup)" $wns]
        lappend lines [format "  %-24s %8s ns" "WHS (hold)" $whs]
        set unrouted [llength [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == UNROUTED || ROUTE_STATUS == CONFLICTS}]]
        lappend lines [format "  %-24s %8s" "Unrouted nets" $unrouted]

        set report [report_utilization -return_string]
        lappend lines "" [format "Utilization:  %-12s %8s %10s %8s" "" Used Available Util%]
        foreach {label row} {
            LUTs            {CLB LUTs}
            Registers       {CLB Registers}
            {Block RAM}     {Block RAM Tile}
            URAM            URAM
            DSPs            DSPs
        } {
            lassign [util_row $report $row] used avail pct
            lappend lines [format "  %-24s %8s %10s %7s%%" $label $used $avail $pct]
        }

        set power [report_power -return_string]
        if {[regexp -line {^\|\s*Total On-Chip Power \(W\)\s*\|\s*([\d.]+)} $power -> total_power]} {
            lappend lines "" [format "Power:        %s W total on-chip" $total_power]
        }
    }

    lappend lines "" "Messages:"
    foreach severity {{CRITICAL WARNING} ERROR} {
        lappend lines [format "  %-24s %8s" [string totitle $severity] [get_msg_config -count -severity $severity]]
    }

    lappend lines "" "Outputs:"
    foreach file [lsort [glob -nocomplain [file join $np_out_dir *]]] {
        lappend lines [format "  %-38s %6.1f MB" [relpath $file] [expr {[file size $file] / 1048576.0}]]
    }
    lappend lines "" "Reports:      [relpath $report_dir]/"
    lappend lines $sep

    set text [join $lines \n]
    puts "\n$text"
    set fh [open [file join $np_dir summary.txt] w]
    puts $fh $text
    close $fh
}

set build_start [clock milliseconds]

if {[catch {
    step "Read sources" {
        create_project -in_memory -part $part
        set_property board_part $board_part [current_project]
        set_property board_connections $board_conn [current_project]
        set_property target_language Verilog [current_project]
        set_property mem.enable_memory_map_generation 1 [current_project]

        # User IP cores
        set_property ip_repo_paths $cores_dir [current_project]
        update_ip_catalog

        # Block design, the IPs are synthesized together with the top level (no OOC runs)
        source [file join $root_dir scripts bd_utils.tcl]
        create_bd_design -dir $np_dir $bd_name
        source [file join $root_dir src bd $bd_name.tcl]
        validate_bd_design
        save_bd_design
        set bd_file [get_files $bd_name.bd]
        set_property synth_checkpoint_mode None $bd_file
        generate_target all $bd_file

        # HDL and constraint files
        foreach file [glob -nocomplain [file join $root_dir src hdl *.v]]   { read_verilog $file }
        foreach file [glob -nocomplain [file join $root_dir src hdl *.sv]]  { read_verilog -sv $file }
        foreach file [glob -nocomplain [file join $root_dir src hdl *.vhd]] { read_vhdl -vhdl2008 $file }
        foreach file [glob -nocomplain [file join $root_dir src constraints *.xdc]] { read_xdc $file }
    }

    step "Synthesis" {
        synth_design -top $top_name -part $part -directive PerformanceOptimized \
            -fsm_extraction one_hot -keep_equivalent_registers -resource_sharing off \
            -no_lc -shreg_min_size 5
        write_checkpoint -force [file join $np_dir post_synth.dcp]
        report_utilization -file [file join $report_dir post_synth_utilization.rpt]
        report_timing_summary -file [file join $report_dir post_synth_timing_summary.rpt]
    }

    step "Optimization" {
        opt_design
    }

    step "Placement" {
        place_design -directive ExtraTimingOpt
        phys_opt_design -directive Explore
        write_checkpoint -force [file join $np_dir post_place.dcp]
    }

    step "Routing" {
        route_design -directive NoTimingRelaxation
        write_checkpoint -force [file join $np_dir post_route.dcp]
        report_timing_summary -file [file join $report_dir timing_summary.rpt]
        report_utilization -file [file join $report_dir utilization.rpt]
        report_power -file [file join $report_dir power.rpt]
        report_drc -file [file join $report_dir drc.rpt]
        report_route_status -file [file join $report_dir route_status.rpt]
    }

    # Fail on timing violations rather than producing a bitstream that may not work
    set wns [slack setup]
    set whs [slack hold]
    if {($wns ne "-" && $wns < 0) || ($whs ne "-" && $whs < 0)} {
        error "Timing not met (WNS = $wns ns, WHS = $whs ns), see [file join $report_dir timing_summary.rpt]"
    }

    step "Bitstream" {
        # Also write a .bin file, which is what fpgautil/xmutil load on the Kria
        write_bitstream -force -bin_file [file join $np_out_dir $proj_name.bit]
        file rename -force [file join $np_out_dir $proj_name.bin] [file join $np_out_dir $proj_name.bit.bin]
    }

    step "Export XSA" {
        write_hw_platform -fixed -include_bit -force -file [file join $np_out_dir $proj_name.xsa]
    }
} err]} {
    summary "FAILED: $err"
    error $err
}

summary "OK"
