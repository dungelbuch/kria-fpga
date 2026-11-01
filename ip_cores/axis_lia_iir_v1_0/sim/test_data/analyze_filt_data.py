import numpy as np
import matplotlib.pyplot as plt

# Path to your VHDL-generated log file
filename = "filt_sim_data.res"

# Read hex strings, and removes "0xXXXXXXXX" entries
with open(filename, 'r') as f:
    hex_lines = [line.strip() for line in f]
hex_lines = [x for x in hex_lines if x != "0xXXXXXXXX"]

# Convert hex strings to unsigned integers and then to signed integers
uint_values = np.array([int(h, 16) for h in hex_lines], dtype=np.uint32)
int_values = uint_values.astype(np.int32)

# Seperate I and Q
I = int_values[0::2]
Q = int_values[1::2]

# Plot I and Q
plt.figure(figsize=(20, 5))
x_limit = 2000

plt.subplot(121)
plt.plot(I, color="tab:green", label="Inphase filtered")
plt.xlim(0, x_limit)
plt.legend()

plt.subplot(122)
plt.plot(Q, color="tab:red", label="Quadrature filtered")
plt.xlim(0, x_limit)
plt.legend()

plt.show()
