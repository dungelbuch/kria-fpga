set display_name {AXI4-Stream Dummy Data Generator v2.0}
set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

#Generic Values:
core_parameter reset_index {RESET_INDEX} {Index where this module is connected to rstn vector}
core_parameter reset_width {RESET_WIDTH} {Reset width of rstn vector, num of modules that are connected to rstn vector}
core_parameter int_data_width {INT DATA WIDTH} {Width of internal data bus.}
core_parameter int_bram_depth {INT BRAM DEPTH} {Depth of internal BRAM.}
core_parameter int_bram_ctrl_addr_width {INT BRAM CTRL ADDR WIDTH} {Width of internal BRAM control address bus.}
core_parameter int_bram_addr_offset {INT BRAM ADDR OFFSET} {Amount of bits to shift the address of the internal BRAM, offset represents size of one sample.}
core_parameter int_bram_addr_width {INT BRAM ADDR WIDTH} {Width of internal BRAM address bus (Port B).}
core_parameter s_axi_data_width {S_AXI DATA WIDTH} {Width of AXI4-Lite data bus.}
core_parameter s_axi_addr_width {S_AXI ADDR WIDTH} {Width of AXI4-Lite addr bus.}
core_parameter m_axis_tdata_width {M_AXIS TDATA WIDTH} {Width of AXI4-Stream data bus.}

# Configure AXI Slave Bus Interface for BRAM
set bus [ipx::get_bus_interfaces -of_objects $core s_axi_bram]
set_property NAME S_AXI_BRAM $bus
set_property INTERFACE_MODE slave $bus

# Configure AXI Slave Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core s_axi_regs]
set_property NAME S_AXI_REGS $bus
set_property INTERFACE_MODE slave $bus

# Configure AXIS Master Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core m_axis]
set_property NAME M_AXIS $bus
set_property INTERFACE_MODE master $bus

# Configure AXIS debug Bus Interface
set bus [ipx::get_bus_interfaces -of_objects $core debug_m_axis]
set_property NAME DEBUG_M_AXIS $bus
set_property INTERFACE_MODE master $bus

# BRAM address range follows the BRAM size (BRAM_AXI_CTRL_ADDR_WIDTH from src/parameters.tcl)
set block [ipx::get_address_blocks -of_objects [ipx::get_memory_maps s_axi_bram -of_objects $core]]
set_property RANGE [expr {2**$BRAM_AXI_CTRL_ADDR_WIDTH}] $block

# rstn is a vector of per-module resets, not a single reset interface
ipx::remove_bus_interface rstn $core

# Associate all interfaces with the clock (names changed above, so set it again)
set bus [ipx::get_bus_interfaces aclk -of_objects $core]
set_property VALUE S_AXI_REGS:S_AXI_BRAM:M_AXIS:DEBUG_M_AXIS [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $bus]
set_property VALUE s_axi_aresetn [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $bus]
