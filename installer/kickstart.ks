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

%end
