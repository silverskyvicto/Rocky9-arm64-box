#!/usr/bin/env bash
set -euo pipefail

ISO_URL="${ISO_URL:-https://dl.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-9.7-aarch64-minimal.iso}"
ISO_SHA256="${ISO_SHA256:-}"
ISO_PATH="${ISO_PATH:-}"
BOOT_DIR="${BOOT_DIR:-boot}"
LOCAL_ISO="${LOCAL_ISO:-packer_cache/Rocky-9.7-aarch64-minimal.iso}"

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
  7z l "$iso" images/pxeboot/vmlinuz images/pxeboot/initrd.img >/dev/null
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
need shasum

if [ -z "$ISO_SHA256" ]; then
  ISO_SHA256="$(ISO_URL="$ISO_URL" scripts/resolve-iso-checksum.sh)"
fi

if [ -s "$BOOT_DIR/vmlinuz" ] && [ -s "$BOOT_DIR/initrd.img" ]; then
  echo "boot assets already exist in $BOOT_DIR"
  exit 0
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

mkdir -p "$BOOT_DIR"
echo "extracting boot assets from $ISO_PATH"
7z e -y -o"$BOOT_DIR" "$ISO_PATH" images/pxeboot/vmlinuz images/pxeboot/initrd.img >/dev/null

test -s "$BOOT_DIR/vmlinuz"
test -s "$BOOT_DIR/initrd.img"

echo "extracted:"
ls -lh "$BOOT_DIR/vmlinuz" "$BOOT_DIR/initrd.img"
