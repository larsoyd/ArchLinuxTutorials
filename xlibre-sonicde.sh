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

user_home="$(getent passwd "$aur_user" | cut -d: -f6)"
user_group="$(id -gn "$aur_user")"

# SDDM theme name
sddm_theme="Sonic-Silver"

# Plasma Global Theme / Look-and-Feel package
# Change this one variable to switch variants:
#   org.kde.silverdarkbottompanel.desktop
#   org.kde.silverdarkleftpanel.desktop
#   org.kde.silverlightbottompanel.desktop
#   org.kde.silverlightleftpanel.desktop
plasma_lnf="${PLASMA_LNF:-org.kde.silverdarkbottompanel.desktop}"

pkg_installed() {
  pacman -Qq "$1" >/dev/null 2>&1
}

pacman_key_exists() {
  pacman-key --list-keys "$1" >/dev/null 2>&1
}

repo_exists() {
  pacman-conf --config "$pacman_conf" --repo-list | grep -Fxq -- "$repo_name"
}

repo_server_matches() {
  pacman-conf --config "$pacman_conf" --repo "$repo_name" Server 2>/dev/null | grep -Fxq -- "$repo_url"
}

set_kconfig_key() {
  local file="$1"
  local group="$2"
  local key="$3"
  local value="$4"

  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "$file" --group "$group" --key "$key" "$value"
    return
  fi

  python - "$file" "$group" "$key" "$value" <<'PY'
import configparser
import os
import sys

file_path, group, key, value = sys.argv[1:]
cfg = configparser.ConfigParser(interpolation=None)
cfg.optionxform = str

if os.path.exists(file_path):
    cfg.read(file_path)

if not cfg.has_section(group):
    cfg.add_section(group)

cfg.set(group, key, value)

parent = os.path.dirname(file_path)
if parent:
    os.makedirs(parent, exist_ok=True)

with open(file_path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
PY
}

# Import and locally sign the XLibre key only if it is not already present
if pacman_key_exists "$key"; then
  echo "Pacman key $key already exists, skipping key import/signing."
else
  pacman-key --recv-keys "$key"
  pacman-key --finger "$key"

  echo
  echo "Verify the fingerprint above matches the trusted source before continuing."
  read -r -p "Press Enter to locally sign the key, or Ctrl+C to abort... " _

  pacman-key --lsign-key "$key"
fi

# Add the XLibre repo only if it is not already configured
if repo_exists; then
  echo "Repository [$repo_name] is already configured, skipping pacman.conf edit."

  if ! repo_server_matches; then
    echo "Warning: [$repo_name] exists, but its configured Server does not include:" >&2
    echo "  $repo_url" >&2
    echo "Leaving the existing repo configuration unchanged." >&2
  fi
else
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
sudo -H -u "$aur_user" yay -S --needed sonicde-meta sonic-workspace-bin sonic-x11-session-bin kgamma sonic-workspace-wallpapers sonic-desktop-interface sonic-interface-libraries sonic-screenlocker sonic-screen sonic-keybind-daemon

# Configure SDDM theme
sddm_theme_dir="/usr/share/sddm/themes"
if [[ ! -d "$sddm_theme_dir/$sddm_theme" ]]; then
  echo "Could not find SDDM theme: $sddm_theme_dir/$sddm_theme" >&2
  exit 1
fi

install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-silver.conf <<EOF
[Theme]
Current=$sddm_theme
EOF

# Configure Plasma Look-and-Feel selection
plasma_theme_dir="/usr/share/plasma/look-and-feel/$plasma_lnf"
if [[ ! -d "$plasma_theme_dir" ]]; then
  echo "Requested Plasma global theme was not found: $plasma_lnf" >&2
  echo "Available Silver Plasma theme IDs:" >&2
  printf '  %s\n' \
    org.kde.silverdarkbottompanel.desktop \
    org.kde.silverdarkleftpanel.desktop \
    org.kde.silverlightbottompanel.desktop \
    org.kde.silverlightleftpanel.desktop >&2
  exit 1
fi

# System-wide default for new/clean Plasma configs
install -d -m 0755 /etc/xdg
set_kconfig_key /etc/xdg/kdeglobals KDE LookAndFeelPackage "$plasma_lnf"

# Seed the invoking user's config too
install -d -o "$aur_user" -g "$user_group" -m 0755 "$user_home/.config"
set_kconfig_key "$user_home/.config/kdeglobals" KDE LookAndFeelPackage "$plasma_lnf"
chown "$aur_user:$user_group" "$user_home/.config/kdeglobals"

# Best-effort live apply only if a Plasma session bus already exists
live_apply_done=0
user_uid="$(id -u "$aur_user")"
runtime_dir="/run/user/$user_uid"

if command -v plasma-apply-lookandfeel >/dev/null 2>&1 && [[ -S "$runtime_dir/bus" ]]; then
  if sudo -H -u "$aur_user" \
    env XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
    plasma-apply-lookandfeel --resetLayout --apply "$plasma_lnf"; then
    live_apply_done=1
  fi
fi

echo "Configured SDDM theme: $sddm_theme"

if (( live_apply_done )); then
  echo "Applied Plasma global theme to the active session: $plasma_lnf"
else
  echo "Staged Plasma global theme for the next Plasma login: $plasma_lnf"
fi
