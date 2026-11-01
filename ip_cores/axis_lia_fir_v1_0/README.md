# Finite Impulse Response Filter (Fixed-Point)

The **Finite Impulse Response (FIR) filter** is a digital fixed-point filter
designed to attenuate unwanted frequencies from an input signal. The filter
operates by applying a series of coefficients to the input signal, multiplying
them,  and summing the results to produce the output signal. This FIR filter is
implemented using the [Xilinx FIR Compiler v7.2](https://www.xilinx.com/support/documents/ip_documentation/fir_compiler/v7_2/pg149-fir-compiler.pdf).
The filter configuration details are specified in the file
[core_ext.tcl](./core_ext.tcl). This document provides an overview of the FIR
filter architecture, the filter coefficients, and the simulation and design.


## Generic Map

| Generic Name             | Type    |Default Value | Description |
|--------------------------|---------|--------------|-------------|
| reset_index              | Integer | None         | Reset vector's index within associated with this core's reset signal. |
| reset_width              | Integer | None         | Width of connected reset vector, dependent on number of IP cores. |
| s_axi_data_width         | Integer | 32           | Width of AXI-Lite data bus. |
| s_axi_addr_width         | Integer | 6            | Width of AXI-Lite address bus, determine the amount of slave registers. |
| s_axis_tdata_width       | Integer | 32           | Width of AXI-Stream input data bus. |
| m_axis_tdata_width       | Integer | 32           | Width of AXI-Stream output data bus. |
| fir_coeff_width          | Integer | 25           | Width of FIR filter coefficients. |
| fir_coeff_frac_width     | Integer | 24           | Width of FIR filter coefficients fractional part. |
| fir_out_width            | Integer | 64           | Width of internal FIR filter output wire, this does not affect the actual output width. |


## Port Map

| Port Name           | Type            |Description |
|---------------------|-----------------|------------|
| aclk                | In              | System clock port. |
| rstn[n]             | In (active low) | Module reset port, signal selection via RESET_INDEX generic. |
| s_axi_aresetn       | In              | AXI reset port, toggled once at system start. |
| s_axi_fir           | AXI-Lite        | AXI-Lite slave: Allows modification of the filters internal registers. |
| s_axis_i            | AXI-Stream      | AXI-Stream input port: Inphase signal input. |
| s_axis_q            | AXI-Stream      | AXI-Stream output port: Quadrature signal input. |
| m_axis              | AXI-Stream      | AXI-Stream output port: Filtered signal output, output alternates between inphase and quadrature. |

## Register Map

In this implementation of the FIR filter, internal registers are omitted because
the filter coefficients are fixed and no additional control or reconfiguration
is required. The AXI-Lite port `s_axi_fir` exists, but the register slave
`axis_lia_fir_slave.vhd` is not instantiated, so writes and reads have no effect.


## Filter Architecture

The **Direct Form FIR filter** is the simplest FIR filter architecture. It
consists of a series of multipliers and adders, as illustrated in the figure
below:



```
   x[n] ---------->[z^-1]--------->[z^-1]---------> ... --->[z^-1]---
            |               |               |                       |
            |               |               |                       |
   h[0] -> (X)     h[1] -> (X)     h[2] -> (X)             h[n] -> (X)
            |               |               |                       |
            |               |               |                       |
           (+)------------>(+)------------>(+)----> ... ---------->(+)---> y[n]

```


While conceptually straightforward, the Direct Form FIR filter is not the most
efficient architecture for FPGA implementations due to its high resource
requirements, stemming from the large number of multipliers and adders. To
address this, a **symmetric FIR filter architecture** is often used. This
architecture takes advantage of the symmetry of filter coefficients to reduce
the number of multipliers and adders by half, using a pre-adder before
multiplying with the coefficients. The structure is shown below:



```
   x[n] ---------->[z^-1]--------->[z^-1]--------->[z^-1]-----------
            |                 |               |                    |
            |                 |               |                    V
            |      [z^-1]<---------[z^-1]<---------[z^-1]<----------
            |         |       |       |       |       |          |
            |         |       |       |       |       |          |
            -->(+)<----       -->(+)<--       -->(+)<--          |
                |                 |               |              |
                |                 |               |              |
       h[0] -> (X)       h[1] -> (X)     h[2] -> (X)    h[3] -> (X)
                |                 |               |              |
               (+)-------------->(+)------------>(+)----------->(+)---> y[n]

```


The use of a symmetric architecture imposes a design constraint: the filter
coefficients must be symmetric about the center coefficient. Consequently, the
number of coefficients must be odd. However, this constraint offers several
benefits:

- **Reduced resource usage**: The number of multipliers and adders is halved, making it more efficient for FPGA implementations.
- **Linear phase response**: The filter does not introduce phase distortion to the input signal.
- **Improved numerical stability**: The reduced number of operations makes the filter less sensitive to quantization errors.

By leveraging these advantages, the symmetric FIR filter architecture is well-suited for efficient FPGA-based implementations.


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
FIR filter coefficients fall within the range [-1, 1], only the most significant
bit (MSB) is used as the sign bit, with the remaining bits representing the
fractional part. This results in a **Q1.24 fixed-point format** for the
coefficients.

### Fixed Sample Rate

Even with the symmetric FIR filter architecture, to archive the desired filter
performance is often not possible, since the FPGA's resources are limited. To
enable the implementation of a filter, it might be necessary to reduce the
sample rate of the input signal, allowing the filter to carry out mathematical
operations between samples. This architecture that takes advantage of this is
called the **Systolic_Multiply_Accumulate** architecture, and is enabled in the
[core_ext.tcl](./core_ext.tcl) file, in which the fixed sample rate can be set.


### Truncating the Filter Output

Adding and multiplying the input signal with the filter coefficients produces a
64-bit output signal. This is a consequence of the Xilinx FIR filter design,
even though the inputs are 32x25 bits. The output signal is truncated to 32 bits
by removing the fractional bits and the upper integer bits, leaving only the
relevant 32 bits of the output signal, as illustrated below. For more details,
refer to the bit growth rules for integer and fractional parts in fixed-point
arithmetic.


```
# Original Output
-----------------------------------------------------------
|       40-bit Integer part      | 24-bit Fractional part |
-----------------------------------------------------------

# Truncated Output

-------------                    --------------------------
|   8-bit   |                    | 24-bit Fractional part |
-------------                    --------------------------
                      |
                      |
                      V
             --------------------
             |   32-bit Output  |
             --------------------
```

## Filter Simulation and Design

To simulate the filter and generate coefficients, a python script is used and
can be accessed as a [jupyter notebook](./coeff/fir_design.ipynb). This allows
us to use sliders to adjust the filter parameters and observe the filter's
behaviour in a graphical manner. The notebook needs the `rp` Python package from
the RedPitaya-LIA repository this core was ported from, which is not part of
this repository.

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
save it to a file. This file can then be used to test the filter in Vivado.

### Filter Simulation and Coefficient Generation

After generating the test input signal, the next step is to configure the filter settings:

- **`order`**: The filter order determines the number of coefficients (taps) used. Since the FIR filter is symmetric, the order must be odd. The script automatically adjusts the order by increasing it by one if an even number is provided.
- **`fc (Hz)`**: The cutoff frequency of the filter.
- **`window`**: Select either the Hamming or Blackman window function for calculating the filter coefficients.
- **`quantization`**: Set to True or False. If False, the filter coefficients in the simulation are of type `float32`. If True, the coefficients are quantized with the number of bits specified in the `quant_bits` option. This simulates the filter's behavior under quantization losses.
- **`plot_period`**: Defines how many periods of the signal should be shown in the filtered signal plot.

The plots in the first row display the filter's parameters, including the filter coefficients and frequency response. The second row shows an overlay of the input signal and the filtered signal, showcasing the filter's performance based on the chosen parameters.


### Filter Coefficient Quantization and Generating .coe File

The filter parameters from the previous step are carried over to this section
and do not require further modification. Simply execute this cell to save the
coefficients to a file, which will be saved at this [location](./coeff/fir.coe).
This specific location is important because [core_ext.tcl](./core_ext.tcl)
loads it into the FIR Compiler, both when packaging the core and when creating
the simulation project. Run `make cores` or `make sim-cores` afterwards to pick
up the new coefficients.

The FIR Compiler is configured for the clock `PL_CLK_FREQ` from
[src/parameters.tcl](../../src/parameters.tcl) and expects one input sample every
`FIR_SAMPLE_RATE_DIV` (10) clock cycles, set in [core_ext.tcl](./core_ext.tcl).
On the KR260 this is 100 MHz clock and 10 MSPS.

## Simulation in Vivado

The [testbench](./sim/axis_lia_fir_tb.vhd) feeds the I and Q test vectors
`sim/test_data/i_data.tv` and `sim/test_data/q_data.tv` into the filter, one
sample every `sample_rate_div` (10) clock cycles. It is not self-checking; inspect
the output in the waveform, for example with
[axis_lia_fir_tb_behav.wcfg](./sim/axis_lia_fir_tb_behav.wcfg).

Generate the test vectors (2000 samples of a noisy 125 kHz sine at 12.5 MSPS,
mixed with the sine and cosine reference) without the notebook:

```
.venv/bin/python ip_cores/axis_lia_fir_v1_0/sim/test_data/generate_test_data.py
```

Then run `make sim-cores` and the simulation as described in the
[main README](../../README.md#simulation). The testbench clock is 125 MHz
(8 ns), independent of `PL_CLK_FREQ`.


## Future Improvements

The current implementation of the FIR filter does not allow for dynamic
reconfiguration of the filter coefficients and new parameters can only be set
during the design phase. Future improvements could include adding an AXI-Lite
interface to allow for real-time reconfiguration of the filter coefficients.
The coefficient reload configuration needs to be enabled in the
[core_ext.tcl](./core_ext.tcl) file. For more details on how to
implement this feature, refer to the [Xilinx FIR Compiler documentation](https://www.xilinx.com/support/documents/ip_documentation/fir_compiler/v7_2/pg149-fir-compiler.pdf).
