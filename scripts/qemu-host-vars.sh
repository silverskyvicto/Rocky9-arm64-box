#!/usr/bin/env bash
set -euo pipefail

host_os="$(uname -s)"
host_arch="$(uname -m)"

find_first() {
  local path

  for path in "$@"; do
    if [ -f "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

require_value() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ]; then
    echo "error: could not resolve $name for $host_os $host_arch" >&2
    exit 1
  fi
}

case "$host_os:$host_arch" in
  Darwin:arm64)
    accelerator="hvf"
    machine_type="virt,highmem=off"
    qemu_binary="qemu-system-aarch64"
    firmware_code="$(find_first \
      /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
      /usr/local/share/qemu/edk2-aarch64-code.fd)"
    firmware_vars="$(find_first \
      /opt/homebrew/share/qemu/edk2-arm-vars.fd \
      /usr/local/share/qemu/edk2-arm-vars.fd)"
    ;;
  Linux:aarch64 | Linux:arm64)
    accelerator="kvm"
    machine_type="virt,highmem=off"
    qemu_binary="qemu-system-aarch64"
    firmware_code="$(find_first \
      /usr/share/AAVMF/AAVMF_CODE.fd \
      /usr/share/edk2/aarch64/QEMU_EFI-pflash.raw \
      /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
      /usr/share/qemu/edk2-aarch64-code.fd)"
    firmware_vars="$(find_first \
      /usr/share/AAVMF/AAVMF_VARS.fd \
      /usr/share/edk2/aarch64/vars-template-pflash.raw \
      /usr/share/qemu-efi-aarch64/QEMU_VARS.fd \
      /usr/share/qemu/edk2-arm-vars.fd)"
    ;;
  *)
    echo "error: unsupported host for arm64 QEMU build: $host_os $host_arch" >&2
    exit 1
    ;;
esac

require_value "EFI firmware code path" "$firmware_code"
require_value "EFI firmware vars path" "$firmware_vars"

printf -- '-var=qemu_binary=%q ' "$qemu_binary"
printf -- '-var=qemu_accelerator=%q ' "$accelerator"
printf -- '-var=qemu_machine_type=%q ' "$machine_type"
printf -- '-var=efi_firmware_code=%q ' "$firmware_code"
printf -- '-var=efi_firmware_vars=%q\n' "$firmware_vars"
