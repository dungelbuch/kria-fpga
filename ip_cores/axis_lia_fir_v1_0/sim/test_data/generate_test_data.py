"""Generate the test vectors for the FIR testbench (axis_lia_fir_tb.vhd).

Headless version of the signal cell in coeff/fir_design.ipynb: a noisy sine is mixed with the
sine (I) and cosine (Q) reference and written as 32-bit two's complement hex values.
"""

from pathlib import Path
import numpy as np


def write_file(values: np.ndarray, filename: Path):
    """Write values as 8 character hex strings, one per line."""
    with open(filename, "w") as file:
        for value in values:
            s = int(value)
            # convert to two's complement
            if s < 0:
                s = (1 << 32) + s
            file.write(f"{s:08X}\n")


################################################################################
# Main
################################################################################
FS = 12.5e6          # Sample rate, clock / sample_rate_div of the testbench
F_SIG = 125e3        # Signal frequency
PHASE = 0            # Signal phase in degree
PERIODS = 1000       # Number of signal periods to generate
NOISE = 0.1          # Standard deviation of the added noise
TV_DEPTH = 2000      # Number of samples written, tv_depth of the testbench

samples = int(FS / F_SIG) * PERIODS
t = np.arange(samples) / FS

rng = np.random.default_rng(0)
sig_noise = np.sin(2 * np.pi * F_SIG * t + np.deg2rad(PHASE)) + rng.normal(0, NOISE, samples)
sin_ref = np.sin(2 * np.pi * F_SIG * t)
cos_ref = np.cos(2 * np.pi * F_SIG * t)

out_dir = Path(__file__).parent
write_file((sig_noise * sin_ref)[:TV_DEPTH] * 2**16 - 1, out_dir / "i_data.tv")
write_file((sig_noise * cos_ref)[:TV_DEPTH] * 2**16 - 1, out_dir / "q_data.tv")
