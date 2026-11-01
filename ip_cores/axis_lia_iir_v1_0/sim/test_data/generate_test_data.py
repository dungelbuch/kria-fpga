"""Generate the test vectors for the IIR testbench (axis_lia_iir_tb.vhd).

Headless version of sim/sim_setup.py without the rp package and plots: writes the mixed I/Q
input data and the filter coefficients as they are loaded into the IIR registers.
"""

from pathlib import Path
import numpy as np
from scipy.signal import butter, cheby1, cheby2


def write_file(values: np.ndarray, filename: Path):
    """Write values as 8 character hex strings, one per line."""
    with open(filename, "w") as file:
        for value in values:
            s = int(value)
            # convert to two's complement
            if s < 0:
                s = (1 << 32) + s
            file.write(f"{s:08X}\n")


def calc_iir_coeffs(order: int, fc: float, fs: float, filt_type: str, attn_db: float) -> np.ndarray:
    """Calculate the second order sections of a low pass IIR filter."""
    if filt_type == "butter":
        return butter(order, fc, fs=fs, output="sos")
    if filt_type == "cheby1":
        return cheby1(order, attn_db, fc, fs=fs, output="sos")
    if filt_type == "cheby2":
        return cheby2(order, attn_db, fc, fs=fs, output="sos")
    raise ValueError(f"Unknown filter type {filt_type}")


def write_coeff_file(coeff: np.ndarray, coeff_width: int, frac_width: int, num_regs: int, filename: Path):
    """Write the register contents: number of sections, then b0 b1 b2 a1 a2 of each section."""
    regs = [len(coeff)]
    for sos in coeff:
        # skip a0 coefficient
        for value in np.delete(sos, 3):
            s = round(value * 2**frac_width)
            # convert to two's complement
            if s < 0:
                s = (1 << coeff_width) + s
            regs.append(s)
    if len(regs) > num_regs:
        raise ValueError(f"{len(coeff)} sections need {len(regs)} registers, only {num_regs} available")
    regs += [0] * (num_regs - len(regs))
    write_file(np.array(regs), filename)


################################################################################
# Main
################################################################################
# Signal, SAMPLE_RATE_DIV and N_SAMPLES must match sample_rate_div and tv_depth of the testbench
CLK_MHZ = 125        # Testbench clock (aclk_period = 8 ns)
SAMPLE_RATE_DIV = 10
FS = CLK_MHZ * 1e6 / SAMPLE_RATE_DIV
F_SIG = 125e3        # Signal frequency
PHASE = 0            # Signal phase in degree
NOISE = 0            # Standard deviation of the added noise
N_SAMPLES = 10000
REF_RESOLUTION = 14

# Filter, COEFF_BITS, FRAC_BITS and NUM_REGS must match the testbench generics
F_CUTOFF = 50e3
FILTER_ORDER = 2
FILTER_TYPE = "butter"
ATTN_DB = 60
COEFF_BITS = 25
FRAC_BITS = 23
NUM_REGS = 32

t = np.arange(N_SAMPLES) / FS
rng = np.random.default_rng(0)
sig_noise = np.sin(2 * np.pi * F_SIG * t + np.deg2rad(PHASE)) + rng.normal(0, NOISE, N_SAMPLES)
I = sig_noise * np.sin(2 * np.pi * F_SIG * t)
Q = sig_noise * np.cos(2 * np.pi * F_SIG * t)

out_dir = Path(__file__).parent
write_file((2**REF_RESOLUTION - 1) * I, out_dir / "i_data.tv")
write_file((2**REF_RESOLUTION - 1) * Q, out_dir / "q_data.tv")

coeff = calc_iir_coeffs(FILTER_ORDER, F_CUTOFF, FS, FILTER_TYPE, ATTN_DB)
write_coeff_file(coeff, COEFF_BITS, FRAC_BITS, NUM_REGS, out_dir / "iir_coeff_data.tv")
