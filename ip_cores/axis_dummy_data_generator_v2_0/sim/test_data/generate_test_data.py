import math
from pathlib import Path
import numpy as np
from matplotlib import pyplot as plt


def twos_complement(value: int, bits: int) -> int:
    """Calculate the two's complement of a given value."""
    if value < 0:
        value = (1 << bits) + value
    return value


def generate_sine_cosine_values(num_samples: int, resolution: int = 16) -> np.ndarray:
    """Generate 16-bit signed sine and cosine values."""
    sine = []
    cosine = []
    for i in range(num_samples):
        angle = 2 * math.pi * i / num_samples
        # Scale sine and cosine values to fit into 16-bit signed range
        s = ((2**resolution) / 2) - 1
        sine_scaled = int(math.sin(angle) * s)
        cosine_scaled = int(math.cos(angle) * s)
        sine.append(sine_scaled)
        cosine.append(cosine_scaled)

    return np.array(sine), np.array(cosine)


def write_file_concat(up_val: int, low_val: int, data_len: int, filename: str):
    """Write values into a COE file."""
    shift_len = data_len // 2
    lower_mask = 2**shift_len - 1
    with open(filename, "w") as file:
        for i in range(len(up_val)):
            # Concatenate upper and lower values into a data_len-bit value
            concatenated_value = (up_val[i] << shift_len) | (low_val[i] & lower_mask)
            # Write the concatenated value in hexadecimal format
            hex_value = "{:0{width}X}".format(concatenated_value, width=data_len // 4)
            # write data in this format: h"hex_value"
            file.write(f"{hex_value}\n")


def write_file(values: int, data_len: int, filename: str):
    """Write values into a COE file."""
    with open(filename, "w") as file:
        for i in range(len(values)):
            # Write the concatenated value in hexadecimal format
            hex_value = "{:0{width}X}".format(values[i], width=data_len // 4)
            # write data in this format: h"hex_value"
            file.write(f"{hex_value}\n")


################################################################################
# Main
################################################################################
# Number of samples for sine and cosine values
num_samples = 16384
bram_data_width = 32

# Generate sine and cosine values
sine, cosine = generate_sine_cosine_values(num_samples)
# Apply two's complement conversion for sine_res and cosine_res
sine_ref = [twos_complement(i, bram_data_width // 2) for i in sine]
cosine_ref = [twos_complement(i, bram_data_width // 2) for i in cosine]

# Write coe files
# Conbine sine and cosine values into a single file (16 bits for sine and 16 bits for cosine)
write_file_concat(sine_ref, cosine_ref, bram_data_width, Path(__file__).parent / "input_data.tv")
