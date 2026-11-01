# BRAM size and clock come from src/parameters.tcl (sourced by core.tcl / core_sim.tcl)

# Create BRAM controller and insert IP from xilinx into the current IP:
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -module_name axi_bram_ctrl_0
set_property -dict [list \
    CONFIG.CLKIF.FREQ_HZ [expr {int($PL_CLK_FREQ * 1000000)}] \
    CONFIG.PROTOCOL AXI4LITE \
    CONFIG.SINGLE_PORT_BRAM 1 \
    CONFIG.MEM_DEPTH $BRAM_AXI_DEPTH \
] [get_ips axi_bram_ctrl_0]
generate_target {all} [get_files axi_bram_ctrl_0.xci]
update_compile_order -fileset sources_1

# Create block memory and insert IP from xilinx into the current IP:
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name blk_mem_gen_0
set_property -dict [list \
    CONFIG.Memory_type True_Dual_Port_RAM \
    CONFIG.Enable_32bit_Address true \
    CONFIG.Use_Byte_Write_Enable true \
    CONFIG.Byte_Size 8 \
    CONFIG.Assume_Synchronous_Clk false \
    CONFIG.Enable_B Use_ENB_Pin \
    CONFIG.Write_Depth_A $BRAM_AXI_DEPTH \
    CONFIG.Write_Width_A $BRAM_AXI_WIDTH \
    CONFIG.Write_Width_B $BRAM_AXI_WIDTH \
    CONFIG.Read_Width_A $BRAM_AXI_WIDTH \
    CONFIG.Read_Width_B $BRAM_AXI_WIDTH \
    CONFIG.Port_A_Write_Rate 50 \
    CONFIG.Port_B_Write_Rate 50 \
    CONFIG.Register_PortA_Output_of_Memory_Primitives false \
    CONFIG.Register_PortB_Output_of_Memory_Primitives false \
    CONFIG.Use_RSTA_Pin true \
    CONFIG.Use_RSTB_Pin false \
    CONFIG.EN_SAFETY_CKT true \
    CONFIG.use_bram_block BRAM_Controller \
] [get_ips blk_mem_gen_0]
generate_target {all} [get_files blk_mem_gen_0.xci]
update_compile_order -fileset sources_1
