#!/bin/bash
set -ouex pipefail

#### PREPARE
if [[ "testing" == "${FRUITADENS_STREAM:-}" ]]; then
  for REPO in $(ls /etc/yum.repos.d/fedora-updates-testing.repo); do
    if [[ "$(grep enabled=1 ${REPO} > /dev/null; echo $?)" == "1" ]]; then
      echo "enabling $REPO" &&
      sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' ${REPO}
    fi
  done
fi

dnf -y install dnf5-plugins
dnf -y copr enable ublue-os/packages && dnf -y copr disable ublue-os/packages
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

#### INSTALL
dnf -y install \
    bootc \
    cockpit-files \
    cockpit-networkmanager \
    cockpit-podman \
    cockpit-selinux \
    cockpit-system \
    docker-buildx \
    docker-compose \
    firewalld \
    fwupd-efi \
    open-vm-tools \
    podman \
    podman-compose \
    pv \
    qemu-guest-agent \
    tmux \
    usbutils \
    pciutils \
    wireguard-tools

dnf -y install --setopt=install_weak_deps=False \
    tuned \
    tuned-profiles-atomic

dnf -y install \
    NetworkManager-wifi \
    atheros-firmware \
    brcmfmac-firmware \
    iwlegacy-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    mt7xxx-firmware \
    nxpwireless-firmware \
    realtek-firmware \
    tiwilink-firmware

dnf -y --enable-repo=tailscale-stable install tailscale

#### K0S SYSEXT
K0S_VERSION="v1.30.0"
K0S_URL="https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64"

mkdir -p /usr/lib/extensions/k0s
cp -a /ctx/k0s-sysext/* /usr/lib/extensions/k0s/

curl -sSL "${K0S_URL}" -o /tmp/k0s-bin
install -D -m 0755 /tmp/k0s-bin /usr/lib/extensions/k0s/usr/bin/k0s
rm -f /tmp/k0s-bin

#### TWEAKS
sed -i '/^PRETTY_NAME/s/"$/ (Fruitadens)"/' /usr/lib/os-release
sed -i 's|^VARIANT_ID=.*|VARIANT_ID=fruitadens|' /usr/lib/os-release
sed -i 's|^VARIANT=.*|VARIANT="Fruitadens"|' /usr/lib/os-release
