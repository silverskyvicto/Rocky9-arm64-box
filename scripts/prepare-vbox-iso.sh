#!/usr/bin/env bash
set -euo pipefail

ISO_URL="${ISO_URL:-https://dl.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-9.7-aarch64-minimal.iso}"
ISO_SHA256="${ISO_SHA256:-}"
ISO_PATH="${ISO_PATH:-}"
LOCAL_ISO="${LOCAL_ISO:-packer_cache/Rocky-9.7-aarch64-minimal.iso}"
VBOX_ISO="${VBOX_ISO:-packer_cache/Rocky-9.7-aarch64-minimal-vbox.iso}"
WORK_DIR="${WORK_DIR:-packer_cache/vbox-iso-work}"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: '$1' is required." >&2
    exit 1
  fi
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

is_expected_iso() {
  local iso="$1"

  [ -f "$iso" ] || return 1
  [ "$(sha256_file "$iso")" = "$ISO_SHA256" ] || return 1
  7z l "$iso" EFI/BOOT/grub.cfg images/efiboot.img >/dev/null
}

find_cached_iso() {
  local cache_dir="${PACKER_CACHE_DIR:-$HOME/.cache/packer}"
  local iso

  [ -d "$cache_dir" ] || return 1

  while IFS= read -r iso; do
    if is_expected_iso "$iso"; then
      printf '%s\n' "$iso"
      return 0
    fi
  done < <(find "$cache_dir" -type f -name '*.iso' 2>/dev/null)

  return 1
}

need 7z
need perl
need shasum
need xorriso

if [ -z "$ISO_SHA256" ]; then
  ISO_SHA256="$(ISO_URL="$ISO_URL" scripts/resolve-iso-checksum.sh)"
fi

if [ -n "$ISO_PATH" ]; then
  if ! is_expected_iso "$ISO_PATH"; then
    echo "error: ISO_PATH does not match the expected Rocky 9.7 aarch64 minimal ISO: $ISO_PATH" >&2
    exit 1
  fi
else
  ISO_PATH="$(find_cached_iso || true)"
fi

if [ -z "$ISO_PATH" ]; then
  need curl
  mkdir -p "$(dirname "$LOCAL_ISO")"
  echo "downloading ISO to $LOCAL_ISO"
  curl -L --fail --output "$LOCAL_ISO" "$ISO_URL"
  ISO_PATH="$LOCAL_ISO"

  if ! is_expected_iso "$ISO_PATH"; then
    echo "error: downloaded ISO checksum or contents are invalid: $ISO_PATH" >&2
    exit 1
  fi
fi

if [ -s "$VBOX_ISO" ] && [ "$VBOX_ISO" -nt "$ISO_PATH" ] && [ "$VBOX_ISO" -nt http/ks-vbox.cfg ]; then
  echo "$VBOX_ISO"
  exit 0
fi

mkdir -p "$WORK_DIR" "$(dirname "$VBOX_ISO")"

echo "extracting GRUB config from $ISO_PATH" >&2
7z x -so "$ISO_PATH" EFI/BOOT/grub.cfg >"$WORK_DIR/grub.cfg"

perl -0pi -e '
  s/set default="[^"]+"/set default="0"/;
  s/set timeout=\d+/set timeout=5/;
  s{linux /images/pxeboot/vmlinuz inst\.stage2=hd:LABEL=Rocky-9-7-aarch64-dvd ro}
   {linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Rocky-9-7-aarch64-dvd ro inst.text inst.ks=hd:LABEL=Rocky-9-7-aarch64-dvd:/ks.cfg};
' "$WORK_DIR/grub.cfg"

rm -f "$VBOX_ISO"
echo "creating VirtualBox boot ISO at $VBOX_ISO" >&2
xorriso \
  -indev "$ISO_PATH" \
  -outdev "$VBOX_ISO" \
  -boot_image any replay \
  -map "$WORK_DIR/grub.cfg" /EFI/BOOT/grub.cfg \
  -map http/ks-vbox.cfg /ks.cfg \
  >/dev/null

test -s "$VBOX_ISO"
echo "$VBOX_ISO"
