# Fruitadens Installer

Containerized TUI installer for Fruitadens. Can be run from any Linux system with podman, or used to build a bootable ISO.

## Run from existing Linux

```bash
podman run --rm --privileged \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  --security-opt label=type:unconfined_t \
  ghcr.io/fruitadens/fruitadens-installer:latest
```

## Build installer container

```bash
cd installer
podman build -t fruitadens-installer:latest .
```

## Build ISO

Requires `lorax`, `xorriso`, and `skopeo`.

```bash
cd installer
sudo ./build-iso.sh
```

Output: `fruitadens-installer-YYYY.MM.DD.iso`

## ISO contents

- Fedora minimal base with podman
- fruitadens-installer container pre-loaded
- Auto-starts installer TUI on boot
- Supports disk selection, SSH key injection, hostname configuration
