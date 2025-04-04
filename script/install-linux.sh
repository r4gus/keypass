#!/bin/bash

PASSKEEZ_VERSION=$([ -z "$1" ] && echo "0.5.0" || echo "$1")
ZIGENITY_VERSION=$([ -z "$2" ] && echo "0.4.0" || echo "$2")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ARCH=$(uname -m)

debian_dependencies=(
    curl
)

arches=(
    x86_64
    aarch64
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
            ;;
        *)
            echo -e "${RED}Unknown package manager $1${NC}" 
            echo "Please make sure that the following dependencies are met:"
            echo "    * curl"
            ;;
    esac

    case $2 in
        x86_64)
            ;;
        aarch64)
            ;;
        *)
            echo -e "${RED}unsupported architecture $2${NC}" 
            echo "Supported architectures are:"
            echo "    * x86_64"
            echo "    * aarch64"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Ok${NC}"
}

function install_passkeez {
    curl -L -# -C - -o "/usr/local/bin/passkeez" "https://github.com/r4gus/keypass/releases/download/$PASSKEEZ_VERSION/passkeez-linux-$ARCH-$PASSKEEZ_VERSION"
    chmod +x /usr/local/bin/passkeez
 
    # Install the static files 
    #mkdir -p /usr/share/passkeez
    #cp src/static/*.png /usr/share/passkeez/

    # So we can do the following
    # systemctl --user enable passkeez.service
    # systemctl --user start passkeez.service
    # systemctl --user stop passkeez.service
    # systemctl --user status passkeez.service
    #cp script/passkeez.service /etc/systemd/user/passkeez.service
    mkdir -p /home/${SUDO_USER}/.local/share/systemd/user
    curl -L -# -C - -o "/home/${SUDO_USER}/.local/share/systemd/user/passkeez.service" "https://raw.githubusercontent.com/r4gus/keypass/refs/heads/master/script/passkeez.service"
}

function install_zigenity {
    curl -L -# -C - -o "/usr/local/bin/zigenity" "https://github.com/r4gus/keypass/releases/download/$PASSKEEZ_VERSION/zigenity-linux-$ARCH-$ZIGENITY_VERSION"
    chmod +x /usr/local/bin/zigenity
}

function check_config_folder {
    # This is where all configuration files will live
    if [ ! -d /home/${SUDO_USER}/.passkeez ]; then
        sudo -E -u $SUDO_USER mkdir /home/${SUDO_USER}/.passkeez
        sudo chown ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.passkeez
    fi

    if [ ! -e /home/${SUDO_USER}/.passkeez/config.json ]; then 
        echo '{"db_path":"~/.passkeez/db.kdbx", "lang":"english"}' > /home/${SUDO_USER}/.passkeez/config.json
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
echo "\_|  \__,_|___/___/\_| \_/\___|\___|\_____/ v$PASSKEEZ_VERSION"
echo -e "${GREEN}PassKeeZ Installer${NC}"
echo "------------------"

if [ ! `id -u` = 0 ]; then
    echo -e "${YELLOW}please run script with sudo${NC}"
    exit 1
fi

# First we make sure that all dependencies are met
PKG=$(get_package_manager)

echo "Architecture:    ${ARCH}"
echo "Package manager: ${PKG}"

echo "Stopping PassKeeZ service..."
systemctl --user --machine=${SUDO_USER}@ stop passkeez.service || true
echo "Disabling PassKeeZ service..."
systemctl --user --machine=${SUDO_USER}@ disable passkeez.service || true

echo "Checking dependencies... "
check_dependencies $PKG $ARCH

echo "Installing PassKeeZ... "
install_passkeez
echo -e "${GREEN}OK${NC}"

echo "Installing zigenity... "
install_zigenity
echo -e "${GREEN}OK${NC}"

echo "Checking configuration folder... "
check_config_folder
echo -e "${GREEN}OK${NC}"

echo "Configuring... "
postinst
echo -e "${GREEN}OK${NC}"

echo "Enabling PassKeeZ service..."
systemctl --user --machine=${SUDO_USER}@ enable passkeez.service || true
echo "Starting PassKeeZ service..."
systemctl --user --machine=${SUDO_USER}@ start passkeez.service || true
systemctl --user --machine=${SUDO_USER}@ status --no-pager passkeez.service || true

echo -e "${GREEN}PassKeeZ installed successfully.${NC}"
echo "To enable PassKeeZ permanently you can run the following commands:"
echo -e "    ${YELLOW}systemctl --user enable passkeez.service${NC}"
echo -e "    ${YELLOW}systemctl --user start passkeez.service${NC}"
echo "To stop PassKeeZ run:"
echo -e "    ${YELLOW}systemctl --user stop passkeez.service${NC}"
echo "To disable PassKeeZ run:"
echo -e "    ${YELLOW}systemctl --user disable passkeez.service${NC}"
echo "For further details visit https://github.com/Zig-Sec/PassKeeZ/wiki"
echo -e "${YELLOW}If this is the first time running this script, please reboot...${NC}"

# Exit successfully
exit 0
