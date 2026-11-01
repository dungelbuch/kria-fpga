"""
script to "simulate filter calculations..."
"""

import matplotlib.pyplot as plt
from rp.constants import RP_SYS_CLK
import numpy as np

from sim_setup import COEFF_BITS, FRAC_BITS, FS_MHZ

pathToDataFolder = "test_data/"


NSAMPLES = 10

BIT_WIDTH_ACC_B = 32 + 25 + 2
BIT_WIDTH_ACC_A = 32 + 25 + 1
BIT_WIDTH_ACC_Y = 32 + 25 + 3

COEFF_WIDTH = COEFF_BITS
COEFF_FRAC_WIDTH = FRAC_BITS
DATA_WIDTH = 32

SHOW_PLOT = True


def hex_to_signed(hex_str, bitWidth: int = 32):
    """Convert 8-character hex string to a signed 32-bit integer."""
    s = int(hex_str, 16)  # Convert hex string to integer
    if s & (1 << bitWidth - 1):  # Check if the highest bit (31st) is set
        return s - (1 << bitWidth)  # Convert back to signed
    return s  # It's already positive


def resize(value, bit_width: int):
    """Mimics VHDL's resize function by constraining the value to bit_width."""
    max_val = (1 << (bit_width - 1)) - 1  # Max positive value
    min_val = -(1 << (bit_width - 1))  # Min negative value

    # Apply two's complement constraints
    if value > max_val:
        value -= 1 << bit_width
    elif value < min_val:
        value += 1 << bit_width

    return value


def shift_right(value, n, bit_width):
    """Mimic VHDL's shift_right for signed integers with a fixed bit width."""
    if value < 0:
        # Arithmetic shift for signed numbers (preserves sign bit)
        shifted = (value >> n) | (
            -(1 << (bit_width - n)) if (value & (1 << (bit_width - 1))) else 0
        )
    else:
        # Logical shift for positive numbers
        shifted = value >> n

    # Ensure the result is within the correct bit-width range
    return resize(shifted, bit_width)


# read in coeffs:
def getInputData(filter: str = "i"):
    with open(f"{pathToDataFolder}{filter}_data.tv") as f:
        data = f.readlines()
    # strip away \n and convert to signed int
    dataInt = [hex_to_signed(value.replace("\n", ""), 32) for value in data[:NSAMPLES]]
    return dataInt


def getCoeffs():
    with open(f"{pathToDataFolder}iir_coeff_data.tv") as f:
        data = f.readlines()
    coeffs = []
    # skip first coeff=1??
    for coeff in data[1:]:
        coeff = coeff.replace("\n", "")
        coeffInt = hex_to_signed(coeff, 25)

        if coeffInt != 0:
            coeffs.append(coeffInt)

    return {
        "b0": coeffs[0],  # 1,
        "b1": coeffs[1],  # 0,
        "b2": coeffs[2],  # 0,
        "a1": coeffs[3],  # 0,
        "a2": coeffs[4],  # 0,
    }


def testFilter(coeffs: dict, data: list):
    """Implements a 2nd-order IIR filter (Direct Form 1)"""
    y = [0] * len(data)  # Output buffer (same length as input)

    # Initialize past values (for feedback and feedforward terms)
    x_1, x_2 = 0, 0  # x[n-1], x[n-2]
    y_1, y_2 = 0, 0  # y[n-1], y[n-2]

    # Coefficients
    b0, b1, b2 = coeffs["b0"], coeffs["b1"], coeffs["b2"]
    a1, a2 = coeffs["a1"], coeffs["a2"]

    # Filtering loop
    for i in range(len(data)):
        x_n = data[i]  # Current input sample

        mult_b0 = b0 * x_n
        mult_b1 = b1 * x_1
        mult_b2 = b2 * x_2
        mult_a1 = a1 * y_1
        mult_a2 = a2 * y_2

        res_acc_b = resize(mult_b0 + mult_b1 + mult_b2, BIT_WIDTH_ACC_B)
        res_acc_a = resize(mult_a1 + mult_a2, BIT_WIDTH_ACC_A)

        # Compute filtered output using the difference equation
        y_n = shift_right(res_acc_b - res_acc_a, COEFF_FRAC_WIDTH, DATA_WIDTH)

        # Store the result
        y[i] = y_n

        # Update past values for the next iteration
        x_2, x_1 = x_1, x_n
        y_2, y_1 = y_1, y_n

        print(f"{i}: mult_b0 = {b0} * {x_n}  = {mult_b0} ")
        print(f"{i}: mult_b1 = {b1} * {x_1}  = {mult_b1} ")
        print(f"{i}: mult_b2 = {b2} * {x_2}  = {mult_b2} ")
        print(f"{i}: mult_a1 = {a1} * {y_1}  = {mult_a1} ")
        print(f"{i}: mult_a2 = {a2} * {y_2}  = {mult_a2} ")
        print(f"{i}: res_acc_b = {res_acc_b} ")
        print(f"{i}: res_acc_a = {res_acc_a} ")
        print(f"{i}: y = {y} ")

        print("##########################")

    return y  # Return the filtered signal


data_i = getInputData("i")
coeffs = getCoeffs()
output = testFilter(coeffs, data_i)
print(f"InputData: data = {data_i} ")

timeAxis = (1 / FS_MHZ) * np.arange(len(data_i))

plt.plot(timeAxis, data_i, label="input")
plt.plot(timeAxis, output, label="filter output")
plt.xlabel("time in us")
plt.legend()
if SHOW_PLOT:
    plt.show()
