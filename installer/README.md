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
just installer-build
```

## Build ISO in container

Requires `podman` with `--privileged` support.

```bash
FRUITADENS_IMAGE=ghcr.io/fruitadens/fruitadens:stable just installer-iso
```

Or run the ISO builder directly:

```bash
podman build -t fruitadens-iso-builder:latest installer/iso-builder/
mkdir -p /tmp/fruitadens-iso/output/iso /tmp/fruitadens-iso/output/rootfs
podman run --rm --privileged \
  -v /tmp/fruitadens-iso:/workspace \
  -e FRUITADENS_IMAGE=ghcr.io/fruitadens/fruitadens:stable \
  fruitadens-iso-builder:latest
```

Output: `/tmp/fruitadens-iso/output/fruitadens-installer.iso`

The ISO is a minimal live image that auto-starts the Fruitadens installer TUI on boot. It embeds the installer container and the target Fruitadens image reference.
