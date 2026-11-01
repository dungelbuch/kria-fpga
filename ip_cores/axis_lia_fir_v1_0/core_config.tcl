set display_name {AXI4-Stream FIR Filter}
set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

#Generic Values:
core_parameter reset_index {RESET_INDEX} {Index where this module is connected to rstn vector}
core_parameter reset_width {RESET_WIDTH} {Reset width of rstn vector, num of modules that are connected to rstn vector}
core_parameter s_axi_data_width {S_AXI_DATA_WIDTH} {AXI4-Stream data width}
core_parameter s_axi_addr_width {S_AXI_ADDR_WIDTH} {AXI4-Stream address width}
core_parameter s_axis_tdata_width {S_AXIS_TDATA_WIDTH} {AXI4-Stream slave tdata width}
core_parameter m_axis_tdata_width {M_AXIS_TDATA_WIDTH} {AXI4-Stream master tdata width}
core_parameter fir_coeff_width {FIR_COEFF_WIDTH} {Width of FIR coefficients}
core_parameter fir_coeff_frac_bits {FIR_COEFF_FRAC_BITS} {Number of fractional bits in FIR coefficients}

# Configure AXI Slave Interface
set bus [ipx::get_bus_interfaces -of_objects $core s_axi_fir]
set_property NAME S_AXI_FIR $bus
set_property INTERFACE_MODE slave $bus

# Configure AXIS Slave Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core s_axis_i]
set_property NAME S_AXIS_I $bus
set_property INTERFACE_MODE slave $bus

# Configure AXIS Slave Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core s_axis_q]
set_property NAME S_AXIS_Q $bus
set_property INTERFACE_MODE slave $bus

# Configure AXIS Master Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core m_axis]
set_property NAME M_AXIS $bus
set_property INTERFACE_MODE master $bus

# rstn is a vector of per-module resets, not a single reset interface
ipx::remove_bus_interface rstn $core

# Associate all interfaces with the clock (names changed above, so set it again)
set bus [ipx::get_bus_interfaces aclk -of_objects $core]
set_property VALUE S_AXI_FIR:S_AXIS_I:S_AXIS_Q:M_AXIS [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $bus]
set_property VALUE s_axi_aresetn [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $bus]
