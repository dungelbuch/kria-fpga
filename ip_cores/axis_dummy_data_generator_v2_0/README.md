# Dummy Data Generator

This module is created to work together with the [RAM Writer](../axis_ram_writer_v2_0) module. It purpose is to verify the RAM-Writer is working properly under various sampling rates. Once enabled the module will output data with a configurable sample rate. The data is in the range of [0 - CNT_MAX_VALUE] and will be increamented by 1 between each sample.

The module also has an internal BRAM, which is able to hold 16384 samples (32 bit). It can be used to simulate real-time operation, by writing pre-acquired measurement data into the BRAM and sending it out to the device under test.

## Generic Map

| Generic Name            | Type    |Default Value | Description |
|-------------------------|---------|--------------|-------------|
| reset_index             | Integer |              | Reset vector's Index within associated with this core's reset signal. |
| reset_width             | Integer |              | Width of connected reset vector, dependent on number of IP cores. |
| int_data_width          | Integer | 32           | Width of internal data bus. |
| int_bram_depth          | Integer |              | Depth of internal BRAM module. |
| int_bram_ctrl_addr_width| Integer |              | Width of internal BRAM controller module, calculated using $$clogb2(int\_bram\_depth * (int\_data\_width / 8))$$ |
| int_bram_addr_offset    | Integer |              | Address offset between each sample, calculated using $$clogb2(int\_data\_width / 8)$$ |
| int_bram_addr_width     | Integer | 32           | Width of internal BRAM address bus.
| s_axi_data_width        | Integer | 32           | Width of AXI-Lite data bus. |
| s_axi_addr_width        | Integer | 6            | Width of AXI-Lite address bus, determine the amount of slave registers. |
| m_axis_tdata_width      | Integer | 32           | Width of AXI-Stream data bus. |

## Port Map

| Port Name     | Type            |Description |
|---------------|-----------------|------------|
| aclk          | In              | System clock port. |
| rstn[n]       | In (active low) | Module reset port, signal selection via RESET_INDEX generic. |
| s_axi_aresetn | In              | AXI reset port, toggled once at system start. |
| S_AXI         | AXI-Lite        | AXI-Lite slave port: Allows modification of internal slave registers. |
| M_AXIS        | AXI-Stream      | AXI-Stream master ports: Sending data designated for RAM-Writer module. |
| DEBUG_M_AXIS  | AXI-Stream      | AXI-Stream master debug port: When **debug_mode = 0x1** data will be outputted through this port instead of the M_AXIS port. |

## Register Map

| Offset Address | Register Name | Bit Assignment | Access | Initial Value | Description |
|----------------|---------------|----------------|--------|---------------|-------------|
| 0x00 | continuous_mode | [0] | hro/srw | 0x0 | Enable continuous mode (0x1), in this mode the module will ignore the configured max sample and keeps sending data until manually stopped by user, simply set max sample to zero to signal that the module operates in continuous mode. Counter mode (0x0) is the default setting, the module will sending out **max_samples** amount of data. Once finished it will assert the **transaction_done** flag. |
| 0x00 | bram_mode | [1] | hro/srw | 0x0 | Enable BRAM mode (0x1) to output data stored within internal BRAM, otherwise the module will output incremented data (0x0). **continuous_mode** settings will remain valid in this mode. |
| 0x00 | debug_mode | [2] | hro/srw | 0x0 | Select the wether the module outputs data through the default AXIS port (0x0) or through the debug AXIS port (0x1).|
| 0x04 | sample_delay | [31:0] | hro/srw | 0x0 | Gives the delay between two data_valid signals (falling edge <-> rising edge) in clock cycles. |
| 0x08 | cnt_max_samples | [31:0] | hro/srw | 0x0 | The module will count until the maximum value is reached and returns to the initial value of 0. The highest possible value is $2^{32}-1$. |
| 0x0C | max_samples | [31:0] | hro/srw | 0x0 | The module will output the given amount of samples and transition over to the **done** state. **Avoid value "1" when configuring this register, the module will immediately goes into done state!**|
| 0x10 | transaction_done | [0] | hwo/sro | 0x0 | Indicates when the module has finishes sending out data, **this flag can only be asserted when the module is in counter mode (continuous_mode = 0x0)**. |
| 0x14 | bram_max_addr | [31:0] | hro/srw | 0x0 | When writing data into the BRAM this value should be provided to the module, to indicate the valid data range given by the amount of data written. The internal address counter will increment until the given value and returns to 0. If not specifically set, the default setting (0x0) will let the internal address counter increment until the last BRAM address is reached (int_bram_depth) and then returns to 0. Any value that is bigger than the int_bram_depth will be treated as an overflowed value. |


The table below provides the conversion between sample delay and sample rate, given by this formula
$$
\text{f} = \frac{f_{max}}{d}
$$
where $f_{max}$ is the clock frequency of the module, `PL_CLK_FREQ` in
[src/parameters.tcl](../../src/parameters.tcl), 100 MHz on the KR260.

| Sample Delay ($d$) | Frequency ($f$) |
|--------------------|-----------------|
| 1                  | 100 MHz         |
| 2                  | 50 MHz          |
| 3                  | 33.333 MHz      |
| 4                  | 25 MHz          |
| 5                  | 20 MHz          |
| 6                  | 16.667 MHz      |
| 7                  | 14.286 MHz      |
| 8                  | 12.5 MHz        |
| 9                  | 11.111 MHz      |
| 10                 | 10 MHz          |
| 11                 | 9.091 MHz       |

## How to use

This applies to the C-code not Python code.

1. Deactivate the module by deasserting the reset signal, since it's active low.
2. Configure the module by writing into the slave registers.
3. Activate the module by assterting the reset signal. The module will apply the values stored inside the slave registers onto it's internal logic.

## Good To Know

The transaction_done register (signal) will not necessarily work, if the RAM-Writer is operated in **block mode**. The RAM-Writer will stop writing, once the address offset has reached the configured maximum value. The internal FIFO will continue saving incoming data, but will stop after it is full. The RAM-Writer's axis_t_ready signal will be deasserted and this module will stop sending data, thus the transaction_done signal should not be used to identify that the writing process is completed, if block mode is enabled.

## Simulation

The [testbench](sim/axis_dummy_data_generator_v2_0_tb.vhd) is self-checking and
runs 9 testcases: register access, counter mode (maximum counter value, maximum
samples, sample delay, continuous mode), BRAM access via AXI, BRAM continuous and
counter mode, and the debug port. It ends with `Testcases passed: 9/9`.

The BRAM testcases read `sim/test_data/input_data.tv`, 16384 32-bit values with
a sine in the upper and a cosine in the lower 16 bits. Generate it with:

```
.venv/bin/python ip_cores/axis_dummy_data_generator_v2_0/sim/test_data/generate_test_data.py
```

Then run `make sim-cores` and the simulation as described in the
[main README](../../README.md#simulation). The waveform configuration
[axis_dummy_data_generator_v2_0_tb_behav.wcfg](sim/axis_dummy_data_generator_v2_0_tb_behav.wcfg)
shows the relevant signals.

The BRAM testcases are not meant to run with zero sample delay, since some of
the evaluation processes rely on the clock cycles between two samples.

## Python Example

This example is from the Red Pitaya project this core was ported from. It uses
the `rp` Python package, which does not support the KR260.

```python
from rp.core import RedPitayaBoard
from rp.constants import *
from rp.bram.generate import get_bram_struct, gen_sine_cosine
from rp.dummy.config import configure_dummy_data_gen, configure_dummy_data_gen_bram

# Connect to Red Pitaya
pita = RedPitayaBoard()

# Parameters for Dummy Data Generator configuration
MODE = 0b011                # 0b(debug_mode | bram_mode | continuous_mode)
NUM_SAMPLES = 2**28         # 268435456 samples, 4 bytes each sample. Ignored in continuous mode.
SAMPLE_DELAY = 1            # Full speed: 125 MSPs
MAX_CNT = (2**32) - 1       # Highest possible counter value. Ignored in bram mode.
# Create Dummy Data Generator config struct and send to Red Pitaya
configure_dummy_data_gen(pita, MODE, NUM_SAMPLES, SAMPLE_DELAY, MAX_CNT)

# Parameters for BRAM configuration
BRAM_SAMPLES_MAX = 16384    # Maximum amount of samples that can be stored in BRAM
SIG_BIT_RES = 16            # Maximum bit resolution of the signal
PHASE = 0                   # Phase of the signal to be generated
FUNC = gen_sine_cosine      # Function callable to generate the signal
# Create BRAM data struct and send to Red Pitaya
dummyBramCfg = get_bram_struct( FUNC, BRAM_SAMPLES_MAX, SIG_BIT_RES, PHASE)
configure_dummy_data_gen_bram(pita, dummyBramCfg)

```
