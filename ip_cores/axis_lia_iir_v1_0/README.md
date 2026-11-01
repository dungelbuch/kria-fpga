# Infinite Impulse Response Filter (Fixed-Point)

The Infinite Impulse Response (IIR) filter is a digital filter designed to
attenuate unwanted frequencies from an input signal. The filters uses feedback,
meaning their output depends on both the current and previous input and output
values. This filter implementation is based on the Second-Order Sections (SOS)
or Biquads structure, which breaks down the filter into smaller, more manageable
sections. It also uses fixed-point arithmetic to represent the filter
coefficients and input/output signals. This document provides an overview of the
IIR filter's architecture, design, and implementation details.



## Generic Map

| Generic Name             | Type    |Default Value | Description |
|--------------------------|---------|--------------|-------------|
| reset_index              | Integer | None         | Reset vector's index within associated with this core's reset signal. |
| reset_width              | Integer | None         | Width of connected reset vector, dependent on number of IP cores. |
| s_axi_data_width         | Integer | 32           | Width of AXI-Lite data bus. |
| s_axi_addr_width         | Integer | 6            | Width of AXI-Lite address bus, determine the amount of slave registers. |
| s_axis_tdata_width       | Integer | 32           | Width of AXI-Stream input data bus. |
| m_axis_tdata_width       | Integer | 32           | Width of AXI-Stream output data bus. |
| iir_coeff_width          | Integer | None         | Width of IIR filter coefficients. |
| iir_coeff_frac_width     | Integer | None         | Width of IIR filter coefficients fractional part. |
| iir_sos_stages           | Integer | 1            | Number of Second-Order Sections (SOS) in the IIR filter. |


## Port Map

| Port Name           | Type            |Description |
|---------------------|-----------------|------------|
| aclk                | In              | System clock port. |
| rstn[n]             | In (active low) | Module reset port, signal selection via RESET_INDEX generic. |
| s_axi_aresetn       | In              | AXI reset port, toggled once at system start. |
| s_axi_iir           | AXI-Lite        | AXI-Lite slave: Allows modification of the filters internal registers. |
| s_axis_i            | AXI-Stream      | AXI-Stream input port: Inphase signal input. |
| s_axis_q            | AXI-Stream      | AXI-Stream output port: Quadrature signal input. |
| m_axis              | AXI-Stream      | AXI-Stream output port: Filtered signal output, output alternates between inphase and quadrature. |

## Register Map

This IIR filter module supports a total of 32 registers. These registers are organized as follows:

1. **sos_mux** (1 register):
   - This register is reserved to selects the output of a specific SOS stage to be used as the filter output.

2. **Filter Coefficients Registers** (30 registers):
   - The next 30 registers are used to store the filter coefficients for the SOS stages. Each **SOS stage** requires five registers to store the necessary coefficients:
     - 3 registers for the **feedforward coefficients** (`b0`, `b1`, `b2`).
     - 2 registers for the **feedback coefficients** (`a1`, `a2`).

   This arrangement supports a **maximum of 6 SOS stages** (order 12), and a **minimum of 1 SOS stage** (order 2).

3. **Unused Register** (1 register):
   - The last register is currently unused and reserved for **future expansion**.

| Offset Address | Register Name | Bit Assignment | Access | Initial Value | Description |
|----------------|---------------|----------------|--------|---------------|-------------|
| 0x00 | sos_mux | [31:0] | hro/srw | 0x0 | Select which SOS output to use as the filter output. The lowest amount of stages is 1, for a single SOS. |
|||||||
| 0x04 | b0_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 0. |
| 0x08 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 0. |
| 0x0C | b2_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 0. |
| 0x10 | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 0. |
| 0x14 | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 0. |
|||||||
| 0x18 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 1. |
| 0x1C | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 1. |
| 0x20 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 1. |
| 0x24 | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 1. |
| 0x28 | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 1. |
|||||||
| 0x2C | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 2. |
| 0x30 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 2. |
| 0x34 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 2. |
| 0x38 | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 2. |
| 0x3C | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 2. |
|||||||
| 0x40 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 3. |
| 0x44 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 3. |
| 0x48 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 3. |
| 0x4C | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 3. |
| 0x50 | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 3. |
|||||||
| 0x54 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 4. |
| 0x58 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 4. |
| 0x5C | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 4. |
| 0x60 | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 4. |
| 0x64 | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 4. |
|||||||
| 0x68 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b0 for SOS 5. |
| 0x6C | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b1 for SOS 5. |
| 0x70 | b1_0    | [31:0] | hro/srw | 0x0 | Coefficient b2 for SOS 5. |
| 0x74 | a1_0    | [31:0] | hro/srw | 0x0 | Coefficient a1 for SOS 5. |
| 0x78 | a2_0    | [31:0] | hro/srw | 0x0 | Coefficient a2 for SOS 5. |
|||||||
| 0x7C | -       | [31:0] | hro/srw | 0x0 | Empty register |



## Filter Architecture

The **Second-Order Sections (SOS)** or **Biquads** structure is a common
structure used to implement IIR filters, especially in digital signal processing
applications using fixed-point arithmetic. The SOS structure breaks down the
filter into smaller, more manageable sections, each representing a second-order
filter. This structure is beneficial for several reasons:

- **Numerical stability**: The SOS structure is more stable than a direct form
  implementation, as it reduces the likelihood of numerical errors and
  quantization noise.
- **Efficient implementation**: The SOS structure requires fewer resources than
   a direct form implementation, making it suitable for FPGA-based designs.
- **Ease of design**: The SOS structure simplifies the design process by
   allowing the filter to be broken down into smaller, more manageable sections.
   And by cascading these sections, a higher-order filter can be implemented
   with ease.

```

   x[n] ------------| b0 >---->(+)---------------------> y[n]
              |                 ^                |
              |                 |                |
              V               [Z^-1]             V
              |                 |                |
              |                 |                |
              |-----| b1 >---->(+)<----< a1 |----|
              |                 ^                |
              |                 |                |
              |               [Z^-1]             |
              |                 |                |
              |                 |                |
              |-----| b2 >---->(+)<----< a2 |----|

```

The Filter is intended to be used as a variable order IIR filter, so that a
redesign of the filter is not necessary when the order of the filter is changed.
For that the SOS sections are fixed at a chosen number and cascaded to form the
desired maximum order. To change the order of the filter, a multiplexer is used
to select the output of a specific SOS stage to be used as the filter output. As
illustrated in the example below, with 3 SOS stages.

```
Input ------------>[SOS 0]----->[SOS 1]----->[SOS 2]---        ___
                            |            |            |       |   \
                            |            |            |------>|    \
                            |            |                    |     |
                            |            |------------------->| MUX |---> Output
                            |                                 |     |
                            |-------------------------------->|    /
                                                              |___/
```



### Filter Coefficients

The FIR filter is designed as a fixed-point filter because the input is a 32-bit
fixed-point value (Q32.0). Consequently, the filter coefficients must also be in
fixed-point format. These coefficients are initially generated as floating-point
values using a Python function and then converted to fixed-point through a
process known as quantization.

Quantization introduces errors, which can be mitigated by increasing the number
of bits used to represent the coefficients. However, increasing the bit width
comes with trade-offs, as it raises the FPGA resource usage, particularly the
number of DSP slices required for multiplication. The Red Pitaya's FPGA uses
DSP48E1 slices, which have a maximum input width of 25x18 bits. For more
details, see the [DSP48E1 Documentation](https://docs.amd.com/v/u/en-US/ug479_7Series_DSP48E1).

Through experimentation, the optimal bit width for the filter coefficients was
determined to be 25 bits. This bit width balances precision and resource usage.
The 32-bit input signal is distributed across two DSP slices, with 16 bits
feeding the 18-bit input of the first slice and the remaining 16 bits feeding
the same input of the second slice. The 25-bit input of the DSP slices is
reserved for the filter coefficients. Exceeding 25 bits increases the number of
DSP slices required, which is resource-intensive. It was also observed that 25
bits provide sufficient precision to represent the filter coefficients. Since
FIR filter coefficients fall within the range [-2, 2], only the most significant
bit (MSB) is used as the sign bit, with the remaining bits representing the
fractional part. This results in a **Q2.23 fixed-point format** for the
coefficients.


### Truncating the Filter Output

Since the filter output is expected to be a 32-bit fixed-point value, the output
of the filter must be truncated to fit this format. In this version the internal
output contains an  integer part and a fractional part. First the fractional part
need to be removed and then the integer part needs to be resized to fit the 32
bit output.


```
# Original Output
-----------------------------------------------------------
|       x-bit Integer part       |  y-bit Fractional part |
-----------------------------------------------------------

# Shift Right by y bits to remove the fractional part
                         ----------------------------------
 y-bits shift  ------>   |       x-bit Integer part       |
                         ----------------------------------

# Resize the integer part to fit the 32-bit output
                       ------------------------------------
       Resize  ------> |        32-bit Integer part       |
                       ------------------------------------
```



## Filter Simulation and Design

To simulate the filter and generate coefficients, a python script is used and
can be accessed as a [jupyter notebook](./sim/iir_design.ipynb). This allows
us to use sliders to adjust the filter parameters and observe the filter's
behaviour in a graphical manner. The notebook, [sim_setup.py](./sim/sim_setup.py)
and [test_filter_calc.py](./sim/test_filter_calc.py) need the `rp` Python
package from the RedPitaya-LIA repository this core was ported from, which is not
part of this repository. To only generate the test vectors, use the script
described in [Simulation in Vivado](#simulation-in-vivado).

The notebook is divided into three sections:
- Input Signal Generation
- Filter Simulation and Coefficient Generation
- Filter Coefficient Quantization and Generating .coe file

### Input Signal Generation

To simulate the filter, an input signal is required. The input signal can be
configured to match the desired frequency, amplitude, and noise characteristics.
To simulate the Red Pitaya's ADC, the sampling rate is adjustable, and the
number of samples can be set to define the signal's duration. Once you
are satisfied with the input signal, you can toggle the "write_file" option to
save it to a file. For the Inphase and Quadrature signals, the data will be
saved into separate files [i_data.tv](./sim/test_data/i_data.tv) and
[q_data.tv](./sim/test_data/q_data.tv) respectively. These files will be used as
the input for the filter simulation in Vivado.

### Filter Simulation and Coefficient Generation

After generating the test input signal, the next step is to configure the filter
settings:

- **`f (Hz)`**: The signal of interest's frequency or the frequency of the reference
  signal.
- **`fs (Hz)`**: The sampling frequency of the input signal.
- **`fc (Hz)`**: The cutoff frequency of the filter.
- **`N`**: The filter order, which determines the number of SOS stages.
- **`coeff_bits`**: The number of bits used to represent the filter
  coefficients.
- **`frac_bits`**: The number of fractional bits used to represent the fractional part of the filter coefficients.
- **`sig_period`**: Defines how many periods of the signal should be shown in the filtered signal plot.

The plots in the first row display the filter's parameters, including the filter coefficients and frequency response. The second row shows an overlay of the input signal and the filtered signal, showcasing the filter's performance based on the chosen parameters.


### Filter Coefficient Quantization and Generating .coe File

The filter parameters from the previous step are carried over to this section
and do not require further modification. Simply execute this cell to save the
coefficients to a file, which will be saved at this
[location](./sim/test_data/iir_coeff_data.tv). This specific location is
important because the testbench reads the coefficients from it. In hardware,
the coefficients are written into the registers by software.

## Simulation in Vivado

The [testbench](./sim/axis_lia_iir_tb.vhd) runs two testcases:

1. It writes the 32 registers from `sim/test_data/iir_coeff_data.tv` via AXI,
   feeds the I and Q test vectors `sim/test_data/i_data.tv` and
   `sim/test_data/q_data.tv` into the filter, one sample every `sample_rate_div`
   (10) clock cycles, and writes the filter output to
   `sim/test_data/filt_sim_data.res` (I and Q alternating).
2. It sends an impulse to show the delay between input and output data and of
   the tvalid signal.

The testbench is not self-checking. Check the output in the waveform, for
example with [axis_lia_iir_filter_behav.wcfg](./sim/axis_lia_iir_filter_behav.wcfg),
or plot the logged output:

```
cd ip_cores/axis_lia_iir_v1_0/sim/test_data
../../../../.venv/bin/python analyze_filt_data.py
```

Generate the test vectors and coefficients without the notebook:

```
.venv/bin/python ip_cores/axis_lia_iir_v1_0/sim/test_data/generate_test_data.py
```

By default this writes 10000 samples of a 125 kHz sine at 12.5 MSPS, mixed with
the sine and cosine reference, and the coefficients of a 2nd order Butterworth
low pass at 50 kHz with 25-bit coefficients and 23 fractional bits. The
parameters at the bottom of the script must match the testbench generics
(`sample_rate_div`, `tv_depth`, `iir_coeff_width`, `iir_coeff_frac_width`,
`num_regs`).

Then run `make sim-cores` and the simulation as described in the
[main README](../../README.md#simulation). The testbench clock is 125 MHz
(8 ns), independent of `PL_CLK_FREQ`.

The second order sections use the Xilinx multiplier IP `multiplier`
(mult_gen, 25 x 32 bit), which is created in [core_ext.tcl](./core_ext.tcl)
for both packaging and simulation.


## Future Improvements

This version of the IIR filter does not provide any mechanism to avoid overflow
or saturation of the filter output. This might cause issues and leads to the
filter to produce incorrect results. If you happen to encounter issues with the
filter performance, consider implementing overflow and saturation detection
mechanisms.
