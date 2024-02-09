#!/usr/bin/env bash
# ----------------------------------------------------------
# Author:          damiancypcar
# Modified:        2024-02-09
# Version:         1.2
# PVE Version:     7/8
# Desc:            Fix Proxmox "no active subscription"
# ----------------------------------------------------------

set -euo pipefail

ORIG_PVE="/etc/apt/sources.list.d/pve-enterprise.list"
NEW_PVE="/etc/apt/sources.list.d/pve-no-subscription.list"
ORIG_CEPH="/etc/apt/sources.list.d/ceph.list"
NEW_CEPH="/etc/apt/sources.list.d/ceph-no-subscription.list"
PVE_VER=$(pveversion -v | grep 'proxmox-ve:' | cut -d' ' -f2 | cut -d'.' -f1)

# shellcheck disable=SC2046
if [ $(id -u) -ne 0 ]; then
    echo "You must be ROOT to run this script"
    exit 1
fi

# version check
echo "Proxmox VE version: ${PVE_VER}"
if [ "${PVE_VER}" -eq 7 ]; then
    echo -e '\n>> Fixing PVE repo...'
    sed -i "s/^deb/#deb/g" ${ORIG_PVE}
    echo 'deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription' > ${NEW_PVE}

elif [ "${PVE_VER}" -eq 8 ]; then
    echo -e '\n>> Fixing PVE repo...'
    sed -i "s/^deb/#deb/g" ${ORIG_PVE}
    echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' > ${NEW_PVE}

    echo '>> Fixing Ceph repo...'
    sed -i "s/^deb/#deb/g" ${ORIG_CEPH}
    echo 'deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription' > ${NEW_CEPH}
else
    echo "Require Proxmox VE version 7 or 8"
    exit 1
fi

# disable "no active subscription" warning in Proxmox GUI
echo -e '\n>> Disabling "no active subscription" warning message...'
echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i.bak '/data.status/{s/\!//;s/[Aa]ctive/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" > /etc/apt/apt.conf.d/80pve-no-active-subscription-fix
apt --reinstall install proxmox-widget-toolkit
systemctl restart pveproxy.service

echo -e '\n>> Updating system...'
apt update
apt dist-upgrade -y
echo -e '\n>> Done. Please reboot!\n'
