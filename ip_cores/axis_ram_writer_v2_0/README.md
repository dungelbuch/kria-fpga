
# RAM Writer
This module writes stores incoming data inside a synchronous FIFO and writes the stored data in a burst, once the threshold of (16 x 32 bits) has been crossed. Tests with the Red Pitaya's maximum sample rate of 125 MS/s have shown that the FIFO will not get full, during continuous writing. It is worth mentioning that the data bus connected from this module to the PS is 64 bit wide, which means that the module will send 2 samples at a time and the address offset will increase by 8 at the same time.

**KR260:** In this project the module runs on `PL_CLK_FREQ` (100 MHz) and its 64-bit
`M_AXI` port is connected to the PS port `S_AXI_HP0_FPD`, which gives it access to the
lower 2 GB of DDR (see [src/bd/kr260_ps.tcl](../../src/bd/kr260_ps.tcl)). The streaming
results, the memory limits, the Alpine Linux and CMA setup, and the C and Python
examples below are from the Red Pitaya project this core was ported from. The linked
C sources and Linux patches are not part of this repository. There is no testbench for
this core.

## Streaming Test Result

Continuous streaming of data via TCP/IP cen be done for an indefinite amount of time can be archived with a sample rate of 17,8 MSps. Streaming with 20,8 MSps is archiveable for a longer period (undetermined), but due to the fact that the Red Pitaya is working at it's limits here, data integrity while streaming continuously is not garanteed. **17,8 MSps is the safest option when it comes to streaming data!**

## Generic Map

| Generic Name           | Type    |Default Value | Description |
|------------------------|---------|--------------|-------------|
| RESET_WIDTH            | Integer | 0            | Width of reset vector. |
| RESET_INDEX            | Integer | 0            | Index of module reset. |
| STS_DATA_WIDTH         | Integer | 32           | Width of status register, which contains the offset from the base address. |
| CFG_DATA_WIDTH         | Integer | 32           | Width of config register, which contains the base address. |
| M_AXI_ID_WIDTH         | Integer | 6            | Width of AXI Lite ID bus. |
| M_AXI ADDR_WIDTH       | Integer | 32           | Width of AXI master address bus (IP -> PS).|
| M_AXI_DATA_WIDTH       | Integer | 64           | Width of AXI master data bus (IP -> PS). |
| AXI_ADDR_WIDTH         | Integer | 6            | Width of AXI slave address bus (PS -> IP). |
| AXI_DATA_WIDTH         | Integer | 32           | Width of AXI slave data bus (PS -> IP). |
| S_AXIS_TDATA_WIDTH     | Integer | 32           | Width of AXI stream slave data bus (ADC -> IP). |
| FIFO_WRITE_DEPTH       | Integer | 1024         | Depth of internal FIFO, 32 bit wide. |


## Port Map

| Port Name     | Type            |Description |
|---------------|-----------------|------------|
| alck          | In              | System clock port. |
| rstn[n]       | In (active low) | Module reset port, signal selection via RESET_INDEX generic. |
| M_AXI         | AXI Lite        | AXI Lite master ports: Sending data to PS for writing it into memory. |
| S_AXI         | AXI Lite        | AXI Lite slave ports: Allows modification of internal slave registers. |
| S_AXIS        | AXI Stream      | AXI Stream slave ports: Receiving data from ADC or data generator IP. |

## Register Map

| Offset Address | Register Name  | Bit Assignment | Access | Initial Value | Description |
|----------------|----------------|----------------|--------|---------------|-------------|
| 0x00           | CFG_DATA       | [31:0] | hro/srw | 0x0 | Holds the RAM's base address. |
| 0x04           | STS_DATA       | [31:0] | hro/srw | 0x0 | Holds the RAM writer's current address offset (8 bytes / offset).|
| 0x08           | BLOCK_MODE_EN  | [0]    | hro/srw | 0x0 | Enable block mode (0x1) or stay in continuos mode (0x0). |
| 0x0C           | STS_WIDTH_MASK | [31:0] | hro/srw | 0x0 | Hold the value which determines the width of address offset stored inside STS_DATA register. |

## How To Use

This applies to the C-code not Python code.

1. Deassert the reset signal and hold it to deactivate the RAM Writer.
2. Initialize the RAM by calling the [**InitRAM**](../../c_src/rp_ram.c) method, with the disired value written into the STS_WIDTH_MASK register. Which determine the addressable range of memory. E.g. a width mask of 24 bits (0xFFFFFF) will result in a addressable range of 128MB, which currently is the maximum of the Red Pitaya linux system.
    - 24 Bits -> $2^{24}$ = 16777216 possible offset.
    - Each offset contains 2 samples -> $2^{24} \cdot 2 = 33554432$
    - Each sample is 4 bytes -> $2^{24} \cdot  2  \cdot 4 = 134217728$
3. During the RAM's initialization the requested memory size will be allocated and it's base address will be stored inside the CFG_DATA register, and the STS_DATA register will be set to zero upon enabling the RAM Writer.
4. Set the RAM Writer's mode of operation to **block mode** by setting the BLOCK_MODE_EN register to 0x1, or **continuous mode** with 0x0 (which is the default mode).
5. Enable the RAM Writer by asserting the reset signal.

### Customize Memory Size For Alpine Linux

Since the Red Pitaya only has 512MB of usable memory and Alpine Linux already use a big amount of it. The maximum amount of allocatable memory is 128MB at the moment. In the table below are the STS width and the corresponding amount of addressable momory listed:

| STS Width | Memory Size | No. of Samples |
|-----------|-------------|----------------| 
| 13        | 64KB        | 16384          |
| 14        | 128KB       | 32768          |
| 15        | 256KB       | 65536          |
| 16        | 512KB       | 131072         |
| 17        | 1MB         | 262144         |
| 18        | 2MB         | 524288         |
| 19        | 4MB         | 1048576        |
| 20        | 8MB         | 2097152        |
| 21        | 16MB        | 4194304        |
| 22        | 32MB        | 8388608        |
| 23        | 64MB        | 16777216       |
| 24        | 128MB       | 33554432       |

The Red Pitaya uses a custom [**contiguous memory allocator (cma)**](../../build_src/linux/patches/linux/cma.c) that required us to reduce the amount of RAM access accessible to Linux and to use a memory block at the and of the RAM address range as a buffer. To modify the accessible amount of RAM to Linux, we have to modify [devicetree patch file](../../build_src/linux/patches/devicetree/devicetree.patch).

```
 	memory {
 		device_type = "memory";
-		reg = <0x0 0x20000000>;
+		reg = <0x0 0x18000000>;
 	};
```

This section within the patchfile marks the end of the accessible RAM for Alpine Linux and is set to 512MB (0x20000000) as default. To ensure that the correct amount of memory is available we need to replace it with a lower memory address. In the code example above the maximum address for the Linux OS is set to 0x18000000, which gives us 128MB of memory (0x20000000 - 0x18000000 = 134217728 bytes). Depending on how much RAM the Linux OS might use in the future, you might need to lower the addressable memory range for the RAM Writer. Another file that needs to be modified is the [uEnv.txt](../../build_src/linux/alpine/uEnv.txt) file. Previously the cma value in this file was set to cma=36M, which is 4M(B) more than the than maximum allocatable memory of 32MB (unknown reason). Currently the value is set to cma=132M, which follows the same convention. If you ever need to change this value, please follow the same convention.

## Python Example

```python
from rp.core import RedPitayaBoard
from rp.ram.config import get_ram_config, RAM_SIZE
from rp.constants import RAM_INIT_CONFIG_ID

# Connect to Red Pitaya
pita = RedPitayaBoard()

# Create Struct to init RAM with 8MB size
# Other sizes: .MB_16,.MB_32,.MB_64,.MB_128
ram_size = RAM_SIZE.MB_8
ramCfg = get_ram_config(ram_size_MB = ram_size)

# initalizes RAM allocation 8 MB of RAM
pita.sendConfigParams(ramCfg, RAM_INIT_CONFIG_ID)

```
