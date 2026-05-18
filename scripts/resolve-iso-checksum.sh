#!/usr/bin/env bash
set -euo pipefail

ISO_URL="${ISO_URL:-https://dl.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-9.7-aarch64-minimal.iso}"
CHECKSUM_URL="${CHECKSUM_URL:-${ISO_URL}.CHECKSUM}"
CHECKSUM_PATH="${CHECKSUM_PATH:-packer_cache/$(basename "$ISO_URL").CHECKSUM}"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: '$1' is required." >&2
    exit 1
  fi
}

read_checksum() {
  local checksum_file="$1"
  local iso_name="$2"

  awk -v iso_name="$iso_name" '
    $0 ~ "SHA256 \\(" iso_name "\\)" {
      print $NF
      found = 1
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$checksum_file"
}

need awk

if [ ! -f "$CHECKSUM_PATH" ]; then
  need curl
  mkdir -p "$(dirname "$CHECKSUM_PATH")"
  echo "downloading checksum to $CHECKSUM_PATH" >&2
  curl -L --fail --output "$CHECKSUM_PATH" "$CHECKSUM_URL" >&2
fi

read_checksum "$CHECKSUM_PATH" "$(basename "$ISO_URL")"
