#version=4000

lang en_US.UTF-8
keyboard us
timezone UTC

text

network --bootproto=dhcp --device=link --activate

bootloader --location=mbr --boot-drive=vda

zerombr
clearpart --all --initlabel --disklabel=gpt

part /boot/efi --fstype=efi --size=256 --grow --asprimary
part /boot --fstype=xfs --size=1024 --asprimary
part / --fstype=xfs --size=1 --grow --asprimary

rootpw --lock --iscrypted locked
user --name=installer --groups=wheel --password=installer

services --enabled=sshd,NetworkManager

%packages
@core
podman
dialog
findutils
util-linux
gdisk
ncurses
curl
git
%end

%post

cat > /etc/systemd/system/fruitadens-auto-install.service <<'EOF'
[Unit]
Description=Fruitadens Auto-Install
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/fruitadens-installed

[Service]
Type=simple
ExecStart=/usr/bin/podman run --rm --privileged \
    --pid=host --ipc=host \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    --security-opt label=type:unconfined_t \
    IMAGE_PLACEHOLDER
ExecStartPost=/usr/bin/touch /etc/fruitadens-installed
StandardOutput=tty
TTYPath=/dev/console

[Install]
WantedBy=multi-user.target
EOF

sed -i "s|IMAGE_PLACEHOLDER|${FRUITADENS_IMAGE}|g" /etc/systemd/system/fruitadens-auto-install.service

systemctl enable fruitadens-auto-install.service

%end
