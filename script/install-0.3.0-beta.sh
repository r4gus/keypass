#!/bin/bash

RED='\033[0;31m'
GREEN='\e[0;32m'
NC='\033[0m' # No Color

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

git clone https://github.com/r4gus/keypass --branch dev
cd keypass
../$zig build -Doptimize=ReleaseSmall
cp zig-out/bin/passkeez /usr/bin/passkeez

mkdir -p /usr/share/passkeez
cp src/static/passkeez.png /usr/share/passkeez/passkeez.png
cp src/static/passkeez-ok.png /usr/share/passkeez/passkeez-ok.png
cp src/static/passkeez-error.png /usr/share/passkeez/passkeez-error.png
cp src/static/passkeez-question.png /usr/share/passkeez/passkeez-question.png

# So we can do the following
# systemctl --user enable passkeez.service
# systemctl --user start passkeez.service
# systemctl --user stop passkeez.service
# systemctl --user status passkeez.service
cp script/passkeez.service /etc/systemd/user/passkeez.service

if [ -f "/home/$SUDO_USER/.local/share/applications/passkeez.desktop" ]; then
    echo "Removing old .desktop file..."
    rm "/home/$SUDO_USER/.local/share/applications/passkeez.desktop"
fi

echo "PassKeeZ installed into /usr/bin/passkeez/"

# Install zigenity
cd /tmp
git clone https://github.com/r4gus/zigenity --branch 0.1.3 2> /dev/null
cd zigenity
../$zig build -Doptimize=ReleaseSmall
cp zig-out/bin/zigenity /usr/bin/zigenity

echo "zigenity installed into /usr/bin/"

cd ~/

# This is where all configuration files will live
if [ ! -d /home/${SUDO_USER}/.passkeez ]; then
    sudo -E -u $SUDO_USER mkdir /home/${SUDO_USER}/.passkeez
    sudo chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.passkeez
fi

if [ ! -e /home/${SUDO_USER}/.passkeez/config.json ]; then 
    echo '{"db_path":"~/.passkeez/db.trs"}' > /home/${SUDO_USER}/.passkeez/config.json
    sudo chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.passkeez/config.json
fi

##############################################
#               Postinst                     #
##############################################

# Create a udev rule that allows all users that belong to the group fido to access /dev/uhid
echo 'KERNEL=="uhid", GROUP="fido", MODE="0660"' > /etc/udev/rules.d/90-uinput.rules

# Create a new group called fido
getent group fido || (groupadd fido && usermod -a -G fido $SUDO_USER)

# Add uhid to the list of modules to load during boot
echo "uhid" > /etc/modules-load.d/fido.conf 

#if ! command -v zenity &> /dev/null
#then
#    echo "${RED}zenity seems to be missing... please install!${NC}"
#fi

echo "${GREEN}PassKeeZ installed successfully.${NC}"
echo "To enable PassKeeZ permanently run the following commands:"
echo "    systemctl --user enable passkeez.service"
echo "    systemctl --user start passkeez.service"
echo "For further details visit https://github.com/r4gus/keypass"
echo "Please reboot..."

# Exit successfully
exit 0
