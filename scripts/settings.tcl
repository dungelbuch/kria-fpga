# Shared project settings, sourced by the other scripts.

set root_dir    [file normalize [file join [file dirname [info script]] ..]]
set build_dir   [file join $root_dir build]
set output_dir  [file join $root_dir output]
set ip_src_dir  [file join $root_dir ip_cores]
set cores_dir   [file join $build_dir cores]

set proj_name   kr260_ps
set bd_name     kr260_ps
set top_name    kr260_top

# Minimum Vivado version (board files and IP versions are tied to it)
set vivado_version 2025.2

set part        xck26-sfvc784-2LV-c
set board_part  xilinx.com:kr260_som:part0:1.1
set board_conn  {som240_1_connector xilinx.com:kr260_carrier:som240_1_connector:1.1 som240_2_connector xilinx.com:kr260_carrier:som240_2_connector:1.1}

# Run strategies
set synth_strategy Flow_PerfOptimized_high
set impl_strategy  Performance_ExtraTimingOpt

# Settings for packaged user IP cores
set ip_library            user
set ip_supported_families {zynquplus Production}
set ip_vendor             hhi-thz
set ip_vendor_disp_name   hhi-thz
set ip_company_url        {}

# Parallel jobs for synthesis/implementation runs (overridable via the JOBS environment variable)
set jobs [expr {[info exists ::env(JOBS)] ? $::env(JOBS) : 4}]

# Opens the project and checks the Vivado version
proc open_kria_project {} {
    global build_dir proj_name vivado_version
    if {[package vcompare [version -short] $vivado_version] < 0} {
        error "Vivado $vivado_version or newer required, running [version -short]"
    }
    open_project [file join $build_dir $proj_name.xpr]
}

# Returns 1 if the run is up to date and finished at least up to the given step
proc run_done {run step} {
    if {[get_property NEEDS_REFRESH $run]} { return 0 }
    set steps {synth_design init_design opt_design power_opt_design place_design \
               post_place_power_opt_design phys_opt_design route_design \
               post_route_phys_opt_design write_bitstream}
    if {![regexp {^(\S+) Complete} [get_property STATUS $run] -> done_step]} { return 0 }
    return [expr {[lsearch $steps $done_step] >= [lsearch $steps $step]}]
}

# Runs the given run up to the given step, unless it already got there
proc run_to {run step} {
    global jobs
    set run [get_runs $run]
    if {[run_done $run $step]} {
        puts "$run is up to date ([get_property STATUS $run])"
        return
    }
    if {$step eq "synth_design"} {
        reset_run $run
        launch_runs $run -jobs $jobs
    } else {
        # Keep a run that stopped cleanly at an earlier step, so e.g. write_bitstream continues
        # from route_design. Stale, failed or never started runs are reset.
        if {[get_property NEEDS_REFRESH $run] || ![string match "* Complete*" [get_property STATUS $run]]} {
            reset_run $run
        }
        launch_runs $run -to_step $step -jobs $jobs
    }
    wait_on_run $run
    if {![run_done $run $step]} {
        error "$run failed ([get_property STATUS $run]), see [get_property DIRECTORY $run]/runme.log"
    }
}
