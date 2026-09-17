#!/usr/bin/bash
# Sirius OS: first-boot provisioning for Proton VPN
set -euo pipefail

STAMP="/var/lib/sirius-protonvpn/provisioned"

echo "Sirius: provisioning Proton VPN"

# --- 1. Enable the Proton VPN daemon ----------------------------------
systemctl enable --now me.proton.vpn.split_tunneling.service 2>/dev/null || true

# --- 2. Write the provisioning stamp ----------------------------------
mkdir -p "$(dirname "$STAMP")"
rpm -q --qf '%{VERSION}-%{RELEASE}\n' sirius-os-protonvpn > "$STAMP.tmp"
mv -f "$STAMP.tmp" "$STAMP"
sync

echo "Sirius: Proton VPN provisioning complete"
