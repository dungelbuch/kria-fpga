# Block design, sourced by scripts/project.tcl into an empty block design.
# Uses the helpers cell/module/addr from scripts/bd_utils.tcl and the values in src/parameters.tcl.
#
#   dummy_data_gen --AXIS--> ram_writer --AXI3--> SmartConnect --> PS S_AXI_HP0_FPD (DDR)
#   PS M_AXI_HPM0_FPD --> SmartConnect --> AXI-Lite registers of all cores and GPIOs

############################################################################################################################
# Processing system
############################################################################################################################
cell xilinx.com:ip:zynq_ultra_ps_e ps {} {}
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells ps]

# Enable the PS->PL master (HPM0_FPD) for register access and the PL->PS slave (HP0_FPD) for DDR access,
# disable the other masters enabled by the board preset
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 1 \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH 32 \
    CONFIG.PSU__USE__M_AXI_GP1 0 \
    CONFIG.PSU__USE__M_AXI_GP2 0 \
    CONFIG.PSU__USE__S_AXI_GP2 1 \
    CONFIG.PSU__SAXIGP2__DATA_WIDTH 64 \
    CONFIG.PSU__FPGA_PL0_ENABLE 1 \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $PL_CLK_FREQ \
] [get_bd_cells ps]

# Reset synchronized to pl_clk0
cell xilinx.com:ip:proc_sys_reset rst_pl_clk0 {} {
    slowest_sync_clk ps/pl_clk0
    ext_reset_in ps/pl_resetn0
}

connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/maxihpm0_fpd_aclk]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/saxihp0_fpd_aclk]

# Clock and reset of the SmartConnects created by addr/axi_connect
set axi_clk  ps/pl_clk0
set axi_rstn rst_pl_clk0/peripheral_aresetn

############################################################################################################################
# System: user reset vector and LEDs
############################################################################################################################
# Each user core takes its active-low reset from rstn[RESET_INDEX]; all cores stay in reset until software releases them
cell xilinx.com:ip:axi_gpio axi_gpio_rstn {
    C_GPIO_WIDTH $RESET_WIDTH
    C_ALL_OUTPUTS 1
    C_DOUT_DEFAULT 0x00000000
} {
    s_axi_aclk ps/pl_clk0
    s_axi_aresetn rst_pl_clk0/peripheral_aresetn
}
addr $AXI_BASE_ADDR_GPIO_RSTN $AXI_SLAVE_RANGE axi_gpio_rstn/S_AXI ps/M_AXI_HPM0_FPD

# User LEDs (UF1, UF2) on the carrier, connected to the led_o port of the top level
create_bd_port -dir O -from 1 -to 0 led_o
cell xilinx.com:ip:axi_gpio axi_gpio_leds {
    C_GPIO_WIDTH 2
    C_ALL_OUTPUTS 1
} {
    s_axi_aclk ps/pl_clk0
    s_axi_aresetn rst_pl_clk0/peripheral_aresetn
    gpio_io_o led_o
}
addr $AXI_BASE_ADDR_GPIO_LEDS $AXI_SLAVE_RANGE axi_gpio_leds/S_AXI ps/M_AXI_HPM0_FPD

############################################################################################################################
# Dummy data generator
############################################################################################################################
cell hhi-thz:user:axis_dummy_data_generator_v2_0 dummy_data_gen {
    RESET_WIDTH $RESET_WIDTH
    RESET_INDEX $RESET_INDEX_DUMMY_DATA_GEN
    INT_BRAM_DEPTH $BRAM_AXI_DEPTH
    INT_BRAM_CTRL_ADDR_WIDTH $BRAM_AXI_CTRL_ADDR_WIDTH
    INT_BRAM_ADDR_OFFSET $BRAM_AXI_ADDR_OFFSET
} {
    aclk ps/pl_clk0
    rstn axi_gpio_rstn/gpio_io_o
    s_axi_aresetn rst_pl_clk0/peripheral_aresetn
}
addr $AXI_BASE_ADDR_DUMMY_REGS $AXI_SLAVE_RANGE dummy_data_gen/S_AXI_REGS ps/M_AXI_HPM0_FPD
addr $AXI_BASE_ADDR_DUMMY_BRAM $BRAM_AXI_RANGE dummy_data_gen/S_AXI_BRAM ps/M_AXI_HPM0_FPD

############################################################################################################################
# RAM writer: writes the stream into DDR
############################################################################################################################
cell hhi-thz:user:axis_ram_writer_v2_0 ram_writer {
    RESET_WIDTH $RESET_WIDTH
    RESET_INDEX $RESET_INDEX_RAM_WRITER
    STS_DATA_WIDTH 32
    CFG_DATA_WIDTH 32
    M_AXI_ID_WIDTH 3
    M_AXI_ADDR_WIDTH 32
    M_AXI_DATA_WIDTH 64
    AXI_ADDR_WIDTH 6
    AXI_DATA_WIDTH 32
    S_AXIS_TDATA_WIDTH 32
    FIFO_WRITE_DEPTH 1024
} {
    aclk ps/pl_clk0
    rstn axi_gpio_rstn/gpio_io_o
    s_axi_aresetn rst_pl_clk0/peripheral_aresetn
    S_AXIS dummy_data_gen/M_AXIS
}
addr $AXI_BASE_ADDR_RAM_WRITER $AXI_SLAVE_RANGE ram_writer/S_AXI ps/M_AXI_HPM0_FPD

# The RAM writer addresses the lower 2 GB of DDR; the other PS memory regions are not reachable
axi_connect ps/S_AXI_HP0_FPD ram_writer/M_AXI
assign_bd_address -offset 0x00000000 -range 2G [get_bd_addr_segs ps/SAXIGP2/HP0_DDR_LOW]
