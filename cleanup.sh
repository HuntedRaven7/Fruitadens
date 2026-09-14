#!/usr/bin/bash
set -eoux pipefail

find /boot/ -maxdepth 1 -mindepth 1 -exec rm -fr {} \; || true
find /tmp/* -maxdepth 0 -type d \! -name rpms -exec rm -fr {} \;
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \;
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \;

ostree container commit

mkdir -p /var/tmp \
  && chmod -R 1777 /var/tmp
