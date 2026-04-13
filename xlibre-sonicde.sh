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

pkg_installed() {
  pacman -Qq "$1" >/dev/null 2>&1
}

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

# Remove Plasma Login Manager if it is installed
if pkg_installed plasma-login-manager; then
  pacman -Rns plasma-login-manager
fi

# Install SDDM if it is not installed
if ! pkg_installed sddm; then
  pacman -S --needed sddm
fi

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

# Install SonicDE from the AUR as the invoking user
sudo -H -u "$aur_user" yay -S --needed sonicde-meta

# Set the SDDM theme to Sonic Silver
sddm_theme_dir="/usr/share/sddm/themes"
sddm_theme=""

if [[ -d "$sddm_theme_dir/Sonic-Silver" ]]; then
  sddm_theme="Sonic-Silver"
elif [[ -d "$sddm_theme_dir/sonic-silver" ]]; then
  sddm_theme="sonic-silver"
else
  echo "Could not find the Sonic Silver SDDM theme in $sddm_theme_dir" >&2
  echo "Expected one of:" >&2
  echo "  $sddm_theme_dir/Sonic-Silver" >&2
  echo "  $sddm_theme_dir/sonic-silver" >&2
  exit 1
fi

install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-silver.conf <<EOF
[Theme]
Current=$sddm_theme
EOF

echo "Configured SDDM theme: $sddm_theme"
