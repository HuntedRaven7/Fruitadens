# Fruitadens Implementation Plan

Build a bootc-native Fedora CoreOS 43 image with wifi firmware and optional k0s sysext, plus a custom installer ISO, following ucore's build pattern.

## 1. Base Image Strategy

- Upstream: `quay.io/fedora/fedora-coreos:stable` (currently FCOS 43)
- "One behind" policy: when FCOS moves to 45, pin builds to the last FCOS 44 stable tag until verified
- Track via `renovate.json` or manual workflow pin on the `UPSTREAM_IMAGE` variable
- Image name: `ghcr.io/<user>/fruitadens:stable` (and `:testing` if desired)

## 2. Image Scope

Single image tier `fruitadens` based on ucore-minimal's package set, plus:
- WiFi firmware packages (from ucore's `install-ucore.sh`)
- k0s sysext overlay (from Bluefin Server's pattern)

Do NOT include ucore's NAS/HCI extras (mergerfs, snapraid, libvirt) in v1.

## 3. Repository Structure

```
fruitadens/
├── Containerfile.in          # cpp-preprocessed main image definition
├── Justfile                  # build/test/CI automation
├── ci-deps.json              # CI artifact dependencies (akmods, etc)
├── cleanup.sh                # post-build cleanup, ostree container commit
├── install-fruitadens.sh     # main package installation script
├── post-install.sh           # systemd enable/mask, config tweaks
├── system_files/
│   └── etc/
│       ├── systemd/
│       │   └── system/       # custom units (k0s-sysext, paths-provision, etc)
│       └── containers/
│           └── policy.json   # container image signing policy
└── k0s-sysext/
    ├── usr/
    │   ├── bin/              # k0s binary or symlink
    │   └── lib/systemd/      # systemd units for k0s
    └── etc/
```

## 4. Containerfile.in

```dockerfile
# /* FROMs for copying */
FROM scratch AS ctx
COPY / /

# /* fruitadens image */
FROM quay.io/fedora/fedora-coreos:stable AS fruitadens
COPY system_files/etc /etc
RUN --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,src=/,dst=/ctx \
    /ctx/install-fruitadens.sh \
    && /ctx/post-install.sh \
    && /ctx/cleanup.sh
RUN ["bootc", "container", "lint"]
```

Key differences from ucore:
- No akmods/kernel replacement (use FCOS stock kernel for simplicity in v1)
- No NVIDIA or ZFS layering in v1

## 5. install-fruitadens.sh

```bash
#!/bin/bash
set -ouex pipefail

# Repos
dnf -y install dnf5-plugins
dnf -y copr enable ublue-os/packages && dnf -y copr disable ublue-os/packages

# Core packages (ucore-minimal set)
dnf -y install \
    bootc \
    cockpit-files cockpit-networkmanager cockpit-podman cockpit-selinux cockpit-system \
    docker-buildx docker-compose \
    firewalld \
    open-vm-tools \
    podman podman-compose \
    qemu-guest-agent \
    tailscale wireguard-tools \
    tmux \
    pv \
    fwupd-efi

# WiFi firmware (from ucore's install-ucore.sh)
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
    tiwilink-firmware \
    usbutils \
    pciutils

# k0s sysext
# Build k0s binary into a systemd-sysext overlay at /opt/k0s-sysext
# See section 7 below

# Tweak os-release
sed -i '/^PRETTY_NAME/s/"$/ (Fruitadens)"/' /usr/lib/os-release
sed -i 's|^VARIANT_ID=.*|VARIANT_ID=fruitadens|' /usr/lib/os-release
sed -i 's|^VARIANT=.*|VARIANT="Fruitadens"|' /usr/lib/os-release
```

## 6. post-install.sh

```bash
#!/bin/bash
set -ouex pipefail

# Disable zincati (OCI images use bootc, not zincati)
systemctl mask zincati.service

# Enable staged rpm-ostree automatic updates
systemctl enable rpm-ostreed-automatic.timer
sed -i 's/#AutomaticUpdatePolicy.*/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf

# Enable cockpit service (disabled by default in FCOS)
# (ucore runs cockpit as a container unit; for v1 you can either do the same
#  or just enable cockpit-ws -- pick one, recommend podman container unit)

# Enable k0s sysext on boot
systemctl enable systemd-sysext.service

# Container signing policy
cp /usr/share/fruitadens/signing/usr/etc/containers/policy.json /etc/containers/policy.json
```

## 7. k0s Sysext

Follow Bluefin Server's approach: build k0s as a `systemd-sysext` overlay so the base image stays minimal.

Layout:
```
k0s-sysext/
├── usr/
│   ├── bin/k0s              # k0s binary (from upstream release)
│   └── lib/systemd/system/
│       ├── k0s.service
│       ├── k0scontroller.service
│       └── k0sworker.service
└── etc/
    └── sysctl.d/            # any k0s sysctl tweaks
```

Build steps in `install-fruitadens.sh`:
1. Download pinned k0s release binary for x86_64
2. Create `/opt/k0s-sysext/` with the above structure
3. Run `systemd-sysext merge /opt/k0s-sysext` at build time (so it's available in the committed image)
4. Enable `systemd-sysext.service` in `post-install.sh`

Pinning: use a pinned k0s version in `install-fruitadens.sh`; bump deliberately.

## 8. Installer ISO

### Approach A (recommended for v1): bootc-image-builder Anaconda ISO
- Use `quay.io/centos-bootc/bootc-image-builder:latest` with `--type anaconda-iso`
- Embed Ignition/kickstart that runs:
  ```
  bootc install to-disk /dev/sda --root-ssh-authorized-keys <key>
  ```
- Limitation: Anaconda is heavy (~600MB ISO)

### Approach B (lighter): Custom FCOS live ISO with TUI
- Base on FCOS live ISO
- Inject a TUI script (`dialog`/`whiptail`) that collects:
  - Target disk
  - SSH public key
  - Hostname
  - Whether to enable k0s
- Run `podman run --privileged <image> bootc install to-disk <disk>` with collected args
- Much lighter than Anaconda, closer to Bluefin Server's `systemd-sysinstall` feel

**Recommendation**: Start with Approach A for speed of implementation; switch to B later for ISO size.

## 9. CI Workflow

Three workflows matching ucore:
- `.github/workflows/build-stable.yml` — daily scheduled + manual trigger
- `.github/workflows/build-testing.yml` — same, tracking FCOS testing stream
- `.github/workflows/reusable-build.yml` — shared build logic

Build steps:
1. `cpp` preprocess `Containerfile.in` → `Containerfile`
2. `podman build --layers` using the generated Containerfile
3. `bootc container lint` during build
4. `skopeo inspect` to verify image
5. Push to `ghcr.io/<user>/fruitadens:<stream>-<date>`
6. Update moving tag (`:stable`, `:testing`)
7. Optional: generate provenance, SBOM, changelog (mirror ucore's approach later)

## 10. "One Behind" Pinning Mechanism

- Track FCOS stable stream version via `renovate.json` or a version file
- When FCOS updates to a new major version, workflow should:
  1. Detect upstream change
  2. Keep `UPSTREAM_IMAGE` pinned to last-known-good until manually promoted
  3. Create a draft issue/PR to promote to new FCOS version after testing
- For v1, manual pinning in the workflow is sufficient

## 11. User-Facing Install Flow

```bash
# 1. Download installer ISO
# 2. Boot target machine from ISO
# 3. Run TUI installer, provide SSH key and disk target
# 4. Installer runs bootc install to-disk
# 5. Reboot into Fruitadens

# First boot on installed system:
sudo systemctl enable --now cockpit.socket    # if enabled
sudo systemctl enable --now tailscaled
# k0s sysext is auto-activated via systemd-sysext.service
```

## 12. Out of Scope for v1

- NVIDIA drivers (add later if needed)
- ZFS (add later if needed)
- HCI/libvirt tier
- Image signing/cosign (can add later)
- SBOMs and provenance reports (add later)
- aarch64 builds (start x86_64 only)
- SecureBoot MOK enrollment (add later)

## 13. Validation

- `bootc container lint` passes during build
- Image boots in QEMU/VM: `bootc install to-disk --via-loopback` then boot
- Verify `bootc status` shows correct image reference
- Verify k0s sysext: `systemd-sysext list` shows k0s
- Verify wifi firmware: `lspci -k` shows firmware loaded for wireless devices
- Verify cockpit accessible on boot
