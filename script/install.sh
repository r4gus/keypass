#!/bin/bash

# Exit immediately if any command returns a non-zero exit status
set -e

if [ ! `id -u` = 0 ]; then
    echo "please run script with sudo"
    exit 1
fi

cd /tmp
rm -rf zig* keypass

path=""
case $(uname -m) in
    i386) path="https://ziglang.org/download/0.11.0/zig-linux-x86-0.11.0.tar.xz" ;;
    i686) path="https://ziglang.org/download/0.11.0/zig-linux-x86-0.11.0.tar.xz" ;;
    x86_64) path="https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz" ;;
esac

zig="zig"
if [ "$path" != "" ]; then
    echo "Downloading Zig 0.11.0..."
    curl -# -C - -o "zig.tar.xz" "$path"    
    tar -xf "zig.tar.xz"
    sub=$(ls | grep "zig-")
    zig="$sub/zig"
fi

git clone https://github.com/r4gus/keypass --branch 0.2.1
cd keypass
../$zig build -Doptimize=ReleaseSmall
rm -rf /usr/local/bin/passkeez
mkdir /usr/local/bin/passkeez
cp zig-out/bin/passkeez /usr/local/bin/passkeez/passkeez
cp src/static/passkeez.png /usr/local/bin/passkeez/passkeez.png

if [ -f "/home/$SUDO_USER/.local/share/applications/passkeez.desktop" ]; then
    echo "Removing old .desktop file..."
    rm "/home/$SUDO_USER/.local/share/applications/passkeez.desktop"
    update-desktop-database "/home/$SUDO_USER/.local/share/applications"
fi
echo "Installing .desktop file..."
desktop-file-install --dir="/home/$SUDO_USER/.local/share/applications" linux/passkeez.desktop
update-desktop-database "/home/$SUDO_USER/.local/share/applications"

cd ~/

echo "PassKeeZ installed into /usr/local/bin/passkeez/"

##############################################
#               Postinst                     #
##############################################

# Create a udev rule that allows all users that belong to the group fido to access /dev/uhid
echo 'KERNEL=="uhid", GROUP="fido", MODE="0660"' > /etc/udev/rules.d/90-uinput.rules

# Create a new group called fido
getent group fido || (groupadd fido && usermod -a -G fido $SUDO_USER)

# Add uhid to the list of modules to load during boot
echo "uhid" > /etc/modules-load.d/fido.conf 

echo "Installed successfully. Please reboot..."

# Exit successfully
exit 0
