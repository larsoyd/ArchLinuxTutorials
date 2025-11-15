# Complete Arch Linux Tutorial (AwesomeWM w/ Automounting Partitions)

This is a Arch installation guide for the awesome window manager on Arch Linux.

**GPT Auto-Mount + awesome + NVIDIA**

> **Prerequisites:** This guide assumes you have an AMD processor with NVIDIA graphics.

## Boot from ISO

Set up your keyboard layout if you're not on an US keyboard, and verify UEFI boot:

```bash
loadkeys no-latin1

# the default font for an arch install is tiny and it only gets worse as you get older
# here is how you get it to something readable
setfont ter-118n

# Sync system clock
timedatectl set-ntp true

# --- Web Test (wired & Wi-Fi) ---

# See your links & their state (names like enpXsY for Ethernet, wlan0 for Wi-Fi)
ip link           # interface listing
networkctl list   # networkd's view; "configured" with DHCP is what you want

---

Ethernet:

# If you're on Ethernet, DHCP should be automatic on the ISO.
# You can confirm an IPv4/IPv6 address like:
networkctl status | sed -n '1,80p'   # look for "Address:" and "Gateway:"

---

Wi-Fi:

# If you're on Wi-Fi, (1) make sure nothing is soft-blocked, (2) connect with iwctl.
rfkill list
rfkill unblock all         # if you see "Soft blocked: yes" for wlan      (safe to run always)

# Discover your wireless device name (often "wlan0" on ISO)
iwctl device list          

# Scan & connect (replace SSID if your AP name has spaces keep the quotes)
iwctl station "YOUR-DEV" scan
iwctl station "YOUR-DEV" get-networks
iwctl station "YOUR-DEV" connect "YOUR-SSID"   # iwctl will prompt for passphrase

---

# DNS & IP sanity checks (these distinguish raw IP reachability vs DNS resolution)
ping -c 3 archlinux.org
```

## Partition the NVMe drive with systemd-repart

```bash
lsblk -l

# Set the device you want to operate on
d=/dev/nvme0n1   # change if lsblk shows a different path

# Define the desired partitions for systemd-repart using nano
mkdir -p /tmp/repart.d
```

```bash
# Create 10-esp.conf
nano /tmp/repart.d/10-esp.conf

# 10-esp.conf
[Partition]
Type=esp
Label=EFI
Format=vfat
SizeMinBytes=2G
SizeMaxBytes=2G
```

```bash
# Create 20-root.conf
nano /tmp/repart.d/20-root.conf

# 20-root.conf
[Partition]
Type=root
Label=root
Format=ext4
```

```bash
# Preview the plan 
systemd-repart --definitions=/tmp/repart.d --empty=force "$d"

# Apply the changes for real. Pick ONE of these options.
#
# OPTION A) Normally without fast_commit:
#
systemd-repart --definitions=/tmp/repart.d --dry-run=no --empty=force "$d"

---

# OPTION B) If you want `fast_commit` enabled you run this command.
#
# ext4 has a faster journaling system called fast_commit
# Note that some users have reported instability using it, however.
# It should be fine nowadays, but if unsure don't enable it.
#
# According to the Arch wiki it significantly improves journaling performance:
#
SYSTEMD_REPART_MKFS_OPTIONS_EXT4='-O fast_commit' \
  systemd-repart --definitions=/tmp/repart.d --dry-run=no --empty=force "$d"

---

# Optional: verify results
lsblk -f "$d"

# Optional: verify fast_commit results
# You should see fast_commit listed under features:
tune2fs -l /dev/disk/by-label/root | grep features

# optional, stronger check:
dumpe2fs -h /dev/disk/by-label/root | grep -i 'Fast commit length'
```

## Mount filesystems (labels match your original layout)

```bash
# Mount root first
mount /dev/disk/by-label/root /mnt
```

### Create and mount EFI directory with strict masks

#### Here is some information on why I am mounting EFI like this:

```md
Those options are a security-friendly way to mount the EFI System Partition.
They won’t get in your way for normal use.

fmask=0177 and dmask=0077: VFAT does not store Unix permissions.
These masks tell the kernel how to fake them: files become 600 (owner read/write, no exec),
directories 700 (owner only).

In other words, only root can read or write there, and files are not marked executable.
They are the right defaults for an EFI partition and won’t interfere with normal operation.

noexec: blocks running programs from that filesystem. 
nodev: device files on that filesystem are not treated as devices. 
nosuid: any setuid or setgid bit is ignored, so binaries there cannot gain elevated privileges.
```

```bash
mkdir -p /mnt/efi
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

---

## Optional: Stop mkinitcpio From Running After Pacstrap

If you are like me you find it annoying to have a redundant step where it does this after pacstrap
considering we will be disabling fallback and also doing it later anyways. Generating the MODULES and HOOKS can be time consuming
on some older systems. You can disable the hook in the ArchISO only by doing this. **NB: Do not skip the manual step later**
This will not affect the hook on your actual system.

```bash
# In the live Arch ISO, before pacstrap
mkdir -p /etc/pacman.d/hooks

ln -sf /dev/null /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
ln -sf /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook
```

## Base System Install

First update mirrorlist for optimal download speeds, obv replace Norway and Germany.
A good rule of thumb here is doing your country + closest neighbours and then a few larger neighbours after that.
So for me it's Norway,Sweden,Denmark then Germany,Netherlands:

```bash
# Update mirrorlist before install so you install with fastest mirrors
#
# PROTIP: "\" is a pipe, it basically is a fancy way to add a space to a bash command.
# So essentially just write each line until there isnt a "\" and it will run it all as one command.
# This is good for keeping large commands digestible during install.
#
reflector \ # this is a line, press enter                                      
      --country 'Norway,Sweden,Denmark,Germany,Netherlands' \  # and it goes to the 2nd line, do same as first
      --age 12 \ # same here & etc under  
      --protocol https \ 
      --sort rate \
      --latest 10 \
      --save /etc/pacman.d/mirrorlist  # then when pressing enter here w/o "\" it will run all the lines

# When you understand all of this you can use a faster version of this
# that I like to use:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
-l 10 --sort rate --save /etc/pacman.d/mirrorlist

# NOTE: This is slower but you will guaranteed have the best mirrors if you do this
# if you want to test the mirrors by speed do this:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 10 --save /etc/pacman.d/mirrorlist
```

and then **Install the base of Arch Linux!** :

```bash
# For AMD CPUs:
pacstrap /mnt base linux-zen linux-lts linux-firmware amd-ucode nano sudo zsh
```

## Step 4: System Configuration

### 4.1 Enter the New System

```bash
# However before you can say you've installed arch you need to configure the system
# This is how you chroot into your newly installed system:
#
arch-chroot /mnt
```

### 4.2 Set Timezone

```bash
# Set timezone to your own continent and city
ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime

# Set hardware clock
hwclock --systohc
```

### 4.3 Configure Locale

```bash
# Now we are going to configure our system language.
# I am going to have my system be in English,
# but my time and date will be set as it is in Norway.
# So an English system with a DD/MM/YYYY and 00:00 "military clock".
#
nano /etc/locale.gen

# Go down the list and uncomment both:
Uncomment: en_US.UTF-8 UTF-8 # English
Uncomment: nb_NO.UTF-8 UTF-8 # Bokmål Norwegian (replace with your own or leave out)

# Then generate locales
locale-gen

# Set system locale
nano /etc/locale.conf

# add
LANG=en_US.UTF-8    # LANG for system language
LC_TIME=nb_NO.UTF-8 # LC_TIME for date & time to my specific LANG default


# Set console keymap & font
nano /etc/vconsole.conf

# add
KEYMAP=no-latin1 # Skip this if US keyboard
FONT=ter-118n  # But add this.
               # This is a console font which makes it larger,
               # and more easily readable on boot

```

### 4.4 Set Hostname and Hosts

```bash
# Set hostname, echo lets you do it quickly w/o using nano
# good for one line stuff
#
echo "BigBlue" > /etc/hostname

# Configure hosts file
nano /etc/hosts

## add to /etc/hosts:
127.0.0.1 localhost BigBlue
::1       localhost
```

### 4.5 Create User Account

```bash
# Set root password
passwd

# Create user with necessary groups
useradd -m -G wheel lars
passwd lars

# Set zsh as default shell for user and root
chsh -s /usr/bin/zsh lars
chsh -s /usr/bin/zsh

# Enable sudo for wheel group
EDITOR=nano visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```

### Configure Initramfs

```bash
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

---

# Example for MODULES:
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

---

# Example for HOOKS
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)

# Key changes:
# - MUST use 'systemd' instead of 'udev' 
# - Use 'sd-vconsole' instead of 'keymap' and 'consolefont'
# - Remove 'kms' from HOOKS=() also if you use nvidia
# - Ensure microcode is in HOOKS=()
#
# NOTE: IF you do not remove udev and if you do not replace it with systemd,
# THEN YOUR SYSTEM WILL NOT BOOT.
# This is the only pitfall with systemd-gpt-auto-generator,
#
# It's worth doublechecking.
# Check this again if your system isn't booting post-install.

```

### Install UKIs and Configure Bootloader

```bash
# Install systemd-boot
#
# NOTE: Remember to include `--variables=yes` flag. - Here's why:
# Starting with systemd version 257, bootctl began detecting
# environments like arch-chroot as containers...
#
# This is an intended change and without it, it silently skips
# the step of writing EFI variables to NVRAM...
#
# For non-nerds: This prevents issues where the boot entry
# might not appear in the firmware's boot menu...
#
bootctl install --esp-path=/efi --variables=yes

# Minimal cmdline with kernel option(s)
nano /etc/kernel/cmdline

# These are the only kernel flags needed for this setup
# With GPT Autoloader you do not need to specify UUIDs here
#
# rootflags add options to the root filesystem, like noatime
# noatime is a typical optimization for EXT4 systems.
# nowatchdog is also optimization. Both of them are unneeded for single use desktops.
# they are on for "over-security"/kernel default reasons only.
# many distros ship with nowatchdog and noatime, EOS for example.
#
# if you really are worried about if you need them (you probably dont) then you can
# research them independently
#
# loglevel=3 just increases verbosity in logging.
#
# zswap.compressor=lz4 switches compressor to lz4 from zstd, lz4 is considered faster
#
## /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.compressor=lz4
```

#### Make the ESP directory
```bash
# Make ESP directory
mkdir -p /efi/EFI/Linux
```

#### Edit the mkinitcpio presets so they write UKIs to the ESP

```bash
nano /etc/mkinitcpio.d/linux-zen.preset

# Content:
ALL_kver="/boot/vmlinuz-linux-zen"
PRESETS=('default')

default_uki="/efi/EFI/Linux/arch-linux-zen.efi"
```

#### Repeat for LTS:

```bash
nano /etc/mkinitcpio.d/linux-lts.preset

# Content:
ALL_kver="/boot/vmlinuz-linux-lts"
PRESETS=('default')

default_uki="/efi/EFI/Linux/arch-linux-lts.efi"

```

#### Build the UKIs / This writes both kernel *.efi's into ESP/EFI/Linux/:

```bash
mkinitcpio -P
```

#### Configure bootloader

```bash
# write the loader
nano /efi/loader/loader.conf

## add to loader
timeout 10
console-mode auto
editor no
```


### 4.9 Create swap file & Configure Zswap

```bash
# Create a 16 GiB swap file and initialize it in one step.
#   --size 16G   -> allocate a 16 GiB file
#   --file       -> create the file with correct mode and real blocks
#   -U clear     -> clear any existing UUID in the header
mkswap -U clear --size 16G --file /swapfile

```
edit:
```bash
nano /etc/systemd/system/swapfile.swap
```
and add:
```ini
[Unit]
Description=Swap file

[Swap]
What=/swapfile
Priority=100

[Install]
WantedBy=swap.target
```
then:
```bash
systemctl enable swapfile.swap
```

### Optimizations for swap use:

```bash
# These are optimizations taken from the wiki.
# Generally considered to be optimal.
nano /etc/sysctl.d/99-zswap.conf

# add
vm.swappiness = 100
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125

# update the sysctl
sysctl --system
```


## Install the System

```bash
# Update package database
pacman -Syu
```

### Install Packages
```bash
# pipe commands, like before type out each pipe line, press enter on each until base-devel
# then when u press enter it installs it all
pacman -S --needed \
  networkmanager reflector xorg xorg-init xterm \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  linux-zen-headers linux-lts-headers \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver libva-utils cuda \
  terminus-font ttf-dejavu ttf-liberation \
  pacman-contrib git wget \
  base-devel
```

### Enable Essential Services

```bash
systemctl enable NetworkManager systemd-timesyncd systemd-boot-update.service reflector.timer 
```

```bash
# Exit chroot environment
exit

# Unmount all partitions
umount -R /mnt

# Reboot into new system
shutdown now

# Remove ArchISO USB from computer then boot back into new install
```

---

### Login and Prepare Build Flags

Login to user:

```bash
# Enter user name then your password
```

Build Optimization for Building awesomewm:
```bash
sudo nano /etc/makepkg.conf
```

```bash
# Add these flags for optimized builds
CFLAGS="-march=native -O2 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection=full"
CXXFLAGS="${CFLAGS}"
MAKEFLAGS="-j$(nproc)"
```

Install yay:
```bash
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay

# Build and install the package
makepkg -si

# Confirm
yay --version
```

Install and Build awesomewm:
```bash
yay -S awesome-git
```

Set up ~/.xinitrc in your user’s home:
```bash
# Edit/Add awesome to xinit
nano ~/.xinitrc
```

```bash
#!/bin/sh

# Start xterm in the background
# This is temporary. Later after your setup is done
# you will probably want to comment this out
( sleep 1 && xterm ) &

# Start Awesome
exec awesome
```

```bash
# Make executable
chmod +x ~/.xinitrc

# Now enter Awesome!
startx
```

### Optional: Automatically Start & Login To Awesome
If you don't want to login and write startx every time you boot:

```bash
# Create for zsh:
nano ~/.zprofile
```

```bash
# ~/.zprofile
#
# Source main zsh config if you want
[ -f ~/.zshrc ] && . ~/.zshrc

# Auto start X only on tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  exec startx
fi
```

## 3. Set up systemd autologin on tty1

ArchWiki recommends using a systemd drop-in for `getty@tty1.service`. 

Create the directory:

```sh
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
```

Create the autologin config:

```sh
sudo nano /etc/systemd/system/getty@tty1.service.d/autologin.conf
```

Put this inside, replacing `youruser` with your actual username:

```ini
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin youruser - ${TERM}
Type=simple
# Optional, helps some software identify the session correctly as X11
Environment=XDG_SESSION_TYPE=x11
```

Key bits:

* The empty `ExecStart=` line clears the original `ExecStart` from the template
* The second `ExecStart` line adds agetty with `--autologin youruser`
* `Type=simple` makes getty start immediately, which the ArchWiki notes can help when you also auto start X 

Reload systemd so it sees the drop-in:

```sh
sudo systemctl daemon-reload
```

Make sure `getty@tty1` is enabled (it usually is by default, but no harm checking):

```sh
sudo systemctl enable getty@tty1.service
```

Now reboot:

```sh
reboot
```

Boot flow after this:

1. Systemd starts `getty@tty1.service`
2. That agetty instance auto logs in `youruser` on tty1
3. Your login shell starts
4. The `if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]` check in `~/.bash_profile` or `~/.zprofile` passes
5. `exec startx` runs, which loads `~/.xinitrc` and starts Awesome

You end up in Awesome with no manual login or `startx` typing.

---

## 4. Things to watch out for

* If you ever get stuck in a loop or need to debug, switch to another TTY with `Ctrl+Alt+F2`, log in there, and temporarily comment out the `exec startx` block or move `autologin.conf` out of the way.
* This setup effectively means anyone with physical access to the machine and keyboard has full access to your user account.
* If you later decide you want a greeter with optional autologin instead, something like `greetd` with `tuigreet` can do that.

### Reboot

```bash
reboot
```

