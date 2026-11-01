import numpy as np
import os
import matplotlib.pyplot as plt
from rp.constants import RP_SYS_CLK
from scipy.signal import sosfilt, sosfreqz
from rp.lia.config import calc_iir_coeffs
from rp.lia.processing import calc_r_phi, reconstruct_signal
import re

# Plotting settings
# plt.rcParams['axes.grid'] = True
plt.rcParams["grid.linestyle"] = "--"  # Grid line style
plt.rcParams["grid.linewidth"] = 0.5  # Grid line width
plt.rcParams["axes.titlesize"] = 14  # Title font size
plt.rcParams["axes.labelsize"] = 12  # Axis label font size
plt.rcParams["xtick.labelsize"] = 10  # X tick label font size
plt.rcParams["ytick.labelsize"] = 10  # Y tick label font size
plt.rcParams["legend.fontsize"] = 10  # Legend font size
plt.rcParams["xtick.direction"] = "in"  # X tick direction
plt.rcParams["ytick.direction"] = "in"  # Y tick direction
plt.rcParams["xtick.top"] = True  # Show ticks on top
plt.rcParams["ytick.right"] = True


def writeInputDataFiles(data: np.ndarray, inputData: str = "i"):
    with open(f"./test_data/{inputData}_data.tv", "w") as f:
        # mix_sig = sig_noise * cos_ref
        for value in data:
            s = int(value)
            # convert to two's complement
            if s < 0:
                s = (1 << 32) + s
            # convert to hex
            f.write(f"{s:08X}\n")


def modify_sample_rate_div(new_value, file_path: str = "axis_lia_iir_tb.vhd"):
    with open(file_path, "r") as file:
        content = file.read()

    # Regular expression to find and replace the first occurrence of sample_rate_div value
    pattern = r"(sample_rate_div\s*:\s*natural\s*:=\s*)(\d+)"
    replacement = r"\g<1>" + str(new_value)  # Correct group reference

    modified_content, count = re.subn(
        pattern, replacement, content, count=1
    )  # Stop at first occurrence

    with open(file_path, "w") as file:
        file.write(modified_content)

    if count:
        print(f"Updated sample_rate_div to {new_value} in {file_path}")
    else:
        print("sample_rate_div not found in file.")


## PARAMETERS:

WRITE_FILE = True
SHOW_PLOT = True

# SIGNAL
SAMPLE_RATE_DIV = 10  # only works for >=7
FS_MHZ = RP_SYS_CLK / SAMPLE_RATE_DIV  #
F_SIGNAL_KHZ = 125

# FILTER-Stuff
F_CUTOFF_KHZ = 50

FILTER_ORDER = 2
FILTER_TYPE = "butter"
ATTN_DB = 60
COEFF_BITS = 25
FRAC_BITS = 23

N_SAMPLES = 10000
PHASE_OFFSET = 0  # degree
NOISE_VALUE = 0

REF_RESOLUTION = 14


if __name__ == "__main__":
    # Calculate samples needed for given frequency, periods and sampling rate
    samples_per_period = int(FS_MHZ / (F_SIGNAL_KHZ * 1e-3))

    # plot input signal
    PERIODS_TO_PLOT = 10
    plotRange = PERIODS_TO_PLOT * samples_per_period

    n_periods = N_SAMPLES / samples_per_period

    # Generate the time vector
    t_us = np.arange(N_SAMPLES) / FS_MHZ
    # Generate the sine signal
    sig = np.sin(2 * np.pi * F_SIGNAL_KHZ * 1e-3 * t_us + np.deg2rad(PHASE_OFFSET))

    sig_noise = sig + np.random.normal(0, NOISE_VALUE, N_SAMPLES)
    # Scale signal to simulate hardware ADC
    sin_ref = np.sin(2 * np.pi * F_SIGNAL_KHZ * 1e-3 * t_us)
    cos_ref = np.cos(2 * np.pi * F_SIGNAL_KHZ * 1e-3 * t_us)

    # Mixing the signal with the reference signal
    I = sig_noise * sin_ref
    Q = sig_noise * cos_ref

    time_us = np.asarray(t_us)

    # Save signal to tv file
    if WRITE_FILE:
        # todo: add correct converion method here...
        writeInputDataFiles((2**REF_RESOLUTION - 1) * I, inputData="i")
        # todo: add correct converion method here...
        writeInputDataFiles((2**REF_RESOLUTION - 1) * Q, inputData="q")

        # so also adjust SR in testbench:
        modify_sample_rate_div(SAMPLE_RATE_DIV)

    ## PLOT TEST SIGNAL I and Q

    plt.subplot(2, 1, 1)
    plt.plot(time_us[:plotRange], sig_noise[:plotRange], label="Signal + Noise")
    plt.plot(time_us[:plotRange], sig[:plotRange], label="Signal")
    plt.subplot(2, 1, 2)
    plt.plot(time_us[:plotRange], I[:plotRange], label="i-mult")
    plt.plot(time_us[:plotRange], Q[:plotRange], label="q-mult")
    plt.legend()
    plt.xlabel("time in µs")
    print(f"Number of samples: {N_SAMPLES}")
    print(f"Number of samples per period: {samples_per_period}")
    print(f"Sampling frequency: {FS_MHZ}MHz")

    #######################################################################################################
    ## IIR-Filter coeffs:

    fs = int(FS_MHZ * 1e6)
    f = int(F_SIGNAL_KHZ * 1e3)
    fc = int(F_CUTOFF_KHZ * 1e3)

    # Get parameters from global dict

    # Filtering with floating point coefficients
    coeff = calc_iir_coeffs(
        FILTER_ORDER, fc, fs, filt_type=FILTER_TYPE, attn_dB=ATTN_DB
    )
    I_filt = sosfilt(coeff, I)
    Q_filt = sosfilt(coeff, Q)

    # Filtering with quantized coefficients
    coeff_quan = np.round(coeff * 2**FRAC_BITS) / 2**FRAC_BITS
    I_filt_quantized = sosfilt(coeff_quan, I)
    Q_filt_quantized = sosfilt(coeff_quan, Q)

    # Calculate amplitude and phase and reconstruct the signal
    r, phi = calc_r_phi(I_filt, Q_filt)
    print(f"reconstruct with SR: {fs}Hz for freq {f}Hz")
    out_signal = reconstruct_signal(r, phi, f, fs, 2)

    # Calculate the frequency response of the filter
    w, h = sosfreqz(coeff, worN=8000)  # 8000???
    freq = w / (2 * np.pi) * fs
    gain = np.abs(h)

    # better calculate transient delay...

    f_cutoff = freq[np.where(gain <= 0.707)[0][0]]

    # Assign IIR filter parameters to global variable

    ################################################################################################
    # Plot filtered signal and reconstructed signal
    ################################################################################################
    plt.figure(figsize=(20, 5))

    plt.subplot(131)
    plt.title("In-phase Component")
    plt.plot(t_us[:plotRange], I[:plotRange], color="tab:green", label="unfiltered")
    plt.plot(t_us[:plotRange], I_filt[:plotRange], color="tab:red", label="filtered")
    plt.plot(
        t_us[:plotRange],
        I_filt_quantized[:plotRange],
        color="tab:blue",
        label="filtered quantized",
    )
    plt.xlabel("time in us")
    plt.legend()

    plt.subplot(132)
    plt.title("Quadrature Component")
    plt.plot(t_us[:plotRange], Q[:plotRange], color="tab:green", label="unfiltered")
    plt.plot(t_us[:plotRange], Q_filt[:plotRange], color="tab:red", label="filtered")
    plt.plot(
        t_us[:plotRange],
        Q_filt_quantized[:plotRange],
        color="tab:blue",
        label="filtered quantized",
    )
    plt.xlabel("time in us")
    plt.legend()

    plt.subplot(133)
    plt.title("Signal and Reconstructed Signal")
    plt.plot(
        t_us[:plotRange], sig_noise[:plotRange], color="tab:green", label="Input signal"
    )
    plt.plot(
        t_us[:plotRange],
        out_signal[:plotRange],
        color="tab:red",
        label="Reconstructed_signal",
    )
    plt.xlabel("time in us")
    plt.legend()

    #### Write coefficients to file:
    # Run the cell above first to get the IIR filter parameters
    SOS_NUM = len(coeff)
    SOS_COEFF_NUM = len(coeff[0])
    COEFF_WIDTH = COEFF_BITS
    COEFF_FRAC_WIDTH = FRAC_BITS
    # Number of IIR module's internal registers
    IIR_REGS = 32

    print(f"filter order: {FILTER_ORDER}, sos sections: {SOS_NUM}")
    print(f"coeff_width: {COEFF_WIDTH}, frac_bits: {COEFF_FRAC_WIDTH}\n")

    if not os.path.exists("test_data"):
        os.makedirs("test_data")

    # Write the coefficients to a file
    with open("./test_data/iir_coeff_data.tv", "w") as f:
        # Give information about the number of sos
        f.write(f"{SOS_NUM:08X}\n")
        regs = 1

        # Write the coefficients to a file
        for i in range(SOS_NUM):
            print(f"second order section {i}:")
            for j in range(SOS_COEFF_NUM):
                # skip a0 coefficient
                if j != 3:
                    # convert to two's complement
                    quantization = 2**COEFF_FRAC_WIDTH
                    s = round(coeff[i][j] * quantization)
                    s_error = coeff[i][j] - s / quantization
                    if s < 0:
                        s = (1 << COEFF_WIDTH) + s

                    # convert to hex and write to file
                    print(
                        f"SOS_{i}: COEFF_{j}: 0x{s:08X} <- {coeff[i][j]} | error: {s_error}"
                    )
                    f.write(f"{s:08X}\n")
                    regs += 1

        if regs < IIR_REGS:
            for i in range(IIR_REGS - regs):
                f.write("00000000\n")

    if SHOW_PLOT:
        plt.show()
