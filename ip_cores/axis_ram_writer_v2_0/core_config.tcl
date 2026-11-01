set display_name {AXI4-Stream RAM Writer}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter RESET_WIDTH {reset width} {width of system reset vector.}
core_parameter RESET_INDEX {reset index} {index of modules reset position within the reset vector.}
core_parameter STS_DATA_WIDTH {sts data width} {width of the status register.}
core_parameter CFG_DATA_WIDTH {cfg data width} {width of the config register.}
core_parameter M_AXI_ID_WIDTH {m axi id width} {width of the axi master id bus.}
core_parameter M_AXI_ADDR_WIDTH {m axi addr width} {width of the axi master address bus.}
core_parameter M_AXI_DATA_WIDTH {m axi data width} {width of the axi master data bus.}
core_parameter AXI_ADDR_WIDTH {axi addr width} {width of the axi master address bus.}
core_parameter AXI_DATA_WIDTH {axi data width} {width of the axi master data bus.}
core_parameter S_AXIS_TDATA_WIDTH {s axis tdata width} {width of the s_axis data bus.}
core_parameter FIFO_WRITE_DEPTH {fifo write depth} {depth of the write side of the fifo buffer.}
core_parameter DEBUG_MODE_TB {debug mode tb} {enable/disable debug mode for testbench environments}
core_parameter DEBUG_STS_WIDTH_MASK {debug} {sts_width debug value when in debug testbench mode}
core_parameter DEBUG_BLOCK_MODE_EN {debug} {block_mode_en when in debug testbench mode}

set address [ipx::get_address_spaces m_axi -of_objects $core]
set_property NAME M_AXI $address

set bus [ipx::get_bus_interfaces -of_objects $core m_axi]
set_property NAME M_AXI $bus
set_property INTERFACE_MODE master $bus
set_property MASTER_ADDRESS_SPACE_REF M_AXI $bus
# The write channel has AXI3 signals (4 bit awlen, wid)
ipx::add_bus_parameter PROTOCOL $bus
set_property VALUE AXI3 [ipx::get_bus_parameters PROTOCOL -of_objects $bus]

set bus [ipx::get_bus_interfaces -of_objects $core s_axis]
set_property NAME S_AXIS $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces -of_objects $core s_axi]
set_property NAME S_AXI $bus
set_property INTERFACE_MODE slave $bus

# rstn is a vector of per-module resets, not a single reset interface
ipx::remove_bus_interface rstn $core

set bus [ipx::get_bus_interfaces aclk -of_objects $core]
set_property VALUE M_AXI:S_AXI:S_AXIS [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $bus]
set_property VALUE s_axi_aresetn [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $bus]
