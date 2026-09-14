# Fruitadens

A bootc-native Fedora CoreOS 43 image with wifi firmware and optional k0s sysext, inspired by ucore and Bluefin Server.

## Features

- Based on Fedora CoreOS stable (currently FCOS 43)
- bootc-native image-based updates with atomic rollbacks
- WiFi firmware packages for common wireless adapters
- k0s as a systemd-sysext overlay (minimal base, optional Kubernetes)
- Cockpit web management (podman container)
- firewalld with server profile
- podman, docker-compose, docker-buildx
- tailscale and wireguard-tools
- tuned for atomic profiles
- fwupd-efi for firmware updates
- qemu-guest-agent and open-vm-tools

## Build

Requires `podman`, `cpp`, and `just`.

```bash
just build
just build-stable
just build-testing
```

## Push

```bash
just push
```

Requires `GHCR_USERNAME` and `GHCR_TOKEN` secrets configured.

## Test in QEMU

```bash
just test-vm
```

Boots the image in QEMU via `bootc install to-disk --via-loopback`.

## Install

### Using the installer container

Build and run the TUI installer:

```bash
just installer-build

podman run --rm --privileged \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  --security-opt label=type:unconfined_t \
  ghcr.io/huntedraven7/fruitadens-installer:latest
```

### Using the installer ISO

Build a bootable ISO:

```bash
just installer-iso
```

Boot the ISO and follow the TUI prompts to select disk, SSH key, and hostname.

### Auto-rebase (existing FCOS)

Install Fedora CoreOS, then rebase:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/huntedraven7/fruitadens:stable
```

### Manual install

```bash
podman run --rm --privileged \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  --security-opt label=type:unconfined_t \
  ghcr.io/huntedraven7/fruitadens:stable \
  bootc install to-disk /dev/sda \
    --root-ssh-authorized-keys "ssh-ed25519 ..." \
    --karg hostname=fruitadens
```

## First boot

```bash
sudo systemctl enable --now cockpit
sudo systemctl enable --now tailscaled
# k0s sysext is auto-activated
systemd-sysext list
```

## Streams

- `stable` — tracks Fedora CoreOS stable stream
- `testing` — tracks Fedora CoreOS testing stream

## Upstream

- Fedora CoreOS: https://getfedora.org/coreos/
- bootc: https://github.com/bootc-dev/bootc
- k0s: https://k0sproject.io/
- ucore: https://github.com/ublue-os/ucore
- Bluefin Server: https://github.com/projectbluefin/server

## Dependency Management

[Renovate](https://docs.renovatebot.com/) is configured for automated dependency updates:

- **k0s version** in `install-fruitadens.sh`
- **Fedora base images** in `Containerfile.in` and `installer/Containerfile`
- **GitHub Actions versions** in `.github/workflows/`

Renovate runs weekly and creates grouped PRs for each dependency category.
