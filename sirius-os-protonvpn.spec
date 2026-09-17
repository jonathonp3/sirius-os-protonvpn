%define debug_package %{nil}

Name:           sirius-os-protonvpn
Version:        1.0.0
Release:        1%{?dist}
Summary:        Proton VPN provisioning and lifecycle management for Sirius OS
License:        MIT
URL:            https://github.com/jonathonp3/sirius-os-protonvpn
BuildArch:      noarch

# --- SOURCES ---
Source0:        protonvpn-stable.repo
Source1:        sirius-protonvpn-provision.sh
Source2:        sirius-protonvpn-provision.service
Source3:        sirius-protonvpn-uninstall-provision.sh
Source4:        sirius-protonvpn-uninstall-provision.service

# --- BUILD REQUIREMENTS ---
BuildRequires:  systemd-rpm-macros

# --- RUNTIME REQUIREMENTS ---
Requires:       proton-vpn-gnome-desktop
Requires:       systemd
Requires:       NetworkManager
Requires:       nftables

# Replace upstream's release RPM if a user had it layered
Conflicts:      protonvpn-stable-release
Conflicts:      protonvpn-beta-release
Obsoletes:      protonvpn-stable-release < 2
Obsoletes:      protonvpn-beta-release < 2

%description
Layers Proton VPN on Fedora Atomic as a tracked package. Pulls in the
Proton VPN desktop client and runs a first-boot provisioning service for
setup that RPM scriptlets cannot perform under rpm-ostree. Ships and owns
/etc/yum.repos.d/protonvpn-stable.repo so the repository definition is
versioned and updated with the package; note that the repository must
already be present on the system before the first install, because
rpm-ostree resolves dependencies against the currently booted deployment
and cannot read a repo file from a package staged in the same transaction.
Includes a dormant uninstaller that removes the persistent NetworkManager
kill-switch profile left behind by the Advanced kill switch setting.

%prep
# nothing to unpack

%build
# nothing to build

%install
install -Dpm0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/yum.repos.d/protonvpn-stable.repo

install -Dpm0755 %{SOURCE1} %{buildroot}%{_libexecdir}/sirius/sirius-protonvpn-provision.sh
install -Dpm0644 %{SOURCE2} %{buildroot}%{_unitdir}/sirius-protonvpn-provision.service

install -Dpm0755 %{SOURCE3} %{buildroot}%{_libexecdir}/sirius/sirius-protonvpn-uninstall-provision.sh
install -Dpm0644 %{SOURCE4} %{buildroot}%{_unitdir}/sirius-protonvpn-uninstall-provision.service

# Static enablement for both vendor-layer bootstrap units
mkdir -p %{buildroot}%{_unitdir}/multi-user.target.wants
ln -s ../sirius-protonvpn-provision.service \
    %{buildroot}%{_unitdir}/multi-user.target.wants/sirius-protonvpn-provision.service
ln -s ../sirius-protonvpn-uninstall-provision.service \
    %{buildroot}%{_unitdir}/multi-user.target.wants/sirius-protonvpn-uninstall-provision.service

%files
%config(noreplace) %{_sysconfdir}/yum.repos.d/protonvpn-stable.repo

%{_libexecdir}/sirius/sirius-protonvpn-provision.sh
%{_libexecdir}/sirius/sirius-protonvpn-uninstall-provision.sh

%{_unitdir}/sirius-protonvpn-provision.service
%{_unitdir}/sirius-protonvpn-uninstall-provision.service
%{_unitdir}/multi-user.target.wants/sirius-protonvpn-provision.service
%{_unitdir}/multi-user.target.wants/sirius-protonvpn-uninstall-provision.service

%changelog
* Fri Sep 18 2026 Jonathon P <jonathon@sirius-os> - 1.0.0-1
- Initial release
