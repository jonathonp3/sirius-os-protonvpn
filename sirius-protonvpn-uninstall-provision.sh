#!/usr/bin/bash
# Sirius OS: provision the dormant Proton VPN uninstaller.
#
# Creates a service and a task script in /etc/ at first boot.
# Files created here are owned by nobody, so `rpm-ostree remove` leaves
# them alone. That is what allows the uninstaller to survive the
# deployment swap and fire on the next boot after the RPM is gone.
set -euo pipefail

SERVICE_FILE="/etc/systemd/system/sirius-protonvpn-uninstall.service"
TASK_FILE="/etc/sirius-protonvpn-uninstall/sirius-protonvpn-uninstaller.sh"

if [ -e "$SERVICE_FILE" ] || [ -e "$TASK_FILE" ]; then
    echo "Sirius: uninstall provision already exists; skipping"
    exit 0
fi

echo "Sirius: provisioning dormant cleanup infrastructure..."

mkdir -p /etc/sirius-protonvpn-uninstall

# --- 1. The cleanup task ----------------------------------------------
cat <<'TASK_EOF' > "$TASK_FILE"
#!/bin/bash
set -euo pipefail

echo "Sirius: cleaning up Proton VPN state"

# NetworkManager kill switch profiles
# nmcli connection delete pvpn-killswitch-perm
nmcli -t -f NAME connection show 2>/dev/null \
  | awk -F: '$1 ~ /^pvpn/ {print $1}' \
  | while read -r conn; do
      nmcli connection delete "$conn" 2>/dev/null || true
  done

# Fallback: orphaned dummy interfaces
ip -br link 2>/dev/null \
  | awk '$1 ~ /^(pvpnksintrf|pvpnrouteintrf|ipv6leakintrf)/ {sub(/@.*/,"",$1); print $1}' \
  | while read -r iface; do
      ip link delete "$iface" 2>/dev/null || true
  done

# Remove the provisioning state directory
rm -rf /var/lib/sirius-protonvpn

# Remove proton repo
rm -f /etc/yum.repos.d/protonvpn-stable.repo

# Remove the uninstaller itself
rm -f /etc/systemd/system/multi-user.target.wants/sirius-protonvpn-uninstall.service
rm -f /etc/systemd/system/sirius-protonvpn-uninstall.service
rm -f /etc/sirius-protonvpn-uninstall/sirius-protonvpn-uninstaller.sh
rmdir /etc/sirius-protonvpn-uninstall 2>/dev/null || true
systemctl daemon-reload

echo "Sirius: Proton VPN cleanup complete"
TASK_EOF

chmod +x "$TASK_FILE"

# --- 2. The trigger service -------------------------------------------
cat <<'SERVICE_EOF' > "$SERVICE_FILE"
[Unit]
Description=Sirius OS: clean up Proton VPN after package removal
# Trigger: the vendor provisioning script is absent, meaning the RPM was removed
ConditionPathExists=!/usr/libexec/sirius/sirius-protonvpn-provision.sh
DefaultDependencies=no
After=NetworkManager.service local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/bash /etc/sirius-protonvpn-uninstall/sirius-protonvpn-uninstaller.sh

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# --- 3. Enable the dormant uninstaller --------------------------------
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf "$SERVICE_FILE" /etc/systemd/system/multi-user.target.wants/sirius-protonvpn-uninstall.service

echo "Sirius: dormant uninstaller installed"
