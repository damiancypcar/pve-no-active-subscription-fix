#!/usr/bin/env bash
# ----------------------------------------------------------
# Author:          damiancypcar
# Modified:        2023-12-12
# Version:         1.0
# PVE Version:     7+
# Desc:            Fix Proxmox "no active subscription"
# ----------------------------------------------------------

set -euo pipefail

ORIGPVE="/etc/apt/sources.list.d/pve-enterprise.list"
NEWPVE="/etc/apt/sources.list.d/pve-no-subscription.list"
ORIGCEPH="/etc/apt/sources.list.d/ceph.list"
NEWCEPH="/etc/apt/sources.list.d/ceph-no-subscription.list"
PVEVER=$(pveversion -v | grep 'proxmox-ve:' | cut -d' ' -f2 | cut -d'.' -f1)

# shellcheck disable=SC2046
if [ $(id -u) -ne 0 ]; then
    echo "You must be ROOT to run this script"
    exit 1
fi

# version check
if [ "${PVEVER}" -ge 7 ]; then
    echo "Proxmox VE version: ${PVEVER}"
else
    echo "Require Proxmox VE version 7 or higher"
    exit 1
fi

echo -e '\n>> Fixing PVE repo...'
sed -i "s/^deb/#deb/g" ${ORIGPVE}
echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' > ${NEWPVE}

echo '>> Fixing Ceph repo...'
sed -i "s/^deb/#deb/g" ${ORIGCEPH}
echo 'deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription' > ${NEWCEPH}

# disable "no active subscription" warning in Proxmox GUI
echo -e '\n>> Disabling "no active subscription" warning message...'
echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i.bak '/data.status/{s/\!//;s/[Aa]ctive/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" > /etc/apt/apt.conf.d/80pve-no-active-subscription-fix
apt --reinstall install proxmox-widget-toolkit
systemctl restart pveproxy.service

echo -e '\n>> Updating system...'
apt update
apt dist-upgrade -y
echo -e '\n>> Done. Please reboot!\n'
