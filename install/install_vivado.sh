#!/bin/bash

# Usage: ./install_vivado.sh [xsetup_path] [install_config_path]
#   xsetup_path          defaults to the extracted 2025.2 installer in ~/Downloads
#   install_config_path  defaults to install_config.txt next to this script

# Stop on the first failing command
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assign parameters
XSETUP="${1:-$HOME/Downloads/FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157/xsetup}"
CONFIG_FILE="${2:-$SCRIPT_DIR/install_config.txt}"
VERSION="2025.2"

# Check if the files actually exist
if [ ! -f "$XSETUP" ]; then
    echo "Error: Installer binary '$XSETUP' not found!"
    exit 1
fi

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

# Prepare the root /tools directory so the non-root installer can write to it
DEST_DIR="/tools/Xilinx"
INSTALL_DIR="$DEST_DIR/$VERSION"

# Make sure the config installs to the same place this script expects
if ! grep -qx "Destination=$DEST_DIR" "$CONFIG_FILE"; then
    echo "Error: '$CONFIG_FILE' must contain the line: Destination=$DEST_DIR"
    exit 1
fi

echo "Creating target directory and adjusting permissions..."
sudo mkdir -p "$DEST_DIR"
sudo chown -R "$USER:$USER" "$DEST_DIR"

# Install required packages
sudo apt update
sudo dpkg --add-architecture i386
sudo apt update
sudo apt-get install gparted xinetd gawk gcc net-tools ncurses-dev openssl libssl-dev flex bison xterm autoconf libtool texinfo zlib1g-dev  -y
sudo apt-get install iproute2 make libncurses-dev tftpd-hpa tftp-hpa libselinux1 wget diffstat chrpath socat tar unzip gzip python3 python-is-python3 2to3 tofrodos lsb-release  libftdi1 libftdi1-2 -y
sudo apt-get install lib32stdc++6 libgtk2.0-0:i386 libfontconfig1:i386 libx11-6:i386 libxext6:i386 libxrender1:i386 libsm6:i386 tree openssh-server -y
sudo apt-get install debianutils iputils-ping libegl1 libsdl1.2-dev pylint python3 cpio tftpd-hpa gnupg zlib1g:i386 haveged perl xvfb -y
sudo apt-get install gcc-multilib build-essential automake screen putty pax g++ python3-pip xz-utils python3-git python3-jinja2 python3-pexpect -y
sudo apt-get install liberror-perl mtd-utils xtrans-dev libxcb-randr0-dev libxcb-xtest0-dev libxcb-xinerama0-dev libxcb-shape0-dev libxcb-xkb-dev -y
sudo apt-get install util-linux sysvinit-utils cython3 google-perftools patch diffutils ocl-icd-libopencl1 opencl-headers ocl-icd-opencl-dev -y
sudo apt-get install libncurses6 libncurses-dev libncursesw6:amd64 libncurses6:i386 libtinfo6 libstdc++6:i386 libgtk2.0-0:i386 -y
sudo ln -sf /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5

# Run the installer
echo "Starting installation in CLI mode..."
chmod +x "$XSETUP"
if ! "$XSETUP" --agree XilinxEULA,3rdPartyEULA --batch Install --config "$CONFIG_FILE"; then
    echo "Error: The installer failed. Check the log in ~/.Xilinx/xinstall/ for details."
    exit 1
fi

# Install necessary libraries and cable drivers (with fallback if Vitis isn't installed)
if [ -f "$INSTALL_DIR/Vitis/scripts/installLibs.sh" ]; then
    sudo "$INSTALL_DIR/Vitis/scripts/installLibs.sh"
fi

if [ -f "$INSTALL_DIR/Vivado/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers" ]; then
    sudo "$INSTALL_DIR/Vivado/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers"
else
    echo "Warning: Cable driver installer not found, skipping. JTAG programming may not work."
fi

# Add Xilinx environment settings to .bashrc
echo "Adding environment paths to ~/.bashrc..."
VIVADO_SETTING="source $INSTALL_DIR/Vivado/settings64.sh"
VITIS_SETTING="source $INSTALL_DIR/Vitis/settings64.sh"

grep -qF "$VIVADO_SETTING" ~/.bashrc || echo "$VIVADO_SETTING" >> ~/.bashrc
if [ -f "$INSTALL_DIR/Vitis/settings64.sh" ]; then
    grep -qF "$VITIS_SETTING" ~/.bashrc || echo "$VITIS_SETTING" >> ~/.bashrc
fi

# Info Box for the user
echo "====================================================================="
echo " INFO: Xilinx Environment Paths added to ~/.bashrc"
echo "====================================================================="
echo " The Vivado and Vitis launch paths have been automatically added to"
echo " your ~/.bashrc file. They will load the next time you open a new terminal."
echo ""
echo " IMPORTANT NOTE FOR OTHER SHELLS:"
echo " If you use a different shell (like zsh, fish, etc.), you must manually"
echo " add these source lines to your shell's configuration file (e.g., ~/.zshrc):"
echo ""
echo "   $VIVADO_SETTING"
echo "   $VITIS_SETTING"
echo "====================================================================="

echo "Installation completed successfully!"
