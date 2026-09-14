#!/bin/bash
set -eoux pipefail

WORKDIR="${WORKDIR:-/workspace}"
INSTALLER_DIR="${WORKDIR}/installer"
KICKSTART_TEMPLATE="${INSTALLER_DIR}/kickstart.ks"
KICKSTART="${WORKDIR}/kickstart.ks"
FRUITADENS_IMAGE="${FRUITADENS_IMAGE:-ghcr.io/fruitadens/fruitadens:stable}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKDIR}/output}"

mkdir -p "$OUTPUT_DIR"

echo "Preparing kickstart with image: $FRUITADENS_IMAGE"
sed "s|IMAGE_PLACEHOLDER|${FRUITADENS_IMAGE}|g" "$KICKSTART_TEMPLATE" > "$KICKSTART"

echo "Building installer ISO with lorax..."
lorax \
  --product "Fruitadens Installer" \
  --version "$(date +%Y.%m.%d)" \
  --release "1" \
  --source "fedora" \
  --targetdir "${OUTPUT_DIR}/lorax" \
  --noverifyssl \
  --ks "$KICKSTART" \
  --volid FRUITADENS \
  "${OUTPUT_DIR}/iso"

echo "ISO build complete: ${OUTPUT_DIR}/iso/*.iso"
