#!/usr/bin/env bash

# Import the repository key
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
# Sign the repository key
pacman-key --lsign-key F3B607488DB35A47

# Install the necessary mirrors:
pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst' \
'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.0.0.r7.g1f38429-2-x86_64.pkg.tar.zst'
