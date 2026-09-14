#!/bin/bash
set -eoux pipefail

IMAGE="${FRUITADENS_IMAGE:-ghcr.io/huntedraven7/fruitadens:stable}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: installer must run as root" >&2
  exit 1
fi

if [[ ! -d /dev && ! -w /dev ]]; then
  echo "ERROR: /dev is not writable; run container with -v /dev:/dev and --privileged" >&2
  exit 1
fi

list_disks() {
  lsblk -d -n -o NAME,SIZE,TYPE | awk '$3 == "disk" {print "/dev/" $1 " (" $2 ")"}'
}

select_disk() {
  local disks
  disks=$(list_disks)
  if [[ -z "$disks" ]]; then
    echo "ERROR: no disks found" >&2
    exit 1
  fi
  local options=()
  while IFS= read -r line; do
    options+=("$line")
  done <<< "$disks"
  dialog --clear --title "Fruitadens Installer" \
    --menu "Select target disk (WILL BE WIPED):" 15 60 5 \
    "${options[@]}" 2>/tmp/fruitadens-disk
  cat /tmp/fruitadens-disk | tr -d '\n'
}

prompt_ssh_key() {
  local key
  while true; do
    key=$(dialog --clear --title "SSH Key" --inputbox "Enter SSH public key:" 10 60 "" 2>/tmp/fruitadens-ssh)
    if [[ -z "$key" ]]; then
      dialog --clear --title "SSH Key" --yesno "SSH key is required for remote access. Continue without?" 8 60
      if [[ $? -eq 0 ]]; then
        echo ""
        return
      fi
    else
      echo "$key"
      return
    fi
  done
}

prompt_hostname() {
  dialog --clear --title "Hostname" --inputbox "Enter hostname:" 8 60 "fruitadens" 2>/tmp/fruitadens-hostname
  cat /tmp/fruitadens-hostname | tr -d '\n'
}

prompt_k0s() {
  dialog --clear --title "k0s Kubernetes" --yesno "Enable k0s (single-node Kubernetes) via systemd-sysext?" 8 60
  echo $?
}

run_install() {
  local disk="$1"
  local ssh_key="$2"
  local hostname="$3"
  local enable_k0s="$4"

  local podman_args=(
    run --rm --privileged --pid=host --ipc=host
    -v /var/lib/containers:/var/lib/containers
    -v /dev:/dev
    --security-opt label=type:unconfined_t
  )

  local bootc_args=(install to-disk "$disk")

  if [[ -n "$ssh_key" ]]; then
    bootc_args+=(--root-ssh-authorized-keys "$ssh_key")
  fi

  bootc_args+=(--karg "hostname=$hostname")
  bootc_args+=(--karg "ip=dhcp")

  if [[ "$enable_k0s" -eq 0 ]]; then
    bootc_args+=(--karg "systemd.unit=k0s.service")
  fi

  echo "Running: podman ${podman_args[*]} $IMAGE ${bootc_args[*]}"
  podman "${podman_args[@]}" "$IMAGE" "${bootc_args[@]}"
}

main() {
  dialog --clear --title "Fruitadens Installer" --yesno \
    "This will DESTROY all data on the selected disk and install Fruitadens.\n\nContinue?" 10 60
  if [[ $? -ne 0 ]]; then
    echo "Installation cancelled."
    exit 0
  fi

  local disk ssh_key hostname enable_k0s

  disk=$(select_disk)
  echo "Selected disk: $disk"

  ssh_key=$(prompt_ssh_key)
  echo "SSH key: ${ssh_key:+set}"

  hostname=$(prompt_hostname)
  echo "Hostname: $hostname"

  enable_k0s=$(prompt_k0s)
  echo "k0s enabled: $([ "$enable_k0s" -eq 0 ] && echo yes || echo no)"

  dialog --clear --title "Confirm" --yesno \
    "Disk: $disk\nHostname: $hostname\nk0s: $([ "$enable_k0s" -eq 0 ] && echo yes || echo no)\n\nProceed with installation?" 12 60
  if [[ $? -ne 0 ]]; then
    echo "Installation cancelled."
    exit 0
  fi

  run_install "$disk" "$ssh_key" "$hostname" "$enable_k0s"

  echo "Installation complete. Remove installer media and reboot."
}

main "$@"
