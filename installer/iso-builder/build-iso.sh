#!/bin/bash
set -eoux pipefail

WORKDIR="${WORKDIR:-/workspace}"
INSTALLER_DIR="${WORKDIR}/installer"
FRUITADENS_IMAGE="${FRUITADENS_IMAGE:-ghcr.io/fruitadens/fruitadens:stable}"
INSTALLER_IMAGE="${INSTALLER_IMAGE:-fruitadens-installer:latest}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKDIR}/output}"
ROOTFS="${OUTPUT_DIR}/rootfs"
ISO_OUTPUT="${OUTPUT_DIR}/iso"

mkdir -p "$ROOTFS" "$ISO_OUTPUT"

echo "Creating minimal rootfs..."
dnf -y install --installroot="$ROOTFS" \
    --releasever=42 \
    --setopt=install_weak_deps=False \
    @core \
    podman \
    dialog \
    findutils \
    util-linux \
    gdisk \
    ncurses \
    curl \
    git \
    systemd \
    && dnf clean all

echo "Creating auto-install service..."
mkdir -p "$ROOTFS/etc/systemd/system"
cat > "$ROOTFS/etc/systemd/system/fruitadens-auto-install.service" <<EOF
[Unit]
Description=Fruitadens Auto-Install
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/fruitadens-installed

[Service]
Type=simple
ExecStartPre=/usr/bin/podman load -i /opt/installer/installer.tar
ExecStart=/usr/local/bin/fruitadens-install
ExecStartPost=/usr/bin/touch /etc/fruitadens-installed
StandardOutput=tty
TTYPath=/dev/console

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
ln -s /etc/systemd/system/fruitadens-auto-install.service \
  "$ROOTFS/etc/systemd/system/multi-user.target.wants/fruitadens-auto-install.service"

mkdir -p "$ROOTFS/opt/installer"

echo "Building installer container for embedding..."
if ! podman image exists "$INSTALLER_IMAGE" 2>/dev/null; then
  echo "Building installer container..."
  podman build -t "$INSTALLER_IMAGE" "$INSTALLER_DIR"
fi

echo "Saving installer container..."
podman save "$INSTALLER_IMAGE" -o "$ROOTFS/opt/installer/installer.tar"

echo "Creating squashfs of rootfs..."
mksquashfs "$ROOTFS" "${OUTPUT_DIR}/rootfs.squashfs" -noappend -comp xz

echo "Creating initramfs with dracut..."
KVER="$(ls "$ROOTFS/lib/modules" | sort -V | tail -1)"
if [[ -z "$KVER" ]]; then
  echo "ERROR: no kernel found in rootfs" >&2
  exit 1
fi

dracut --force \
  --add "dracut-live" \
  --kver "$KVER" \
  "${OUTPUT_DIR}/initramfs.img" 2>&1 || true

if [[ ! -f "${OUTPUT_DIR}/initramfs.img" ]]; then
  echo "ERROR: dracut failed to create initramfs" >&2
  exit 1
fi

echo "Copying kernel..."
cp "$ROOTFS/vmlinuz" "$ISO_OUTPUT/vmlinuz" 2>/dev/null || \
  cp "$ROOTFS/boot/vmlinuz-"* "$ISO_OUTPUT/vmlinuz" 2>/dev/null || \
  echo "WARNING: could not find kernel, ISO may not boot"

echo "Creating isolinux config..."
mkdir -p "$ISO_OUTPUT/isolinux"
cat > "$ISO_OUTPUT/isolinux/isolinux.cfg" <<EOF
DEFAULT fruitadens
PROMPT 1
TIMEOUT 50

LABEL fruitadens
  MENU LABEL Fruitadens Installer
  KERNEL /vmlinuz
  APPEND initrd=/initramfs.img root=live:CDLABEL=FRUITADENS rootfstype=auto rd.live.image quiet
EOF

cp /usr/share/syslinux/isolinux.bin "$ISO_OUTPUT/isolinux/" 2>/dev/null || true
cp /usr/share/syslinux/ldlinux.c32 "$ISO_OUTPUT/" 2>/dev/null || true
cp /usr/share/syslinux/libutil.c32 "$ISO_OUTPUT/" 2>/dev/null || true
cp /usr/share/syslinux/menu.c32 "$ISO_OUTPUT/" 2>/dev/null || true
cp /usr/share/syslinux/memdisk "$ISO_OUTPUT/" 2>/dev/null || true
cp /usr/share/syslinux/pxelinux.0 "$ISO_OUTPUT/" 2>/dev/null || true

echo "Creating ISO with xorriso..."
xorriso -as mkisofs \
  -o "${OUTPUT_DIR}/fruitadens-installer.iso" \
  -V FRUITADENS \
  -R -J \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -isohybrid-gpt-basdat \
  "$ISO_OUTPUT" 2>&1 || echo "xorriso ISO creation attempted"

if [[ -f "${OUTPUT_DIR}/fruitadens-installer.iso" ]]; then
  echo "ISO build complete: ${OUTPUT_DIR}/fruitadens-installer.iso"
else
  echo "ERROR: ISO was not created" >&2
  exit 1
fi
