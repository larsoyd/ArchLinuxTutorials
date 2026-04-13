#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

key="73580DE2EDDFA6D6"
repo_name="xlibre"
repo_url="https://x11libre.net/repo/arch_based/x86_64"
pacman_conf="/etc/pacman.conf"

pacman-key --recv-keys "$key"
pacman-key --finger "$key"

echo
echo "Verify the fingerprint above matches the trusted source before continuing."
read -r "?Press Enter to locally sign the key, or Ctrl+C to abort... "

pacman-key --lsign-key "$key"

if ! grep -q '^\[xlibre\]$' "$pacman_conf"; then
  cp -a "$pacman_conf" "${pacman_conf}.bak.$(date +%Y%m%d-%H%M%S)"
  cat >> "$pacman_conf" <<EOF

[xlibre]
Server = $repo_url
EOF
fi

pacman -Syu --needed xlibre-xserver xlibre-input-libinput
