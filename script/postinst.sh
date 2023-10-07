#!/bin/sh

# Exit immediately if any command returns a non-zero exit status
set -e 

# Create a udev rule that allows all users that belong to the group fido to access /dev/uhid
echo 'KERNEL=="uhid", GROUP="fido", MODE="0660"' > /etc/udev/rules.d/90-uinput.rules

# Create a new group called fido
getent group fido || (groupadd fido && usermod -a -G fido $SUDO_USER)

# Add uhid to the list of modules to load during boot
if ! grep -q uhid /etc/modules; then
    echo "uhid" >> /etc/modules
fi

echo "Installed successfully. Please reboot..."

# Exit successfully
exit 0
