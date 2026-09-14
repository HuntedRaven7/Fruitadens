#!/bin/bash
set -ouex pipefail

systemctl mask zincati.service
systemctl disable docker.socket
systemctl enable rpm-ostreed-automatic.timer
sed -i 's/#AutomaticUpdatePolicy.*/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf

ln -s ../usr/share/zoneinfo/UTC /etc/localtime

cp -a /etc/firewalld/firewalld-server.conf /etc/firewalld/firewalld.conf

systemctl enable systemd-sysext.service
