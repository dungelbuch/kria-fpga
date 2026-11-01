# Clock comes from src/parameters.tcl (sourced by core.tcl / core_sim.tcl)
# The filter accepts one sample every FIR_SAMPLE_RATE_DIV clock cycles
set FIR_SAMPLE_RATE_DIV 10

create_ip -name fir_compiler -vendor xilinx.com -library ip -module_name lia_fir
set_property -dict [list \
    CONFIG.CoefficientSource COE_File \
    CONFIG.Coefficient_File [file join $core_src coeff fir.coe] \
    CONFIG.Has_ARESETn true \
    CONFIG.Number_Paths 1  \
    CONFIG.Sample_Frequency [expr {double($PL_CLK_FREQ) / $FIR_SAMPLE_RATE_DIV}] \
    CONFIG.Clock_Frequency $PL_CLK_FREQ \
    CONFIG.Coefficient_Sets 1 \
    CONFIG.Coefficient_Reload false  \
    CONFIG.Coefficient_Sign Signed \
    CONFIG.Quantization Integer_Coefficients \
    CONFIG.Coefficient_Width 25 \
    CONFIG.Coefficient_Fractional_Bits 0 \
    CONFIG.Coefficient_Structure Symmetric \
    CONFIG.Data_Width 32 \
    CONFIG.Data_Fractional_Bits 0 \
    CONFIG.M_DATA_Has_TREADY false \
    CONFIG.Output_Rounding_Mode Full_Precision \
    CONFIG.Filter_Architecture Systolic_Multiply_Accumulate \
] [get_ips lia_fir]
generate_target {all} [get_files lia_fir.xci]
update_compile_order -fileset sources_1
