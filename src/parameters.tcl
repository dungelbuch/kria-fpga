# Parameters used by the block design and the IP core packaging scripts.
#
# When adding an IP core with a reset input (rstn), give it a new RESET_INDEX and raise
# RESET_WIDTH to the highest index + 1. When adding an AXI slave, pick a base address that
# does not overlap the existing ranges.

proc clog2 {x} {
    return [expr {int(ceil(log($x) / log(2)))}]
}

# Fabric clock from the PS (pl_clk0) in MHz
set PL_CLK_FREQ 100

set AXI_SLAVE_RANGE 4K
# 16k 32-bit values in BRAM => 64K
set BRAM_AXI_RANGE 64K
set BRAM_AXI_DEPTH 16384
set BRAM_AXI_WIDTH 32
set BRAM_AXI_CTRL_ADDR_WIDTH [clog2 [expr {$BRAM_AXI_DEPTH * $BRAM_AXI_WIDTH / 8}]]
set BRAM_AXI_ADDR_OFFSET [clog2 [expr {$BRAM_AXI_WIDTH / 8}]]

# Number of modules connected to the rstn vector
set RESET_WIDTH 2
# Reset indices of the user IP cores within the rstn vector
set RESET_INDEX_DUMMY_DATA_GEN 0
set RESET_INDEX_RAM_WRITER 1

# AXI base addresses, all within the M_AXI_HPM0_FPD window (0xA000_0000 - 0xAFFF_FFFF)
# System
set AXI_BASE_ADDR_GPIO_RSTN 0xA0000000
set AXI_BASE_ADDR_GPIO_LEDS 0xA0001000
# Dummy data generator
set AXI_BASE_ADDR_DUMMY_REGS 0xA0010000
set AXI_BASE_ADDR_DUMMY_BRAM 0xA0020000
# RAM writer
set AXI_BASE_ADDR_RAM_WRITER 0xA0030000
