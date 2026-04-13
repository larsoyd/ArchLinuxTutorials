#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

key="73580DE2EDDFA6D6"
repo_name="xlibre"
repo_url="https://x11libre.net/repo/arch_based/x86_64"
pacman_conf="/etc/pacman.conf"
aur_user="${SUDO_USER:-}"

if [[ -z "$aur_user" || "$aur_user" == "root" ]]; then
  echo "This script must be started from a regular user account with sudo." >&2
  echo "Example: ./script.sh" >&2
  exit 1
fi

pacman-key --recv-keys "$key"
pacman-key --finger "$key"

echo
echo "Verify the fingerprint above matches the trusted source before continuing."
read -r "?Press Enter to locally sign the key, or Ctrl+C to abort... "

pacman-key --lsign-key "$key"

if ! grep -q "^\[$repo_name\]$" "$pacman_conf"; then
  cp -a "$pacman_conf" "${pacman_conf}.bak.$(date +%Y%m%d-%H%M%S)"
  cat >> "$pacman_conf" <<EOF

[$repo_name]
Server = $repo_url
EOF
fi

# Refresh package databases and install XLibre packages
pacman -Syu --needed xlibre-xserver xlibre-input-libinput

# Build yay only if it is missing
if ! command -v yay >/dev/null 2>&1; then
  pacman -S --needed git base-devel

  sudo -H -u "$aur_user" bash <<'EOF'
set -euo pipefail

workdir="$(mktemp -d /tmp/yay-build.XXXXXX)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

git clone https://aur.archlinux.org/yay.git "$workdir/yay"
cd "$workdir/yay"
makepkg -si
EOF
fi

if ! command -v yay >/dev/null 2>&1; then
  echo "yay was not found after the build step." >&2
  exit 1
fi

# Install sonicde-meta from the AUR as the invoking user
sudo -H -u "$aur_user" yay -S --needed sonicde-meta
