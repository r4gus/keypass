# Exit immediately if any command returns a non-zero exit status
set -e

if [ ! `id -u` = 0 ]; then
    echo "please run script with sudo"
    exit 1
fi

rm -rf /usr/local/bin/passkeez
rm -rf /usr/bin/passkeez

rm -rf /usr/local/bin/zigenity
rm -rf /usr/bin/zigenity

rm /etc/systemd/user/passkeez.service
rm /etc/udev/rules.d/90-uinput.rules

echo "PassKeeZ successfully uninstalled"
