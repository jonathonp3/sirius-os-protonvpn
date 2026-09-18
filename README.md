# sirius-os-protonvpn

## Why This Exists

This package is a reference implementation for the Sirius Provisioning
Framework. It demonstrates the dormant uninstaller pattern on a real,
reproducible upstream bug: Proton VPN's Advanced kill switch leaves a
NetworkManager profile behind that `rpm-ostree remove` cannot clean up.
The package exists as much to document the pattern as to solve the
problem.

The bug itself is a consequence of how `rpm-ostree` handles package
removal. On Fedora Atomic systems, `rpm-ostree remove` does not run `%preun`
scriptlets. The deployment is composed fresh without the package rather
than uninstalled in place. Any cleanup the package would have done in
`%preun` is lost.

For Proton VPN this matters because the Advanced kill switch writes a
persistent NetworkManager profile to:

    /etc/NetworkManager/system-connections/pvpn-killswitch-perm.nmconnection

NetworkManager reads that file on every boot and recreates a dummy
interface (`pvpnksintrf1`) with a default route metric lower than any
real connection. The result is a machine with no internet, no VPN
installed, and no visible cause.

This was reproduced on a clean Silverblue install:

- Install Proton VPN from the upstream repository
- Enable the Advanced kill switch in the app
- `rpm-ostree remove proton-vpn-gnome-desktop && reboot`
- `ping 1.1.1.1` returns 100% packet loss
- `nmcli connection show | grep pvpn` still lists the profile
- `/etc/NetworkManager/system-connections/` still contains the file

`sirius-os-protonvpn` ships a dormant uninstaller that removes the
profile on the next boot after the package is gone, restoring network
access without user intervention.

## Installation

### Prerequisite — seed the Proton VPN repository

Before installing this package, the Proton VPN repository must be
present on the system. Run:

```bash
sudo tee /etc/yum.repos.d/protonvpn-stable.repo <<'EOF'
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-$releasever-stable
enabled=1
gpgcheck=1
gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc
EOF
```

## Install

```bash
sudo rpm-ostree install sirius-os-protonvpn
sudo systemctl reboot
```

## Why the prerequisite exists

This is not a packaging oversight — it is a hard constraint of
rpm-ostree.

rpm-ostree computes a transaction's dependency graph using the
repositories visible on the currently booted deployment. It does not
read .repo files out of packages it is staging in the same
transaction. So a repository shipped inside an RPM cannot be used to
resolve that RPM's own Requires: in the transaction that installs it.

Because sirius-os-protonvpn has Requires: proton-vpn-gnome-desktop,
and that package lives in Proton's repository, the Proton repository must
already be visible before rpm-ostree install runs. There are only three
ways to achieve that, and only one of them preserves GPG verification:

| Approach | Repo visible at install | GPG verified | Manual step |
|---|---|---|---|
| Seed the repo file first (`tee`) | Yes | Yes | One `tee` command |
| COPR Runtime Dependencies | Yes | **No** (`gpgcheck=0` forced) | None |
| Ship repo inside the RPM | Only after reboot | Yes | Install + reboot first |


COPR's Runtime Dependencies feature cannot be used here because it
hardcodes gpgcheck=0 for external repositories — COPR has no way to
know or configure Proton's GPG key. Installing Proton's packages without
signature verification is not acceptable for a VPN client.

Shipping the repo file inside the RPM does not help either: the file
lands on disk during the install transaction, but rpm-ostree has
already resolved Requires: by then. The user would need to install,
reboot, then install proton-vpn-gnome-desktop in a second transaction —
two reboots instead of one, and no security benefit over the tee step.

Seeding the repo file manually is therefore the only approach that
installs everything in a single transaction with full GPG verification.

Once the repository is seeded and this package is layered, the shipped
protonvpn-stable.repo (installed as %config(noreplace)) takes over
ownership of that path, and all future upgrades resolve from the
repository normally.


## What This Package Does After Install

Pulls in proton-vpn-gnome-desktop as a tracked layered dependency

Owns /etc/yum.repos.d/protonvpn-stable.repo so the repo definition is
versioned and updated with the package

Ships a first-boot provisioning service for setup that RPM scriptlets
cannot perform under rpm-ostree

Ships a dormant uninstaller that removes the persistent NetworkManager
kill-switch profile left behind by the Advanced kill switch setting


## Uninstalling
```bash
sudo rpm-ostree remove sirius-os-protonvpn
sudo systemctl reboot
```

Tested on a clean Fedora Silverblue 44 install.


1. Install Proton VPN from the upstream repository

```bash
sudo tee /etc/yum.repos.d/protonvpn-stable.repo <<'EOF'
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-$releasever-stable
enabled=1
gpgcheck=1
gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc
EOF

sudo rpm-ostree install proton-vpn-gnome-desktop
sudo systemctl reboot
```

2. Enable the Advanced kill switch


Launch the app, connect to any server, disconnect, then:

Settings → Kill switch → Advanced

Confirm the persistent profile exists:

```bash
nmcli -t -f NAME,TYPE,FILENAME connection show | grep pvpn
# pvpn-killswitch-perm:dummy:/etc/NetworkManager/system-connections/pvpn-killswitch-perm.nmconnection
```

3. Remove the package and reboot

```bash
rpm-ostree remove proton-vpn-gnome-desktop
systemctl reboot
```


4. Observe the failure

```bash
ping -c1 1.1.1.1
# 100% packet loss

ip -br link | grep pvpn
# pvpnksintrf1 UNKNOWN ...
```

5. Confirm the fix

```bash
sudo nmcli connection delete pvpn-killswitch-perm
ping -c1 1.1.1.1
# 1 received, 0% packet loss
```

The dormant uninstaller in this package runs step 5 automatically on
the first boot after the package is removed.

License

MIT

This project is built and hosted via [Fedora COPR](https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os-protonvpn/).

Part of the [Sirius Provisioning Framework](https://github.com/jonathonp3/sirius-provisioning-framework).
