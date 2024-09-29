#!/bin/bash

PASSKEEZ_VERSION="0.3.1"
ZIGENITY_VERSION="0.3.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

debian_dependencies=(
    curl
    git
    libgtk-3-0
    libgtk-3-dev
)

function get_package_manager {
    declare -A osInfo;
    osInfo[/etc/redhat-release]=yum
    osInfo[/etc/arch-release]=pacman
    osInfo[/etc/gentoo-release]=emerge
    osInfo[/etc/SuSE-release]=zypp
    osInfo[/etc/debian_version]=apt-get
    osInfo[/etc/alpine-release]=apk

    for f in ${!osInfo[@]}
    do
        if [[ -f $f ]];then
            echo ${osInfo[$f]}
            break
        fi
    done
}

function download_zig {
    cd /tmp
    sub=$(ls | grep "zig-")

    if [ -z "$sub" ]; then
        path=""
        case $1 in
            i386) path="https://ziglang.org/download/0.13.0/zig-linux-x86-0.13.0.tar.xz" ;;
            i686) path="https://ziglang.org/download/0.13.0/zig-linux-x86-0.13.0.tar.xz" ;;
            x86_64) path="https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz" ;;
            *) 
                echo -e "${RED}Unsupported architecture $1. Exiting...${NC}"
                exit 1
                ;;
        esac

        if [ "$path" != "" ]; then
            curl -# -C - -o "zig.tar.xz" "$path"    
            tar -xf "zig.tar.xz"
            sub=$(ls | grep "zig-")
        fi
    fi
    
    zig="$sub/zig"
    echo ${zig}
}

# Verify that all dependencies are met
function check_dependencies {
    case $1 in
        apt-get) 
            for i in "${debian_dependencies[@]}"; do
                if ! command -v "$i" &> /dev/null
                then
                    apt-get install -y "$i"
                fi
            done
            echo -e "${GREEN}Ok${NC}"
            ;;
        *)
            echo "${RED}Unknown package manager $1${NC}" 
            echo "Please make sure that the following dependencies are met:"
            echo "    * curl"
            echo "    * git"
            echo "    * gtk3"
            ;;
    esac
}

function install_passkeez {
    cd /tmp
    
    # Install the application
    if [ ! -d "./keypass" ]; then
        git clone https://github.com/r4gus/keypass --branch $1
    fi
    cd keypass
    ../$2 build -Doptimize=ReleaseSmall
    cp zig-out/bin/passkeez /usr/local/bin/passkeez
    
    # Install the static files 
    mkdir -p /usr/share/passkeez
    cp src/static/*.png /usr/share/passkeez/

    # So we can do the following
    # systemctl --user enable passkeez.service
    # systemctl --user start passkeez.service
    # systemctl --user stop passkeez.service
    # systemctl --user status passkeez.service
    #cp script/passkeez.service /etc/systemd/user/passkeez.service
    mkdir -p /home/${SUDO_USER}/.local/share/systemd/user
    cp script/passkeez.service /home/${SUDO_USER}/.local/share/systemd/user/passkeez.service
    
    # This is to remove the legacy desktop file
    if [ -f "/home/$SUDO_USER/.local/share/applications/passkeez.desktop" ]; then
        rm "/home/$SUDO_USER/.local/share/applications/passkeez.desktop"
    fi
}

function install_zigenity {
    cd /tmp

    if [ ! -d "./zigenity" ]; then
        git clone https://github.com/r4gus/zigenity --branch $1
    fi

    cd zigenity
    ../$2 build -Doptimize=ReleaseSmall
    cp zig-out/bin/zigenity /usr/local/bin/zigenity
}

function check_config_folder {
    # This is where all configuration files will live
    if [ ! -d /home/${SUDO_USER}/.passkeez ]; then
        sudo -E -u $SUDO_USER mkdir /home/${SUDO_USER}/.passkeez
        sudo chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.passkeez
    fi

    if [ ! -e /home/${SUDO_USER}/.passkeez/config.json ]; then 
        echo '{"db_path":"~/.passkeez/db.ccdb"}' > /home/${SUDO_USER}/.passkeez/config.json
        sudo chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.passkeez/config.json
    fi
}

function postinst {
    # Create a new group called fido
    getent group fido || (groupadd fido && usermod -a -G fido $SUDO_USER)

    # Add uhid to the list of modules to load during boot
    echo "uhid" > /etc/modules-load.d/fido.conf

    # Create a udev rule that allows all users that belong to the group fido to access /dev/uhid
    echo 'KERNEL=="uhid", GROUP="fido", MODE="0660"' > /etc/udev/rules.d/90-uinput.rules
    udevadm control --reload-rules && udevadm trigger
}

# Exit immediately if any command returns a non-zero exit status
set -e

echo '______              _   __           ______'
echo '| ___ \            | | / /          |___  /'
echo '| |_/ /_ _ ___ ___ | |/ /  ___  ___    / /'
echo '|  __/ _` / __/ __||    \ / _ \/ _ \  / /'
echo '| | | (_| \__ \__ \| |\  \  __/  __/./ /___'
echo '\_|  \__,_|___/___/\_| \_/\___|\___|\_____/'
echo ""
echo -e "${GREEN}PassKeeZ Installer${NC}"
echo "------------------"

if [ ! `id -u` = 0 ]; then
    echo -e "${YELLOW}please run script with sudo${NC}"
    exit 1
fi

# First we make sure that all dependencies are met
ARCH=$(uname -m)
PKG=$(get_package_manager)

echo "Architecture:    ${ARCH}"
echo "Package manager: ${PKG}"

echo -n "Checking dependencies... "
check_dependencies $PKG

echo "Downloading Zig..."
zig=$(download_zig $ARCH)

echo -n "Installing PassKeeZ... "
install_passkeez $PASSKEEZ_VERSION $zig
echo -e "${GREEN}OK${NC}"

echo -n "Installing zigenity... "
install_zigenity $ZIGENITY_VERSION $zig
echo -e "${GREEN}OK${NC}"

echo -n "Checking configuration folder... "
check_config_folder
echo -e "${GREEN}OK${NC}"

echo -n "Configuring... "
postinst
echo -e "${GREEN}OK${NC}"

echo -e "${GREEN}PassKeeZ installed successfully.${NC}"
echo "To enable PassKeeZ permanently run the following commands:"
echo -e "    ${YELLOW}systemctl --user enable passkeez.service${NC}"
echo -e "    ${YELLOW}systemctl --user start passkeez.service${NC}"
echo "For further details visit https://github.com/r4gus/keypass"
echo -e "${YELLOW}If this is the first time running this script, please reboot...${NC}"

# Exit successfully
exit 0
