# Clock comes from src/parameters.tcl (sourced by core.tcl / core_sim.tcl)

# Multiplier used by the second order sections (sos.vhd) to multiply data with coefficients
create_ip -name mult_gen -vendor xilinx.com -library ip -module_name multiplier
set_property -dict [list \
    CONFIG.CLK_INTF.FREQ_HZ [expr {int($PL_CLK_FREQ * 1000000)}] \
    CONFIG.PortAWidth 25 \
    CONFIG.PortBWidth 32 \
    CONFIG.Multiplier_Construction Use_Mults \
    CONFIG.OptGoal Speed \
    CONFIG.ClockEnable true \
    CONFIG.PipeStages 1 \
    CONFIG.SyncClear true \
    CONFIG.SclrCePriority SCLR_Overrides_CE \
] [get_ips multiplier]
generate_target {all} [get_files multiplier.xci]
update_compile_order -fileset sources_1
