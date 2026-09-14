#!/bin/bash
set -eoux pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRUITADENS_IMAGE="${FRUITADENS_IMAGE:-ghcr.io/fruitadens/fruitadens:stable}"
INSTALLER_IMAGE="${INSTALLER_IMAGE:-ghcr.io/fruitadens/fruitadens-installer:latest}"
WORKDIR="${INSTALLER_DIR}/build"
KICKSTART="${INSTALLER_DIR}/kickstart.ks"

mkdir -p "$WORKDIR"

echo "Building installer container..."
podman build -t "$INSTALLER_IMAGE" "$INSTALLER_DIR"

echo "Saving installer container..."
mkdir -p "$WORKDIR/container"
podman save "$INSTALLER_IMAGE" -o "$WORKDIR/container/installer.tar"

echo "Extracting installer container..."
mkdir -p "$WORKDIR/container/root"
tar -xf "$WORKDIR/container/installer.tar" -C "$WORKDIR/container/root"

INSTALLER_LAYER=$(find "$WORKDIR/container/root" -name "*.tar" | head -1)
mkdir -p "$WORKDIR/container/image"
tar -xf "$INSTALLER_LAYER" -C "$WORKDIR/container/image"

echo "Creating systemd service for auto-install..."
mkdir -p "$WORKDIR/container/image/etc/systemd/system"
cat > "$WORKDIR/container/image/etc/systemd/system/fruitadens-auto-install.service" <<'EOF'
[Unit]
Description=Fruitadens Auto-Install
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/fruitadens-installed

[Service]
Type=simple
ExecStartPre=/usr/bin/podman load -i /opt/installer/installer.tar
ExecStart=/usr/bin/podman run --rm --privileged \
    --pid=host --ipc=host \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    --security-opt label=type:unconfined_t \
    fruitadens-installer:latest
ExecStartPost=/usr/bin/touch /etc/fruitadens-installed
StandardOutput=tty
TTYPath=/dev/console

[Install]
WantedBy=multi-user.target
EOF

echo "Creating container tar for ISO..."
mkdir -p "$WORKDIR/container/opt/installer"
cp "$INSTALLER_LAYER" "$WORKDIR/container/opt/installer/installer.tar"
cp -r "$WORKDIR/container/image"/* "$WORKDIR/container/root/"

echo "Building ISO with lorax..."
if ! command -v lorax &>/dev/null; then
  echo "Installing lorax..."
  dnf -y install lorax
fi

lorax \
  --product "Fruitadens" \
  --version "$(date +%Y.%m.%d)" \
  --release "1" \
  --source "$WORKDIR/container/root" \
  --targetdir "$WORKDIR/lorax" \
  --noverifyssl \
  --ks "$KICKSTART" \
  --volid FRUITADENS \
  "$WORKDIR/iso"

echo "ISO build complete: $WORKDIR/iso/*.iso"
