
`timescale 1 ns / 1 ps

module axis_ram_writer #(
    // Reset vector index
    parameter integer RESET_WIDTH = 0,
    parameter integer RESET_INDEX = 0,
    // Status and Config register address width
    parameter integer STS_DATA_WIDTH = 32,
    parameter integer CFG_DATA_WIDTH = 32,
    // AXI master side parameters
    parameter integer M_AXI_ID_WIDTH = 3,
    parameter integer M_AXI_ADDR_WIDTH = 32,
    parameter integer M_AXI_DATA_WIDTH = 64,
    // AXI slave side parameters
    parameter integer AXI_ADDR_WIDTH = 6,
    parameter integer AXI_DATA_WIDTH = 32,
    // FIFO parameters
    parameter integer S_AXIS_TDATA_WIDTH = 32,
    parameter integer FIFO_WRITE_DEPTH = 1024,
    // testbench parameters
    parameter integer DEBUG_MODE_TB = 0,
    parameter integer DEBUG_STS_WIDTH_MASK = 1048575,
    parameter integer DEBUG_BLOCK_MODE_EN = 0
) (
    // System signals
    input wire aclk,
    input wire [RESET_WIDTH-1:0] rstn,

    // AXI master side
    output wire [    M_AXI_ID_WIDTH-1:0] m_axi_awid,     // Write address ID
    output wire [  M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,   // Write address
    output wire [                   3:0] m_axi_awlen,    // Write burst length
    output wire [                   2:0] m_axi_awsize,   // Write burst size
    output wire [                   1:0] m_axi_awburst,  // Write burst type
    output wire [                   3:0] m_axi_awcache,  // Write memory type
    output wire                          m_axi_awvalid,  // Write address valid
    input  wire                          m_axi_awready,  // Write address ready
    output wire [    M_AXI_ID_WIDTH-1:0] m_axi_wid,      // Write data ID
    output wire [  M_AXI_DATA_WIDTH-1:0] m_axi_wdata,    // Write data
    output wire [M_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,    // Write strobes
    output wire                          m_axi_wlast,    // Write last
    output wire                          m_axi_wvalid,   // Write valid
    input  wire                          m_axi_wready,   // Write ready
    input  wire                          m_axi_bvalid,   // Write response valid
    output wire                          m_axi_bready,   // Write response ready

    // AXI slave side
    input  wire                          s_axi_aresetn,  // axi-reset signal
    input  wire [    AXI_ADDR_WIDTH-1:0] s_axi_awaddr,   // write address
    input  wire [                   2:0] s_axi_awprot,   // Write protection
    input  wire                          s_axi_awvalid,  // Write address valid
    output wire                          s_axi_awready,  // Write address ready
    input  wire [    AXI_DATA_WIDTH-1:0] s_axi_wdata,    // Write data
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,    // Write strobes
    input  wire                          s_axi_wvalid,   // Write valid
    output wire                          s_axi_wready,   // Write readyj
    output wire [                   1:0] s_axi_bresp,    // Write response
    output wire                          s_axi_bvalid,   // Write response valid
    input  wire                          s_axi_bready,   // Write response ready
    input  wire [    AXI_ADDR_WIDTH-1:0] s_axi_araddr,   // read address
    input  wire [                   2:0] s_axi_arprot,   // Read protection
    input  wire                          s_axi_arvalid,  // Read address valid
    output wire                          s_axi_arready,  // Read address ready
    output wire [    AXI_DATA_WIDTH-1:0] s_axi_rdata,    // Read data
    output wire [                   1:0] s_axi_rresp,    // Read response
    output wire                          s_axi_rvalid,   // Read response valid
    input  wire                          s_axi_rready,   // Read response ready

    // AXI-Stream slave side
    output wire                          s_axis_tready,
    input  wire [S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  wire                          s_axis_tvalid
);

  // This function is used to calculate the minimum address width
  // to address a memory of a given size. clogb2 is initialized with '0'
  // and is incremented by '1' as long as value is greater than zero.
  function integer clogb2(input integer value);
    for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) value = value >> 1;
  endfunction

  localparam integer ADDR_SIZE = clogb2(M_AXI_DATA_WIDTH / 8 - 1);
  localparam integer COUNT_SIZE = clogb2(
      FIFO_WRITE_DEPTH * S_AXIS_TDATA_WIDTH / M_AXI_DATA_WIDTH - 1
  ) + 1;

  // Extract reset signal from reset vector
  wire reset = rstn[RESET_INDEX];

  // Create internal registers for AXI write signals
  reg int_awvalid_reg, int_awvalid_next;
  reg int_wvalid_reg, int_wvalid_next;
  reg [STS_DATA_WIDTH-1:0] int_addr_reg, int_addr_next;
  reg [M_AXI_ID_WIDTH-1:0] int_awid_reg, int_awid_next;

  // Create Internal signals connecting to slave registers
  wire [STS_DATA_WIDTH-1:0] sts_data_wire;
  wire [CFG_DATA_WIDTH-1:0] cfg_data_wire;
  wire block_mode_en_wire;
  wire [AXI_DATA_WIDTH-1:0] sts_width_mask_wire;

  // Internal wires for block mode en and sts_width in testbenches
  wire axi_block_mode_en_wire;
  wire [AXI_DATA_WIDTH-1:0] axi_sts_width_mask_wire;

  // Create internal write control wires for FIFO
  wire int_full_wire, int_empty_wire, int_rden_wire;
  wire int_wlast_wire, int_tready_wire;
  wire [COUNT_SIZE-1:0] int_count_wire;
  wire [M_AXI_DATA_WIDTH-1:0] int_wdata_wire;

  // Assign values to internal control wires
  assign int_tready_wire = ~int_full_wire;
  assign int_wlast_wire  = &int_addr_reg[3:0];
  assign int_rden_wire   = m_axi_wready & int_wvalid_reg;

  // Assign debug-generics instead of axi port for DEBUG_MODE_TB = 1
  assign block_mode_en_wire = (DEBUG_MODE_TB == 1'b1) ? DEBUG_BLOCK_MODE_EN : axi_block_mode_en_wire;
  assign sts_width_mask_wire = (DEBUG_MODE_TB == 1'b1) ? DEBUG_STS_WIDTH_MASK : axi_sts_width_mask_wire;

  // Instantiate AXI slave register
  axis_ram_writer_S_AXI #(
      // AXI slave side generic parameters
      .c_s_axi_data_width(AXI_DATA_WIDTH),
      .c_s_axi_addr_width(AXI_ADDR_WIDTH),
      .cfg_data_width(CFG_DATA_WIDTH),
      .sts_data_width(STS_DATA_WIDTH)
  ) ram_writer_slave_regs (
      .sts_data(sts_data_wire),
      .cfg_data(cfg_data_wire),
      .block_mode_en(block_mode_en_wire),
      .sts_width_mask(sts_width_mask_wire),
      .s_axi_aclk(aclk),
      .s_axi_aresetn(s_axi_aresetn),
      .s_axi_awaddr(s_axi_awaddr),
      .s_axi_awprot(s_axi_awprot),
      .s_axi_awvalid(s_axi_awvalid),
      .s_axi_awready(s_axi_awready),
      .s_axi_wdata(s_axi_wdata),
      .s_axi_wstrb(s_axi_wstrb),
      .s_axi_wvalid(s_axi_wvalid),
      .s_axi_wready(s_axi_wready),
      .s_axi_bresp(s_axi_bresp),
      .s_axi_bvalid(s_axi_bvalid),
      .s_axi_bready(s_axi_bready),
      .s_axi_araddr(s_axi_araddr),
      .s_axi_arprot(s_axi_arprot),
      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_rdata(s_axi_rdata),
      .s_axi_rresp(s_axi_rresp),
      .s_axi_rvalid(s_axi_rvalid),
      .s_axi_rready(s_axi_rready)
  );

  // Incoming data will be buffered with a synchonous FIFO
  xpm_fifo_sync #(
      .WRITE_DATA_WIDTH(S_AXIS_TDATA_WIDTH),
      .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),
      .READ_DATA_WIDTH(M_AXI_DATA_WIDTH),
      .READ_MODE("fwft"),
      .FIFO_READ_LATENCY(0),
      .USE_ADV_FEATURES("0400"),
      .RD_DATA_COUNT_WIDTH(COUNT_SIZE)
  ) fifo_0 (
      .full(int_full_wire),
      .rd_data_count(int_count_wire),
      .rst(~reset),
      .wr_clk(aclk),
      .wr_en(int_tready_wire & s_axis_tvalid),
      .din(s_axis_tdata),
      .rd_en(int_rden_wire),
      .dout(int_wdata_wire)
  );

  always @(posedge aclk) begin
    if(~reset)
      // Reset internal registers
      begin
      int_awvalid_reg <= 1'b0;
      int_wvalid_reg <= 1'b0;
      int_addr_reg <= {(STS_DATA_WIDTH) {1'b0}};
      int_awid_reg <= {(M_AXI_ID_WIDTH) {1'b0}};
      end
    else
    // Assign values to internal registers (new/current values from AXI bus)
      begin
      // Add a condition to check if BLOCK_MODE is enabled
        if (block_mode_en_wire == 1 && ( int_addr_reg == sts_width_mask_wire ))
          begin
            int_awvalid_reg <= 1'b0;
            int_wvalid_reg <= 1'b0;
          end
        else
          begin
            // normal operation when not in Block-Mode
            int_awvalid_reg <= int_awvalid_next;
            int_wvalid_reg  <= int_wvalid_next; // here we apply the wvalid_reg with next value
            int_addr_reg <= int_addr_next;
            int_awid_reg <= int_awid_next;
          end
      end
  end

  always @* begin
    // Assign current values as next values, if no internal control signals changes
    int_awvalid_next = int_awvalid_reg;
    int_wvalid_next = int_wvalid_reg;
    int_addr_next = int_addr_reg;
    int_awid_next = int_awid_reg;

    // Assert 'write address/data valid' signals,
    // if enough data is stored inside FIFO
    if ((int_count_wire > 4'd15) & ~int_awvalid_reg & ~int_wvalid_reg) begin
      int_awvalid_next = 1'b1;
      int_wvalid_next  = 1'b1;
    end

    // Deassert internal 'write address ready' signal
    if (m_axi_awready & int_awvalid_reg) begin
      int_awvalid_next = 1'b0;
    end

    // Increment write address, if read data enable is asserted
    if (int_rden_wire) begin
      int_addr_next = int_addr_reg + 1'b1;
    end

    // When slave module is ready to be written
    if (m_axi_wready & int_wlast_wire) begin
      int_awid_next = int_awid_reg + 1'b1;
      if (int_count_wire > 5'd16) begin
        int_awvalid_next = 1'b1;
      end else begin
        int_wvalid_next = 1'b0;
      end
    end
  end

  // Assign internal values to module's output
  assign sts_data_wire = int_addr_reg & sts_width_mask_wire;
  //
  assign m_axi_awid = int_awid_reg;
  assign m_axi_awaddr = cfg_data_wire + {sts_data_wire, {(ADDR_SIZE) {1'b0}}};
  assign m_axi_awlen = 4'd15;
  assign m_axi_awsize = ADDR_SIZE;
  assign m_axi_awburst = 2'b01;
  assign m_axi_awcache = 4'b0110;
  assign m_axi_awvalid = int_awvalid_reg;
  assign m_axi_wid = int_awid_reg;
  assign m_axi_wdata = int_wdata_wire;
  assign m_axi_wstrb = {(M_AXI_DATA_WIDTH / 8) {1'b1}};
  assign m_axi_wlast = int_wlast_wire;
  assign m_axi_wvalid = int_wvalid_reg;
  assign m_axi_bready = 1'b1;
  //
  assign s_axis_tready = int_tready_wire;

endmodule
