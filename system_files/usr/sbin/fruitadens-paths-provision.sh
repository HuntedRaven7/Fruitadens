#!/bin/bash
set -eoux pipefail

mkdir -p /var/lib/containers/storage
mkdir -p /var/home/core/.config/containers
chown -R core:core /var/home/core
