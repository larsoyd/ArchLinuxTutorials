# Complete Arch Linux Tutorial (KDE Plasma + Wayland w/ Automounting Partitions)

This is an **OPINIONATED** Arch installation guide for regular folks who just want a working system to game on that's straight forward with a DE that is most like Windows
and usually the one most people want to use because of that, at least for their first DE. I've used every DE and WM that is both trendy and some obscure,
I started with KDE Plasma and Arch Linux. I always come back to both eventually. It's fun to try out new things, but KDE Plasma is OP at the moment I am writing 
this. It's fully featured, they finally have a good process in eliminating bugs which plagued the DE before, and it's very easy to customize. Most DEs and WMs have
some caveat, KDE Plasma does not. That is why I use it.


## NOTE (ACTUALLY READ THIS): 

So, I like to use something called `systemd-gpt-auto-generator`. I acknowledge that this is a super opinionated decision for a noob tutorial, and I debated whether or not to use it in this tutorial, but I feel it's so cromulent and underrated that I decided to make a big decision to teach you how to use it as well. If you follow this guide correctly and use it you'll see why it's very convenient.
It is not usually done on Linux and it is kind of new(?), at least relative to `fstab`, however it is a modern way of mounting partitions that are also used by other operating systems you may already be familiar with. 

---

# INTRODUCTION - How GPT Auto-Mounting Works

Modern systemd uses `systemd-gpt-auto-generator` to automatically discover and mount partitions based on specific 128-bit **UUIDs,** eliminating the need for manual `/etc/fstab` entries. This system is useful for centralizing file system configuration in the partition table and making configuration in `/etc/fstab` or on the kernel command line unnecessary. This is similar to the OS you probably switched away from and are more familiar with; Windows. - Windows identifies volumes by what they call "GUIDs" (Volume{GUID} paths). Now for your sake all you need to know is that a GUID is functionally the same thing as the specific 128-bit UUIDs that we will use on Linux, but instead of mounting to `boot` or `root` they mount their "GUIDs" to set drives defined by a letter, so `C:` drives and `D:` drives. That is why some letters are reserved for largely depreciated functions, as mounting on Windows is identified by a set identifier just like your system's UUIDs will do.

Your drive partitions like `boot` and `root` will not be mounted by `fstab`, instead they will automount entirely by using UUIDs by using `systemd-gpt-auto-generator`. This is preferable in my opinion to `fstab` which feels like a hack and places too much control of system reliance upon a single text based config. This is anecdotal, but I have heard of what happens when some package or update randomly decides to destroy your `fstab` and it is **NOT** fun to troubleshoot if it happens. It's often difficult to know what is going wrong and many hours will be wasted until you realize your fstab for whatever reason is empty or has some typos.

Now this is still unconventional which is part of the fun of using this as it justifies the manual install, but since it is unique it's worth familiarizing yourself with how this works before following my guide. I will add a small tutorial on how you would go about adding a new SSD later on with this, it's a *tiny* bit different but still very easy to do. -- **PLEASE NOTE:** that there are extra steps to subvolumes if you choose to use this with **BTRFS,** since subvolumes like snapshots usually require `fstab`. I might write a small tutorial on what you need to do with BTRFS for this type of system if I ever decide to use that filesystem, but essentially instead of `fstab` you just use systemd service for each instead which is also what you will do for new drives. 

## The UUIDs

- `EF00` (EFI System Partition)
- `8304` (Linux x86-64 root)  

systemd automatically creates mount units based on these partition type UUIDs. Each hex code corresponds to a specific 128-bit UUID that tells the system exactly what that partition is for. The system recognizes these GUIDs and then mounts accordingly, just like a modern system should. This approach is similar to how partitioning works on other systems.
For extra storage you can use the generic Linux filesystem code:
- `8300`

systemd won't auto-mount these, giving you control over when and where they mount which again to me is ideal, if need be you can mount them on boot with a systemd service. This allows you to avoid `fstab` issues forever. No more random issues where it's suddenly overwritten for some reason or anything else, mounting is seperate and automated.

---

# - CONS: -

Same Disk Only: Auto-mounting only works for partitions on the same physical disk as your root partition.

Boot Loader Dependency: The boot loader must set the `LoaderDevicePartUUID` EFI variable for root partition detection to work. systemd-boot (used in this guide) supports this. Check if the bootloader you wish to use does.
For GRUB to set the `LoaderDevicePartUUID` UEFI variable load the bli module in grub.cfg:
```ini
if [ "$grub_platform" = "efi" ]; then
  insmod bli
fi
```

First Partition Rule: systemd mounts the first partition of each type it finds. If you have multiple 8302 partitions on the same disk, **then only the first one gets auto-mounted.**

No Multi-Disk Support: This won't work on systems where the root filesystem is distributed across multiple disks (like BTRFS RAID).

# - PROS: -

Portability: Your disk image can boot on different hardware without `fstab` changes

Self-Describing: The partition table contains all mounting information

Container-Friendly: Tools like systemd-nspawn can automatically set up filesystems from GPT images

Reduced Maintenance: No broken boots from typos in `/etc/fstab` or random updates doing weird stuff messing with it.

## What you will learn to set and use:

- systemd-automount for GPT partitions 
- KDE Plasma on Wayland
- `linux-zen` default kernel, `linux-lts` backup. Optional `linux-cachyos` and `linux-cachyos-lts` for optimized kernel.
- zsh default shell for users, optional dash shell for /usr/bin/sh 
- systemd-boot with UKIs
- zswap with a 16 GiB swap file
- EXT4 for `/` with optional fast_commit journaling

## What my guide will primarily target:
- AMD CPU + NVIDIA GPU w/ `nvidia-open` 
**NOTE:** This tutorial assumes you have a Turing (NV160/TUXXX) and newer	card for current driver. Check your card first.

I included some stuff for AMDGPUs and Intel too, but my system is NVIDIA so I may have missed some things.

NVIDIA modeset is set by default, and according to the wiki setting fbdev manually is now unnecessary so I will not set those. PLEASE check the wiki before install for anything. **POST-INSTALL GUIDE IS EVEN MORE OPINIONATED, FOLLOW BY OWN VOLITION.**

*Protip:* This tutorial uses Norwegian keymaps and locale/timezone settings. Simply replace those with your own (e.g. keymap, `LANG`, `TZ`).
If you use an English lang keyboard you can ignore all of it, but it's worth knowing if you are new and use a different keyboard like say `de-latin1` for German keyboards.

**NOTE:** **This tutorial assumes you have a NVME SSD,** which are named `/dev/nvme0n1`. If you don't have that, it's something else. If you don't know, check with `lsblk -l` to see your scheme. It could be `sda` or something else. If it is something else replace all instances of `nvme0n1` and remove the `p` from  `${d}p1` in the formatting.

*Sidenote:* Unless you like the name, replace my hostname (basically the name of your rig) of `BigBlue` with yours, same as my user name `lars` if your name ain't Lars. Though if it is, cool. Hi! I thought about doing placeholders but I feel those are more distracting usually, I prefer to see how something would actually work in a guide, maybe you do as well?


## Prerequisites

- A bootable Arch Linux USB (written with `dd` or similar)
- Internet connection
- UEFI system


---


### TUTORIAL PROPER

**GPT Auto-Mount + KDE Plasma (Wayland) + NVIDIA**

> **Prerequisites:** This guide assumes you have an AMD processor with NVIDIA graphics. For Intel CPUs, replace `amd-ucode` with `intel-ucode` throughout the installation.
For AMDGPU or Intel GPU you should look either up at the Arch Wiki and replace the corresponding packages with those. I'd rather not clutter up the guide with a bunch of different setups, especially if I've never used those. It just confuses new users, like placeholders.



## Step 0: Boot from ISO

Set up your keyboard layou if you're not on an US keyboard, and verify UEFI boot:

```bash
# Set your keyboard layout, you can skip this is u use a normal keyboard (US)
# each line in these code blocks is a separate line in the terminal FYI

# # List all keymaps (scrollable):
localectl list-keymaps | less

# or filter by country code by writing:
localectl list-keymaps | grep -i -E 'no'                   # Norway example
                                                           # "no" is our ISO-639 code. Find yours by googling first
                                                           # Then replace 'no' with your country code                 

# For Norway it's "no-latin1". On Arch it's usually "*-latin1" and not just the country code.
# Test out your keyboard after this, if it is wrong try another on the list.
#
# To write "-" on US keyboard which you will need to do to be able to write this command,
# it's usually the first key left of backspace. For Norwegian/Nordic keyboard that's: \.
loadkeys no-latin1

# the default font for an arch install is tiny and it only gets worse as you get older
# here is how you get it to something readable
setfont ter-118n

# if that is not big enough try this:
setfont ter-132n    

# and if even that is not big enough:
setfont -d ter-132n  

# Verify UEFI firmware, write it all out including && and echo.
# It's just going to be a bunch of random variables that's confusing, however...
#
# If it says the quote at the end there then you are good.
ls /sys/firmware/efi/efivars && echo "UEFI firmware detected"

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
ping -c 3 1.1.1.1            # raw IP reachability (no DNS involved)
resolvectl query archlinux.org
ping -c 3 archlinux.org

# HTTPS test (TLS & HTTP working)
curl -I https://archlinux.org  # expect "HTTP/2 200" (or 301/302)

# Time sync sanity (NTP via systemd-timesyncd)
timedatectl status | sed -n '1,12p'  # look for "System clock synchronized: yes"
```

## Step 1: Partition the NVMe drive with systemd-repart

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
# Be advised that some have reported issues with it, albeit a few years ago but still
# According to the Arch wiki it significantly improves performance:
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

## Step 2: Mount filesystems (labels match your original layout)

```bash
# Mount root first
mount /dev/disk/by-label/root /mnt
```

#### Create and mount EFI directory with strict masks

```bash
mkdir -p /mnt/efi
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

### Here is some information on why I am mounting EFI like this:

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

---


## Step 3: Base System Install

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

# Or update reflector for fastest and longer timeout
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 30 --save /etc/pacman.d/mirrorlist
```

```bash
# and then **Install the base of Arch Linux!** :
pacstrap /mnt base
```

## Step 4: System Configuration

### 4.1 Enter the Base

```bash
# However before you can say you've installed arch you need to configure the system
arch-chroot /mnt
```



### 4.5 Create User Account

```bash
# Install zsh
pacman -S --needed zsh

# Set root password
passwd

# Create user with necessary groups
useradd -m -G wheel lars
passwd lars

# Set zsh as default shell for user
chsh -s /usr/bin/zsh lars
```

```bash
# OPTIONAL: Point /bin/sh to dash for 4x faster sh scripts which can make up a lot
# of daily operation in Linux
#
# BE ADVISED it can lead to problems with "bashisms"
# but it's not a super huge problem, as it's default on Debian & Ubuntu
# Because of that it is de facto a standard in Linux for most shell scripts to
# come with a header that explicitly defines a bash script whenever necessary.
#
# You will be fine, but if you are ever unsure then you can
# run "checkbashisms" on the *.sh file via the terminal or skip this step entirely.
pacman -S --needed dash checkbashisms

# Then do this to symlink dash to /usr/bin/sh
ln -sfT dash /usr/bin/sh
```

```bash
# Finally enable sudo for wheel group
EDITOR=nano visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```

---

# OPTIONAL: CachyOS packages and Kernel

If you want CachyOS repos and kernel like I do, then this is how you do it:

```bash
# My reasoning for including this is that the CachyOS kernel and packages are very good at the moment.
# It is a no brainer to use both the repository recompiled for Zen architecture if you have it and
# their kernel, which is already tuned for you. First you need to add their keyring and mirrorfiles.
#
# If you aren't going to get the CachyOS kernel get linux-zen and linux-lts instead then skip this step
# to `Install Packages`.
# linux-zen is a tuned kernel, it has nothing to do with the Zen architecture by AMD FYI:
# REQUIRED IF YOU DONT GET CACHYOS KERNEL:
pacman -S --needed linux-zen linux-lts linux-zen-headers linux-lts-headers

```

```bash
# Import and locally sign the CachyOS repo key
#
# Initialize keys
pacman-key --init

# Populate keys
pacman-key --populate

# Clone this repo
cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials.git
cd ArchLinuxTutorials

# Install + sign keys & mirrors
chmod +x setup.sh
./setup.sh

# Leave /tmp
cd
```

```bash
# Now that you have added the mirrors + keys
# You need to edit /etc/pacman.conf
nano /etc/pacman.conf
```

```bash
# I will add the CachyOS znver4 repos for AMD Zen 4 and Zen 5.
# If your CPU don't support znver4 add any of the others that fit.
#
# Keep the Arch repos ([core], [extra], [multilib]) exactly as they are.
# Add one of the 3 mirrorlists under that fit your CPU above the other repos
# in the same section & in this direction:
```

```bash
# If your CPU is based on Zen 4 or Zen 5, add [cachyos-znver4],
# [cachyos-core-znver4], and [cachyos-extra-znver4]:

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
```

```bash
# If your CPU supports x86-64-v3, then add [cachyos-v3],[cachyos-core-v3],[cachyos-extra-v3]
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
```

```bash
# If your CPU supports x86-64-v4, then add [cachyos-v4], [cachyos-core-v4], and [cachyos-extra-v4]
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
```

```bash
# If your CPU only supports x86-64, then add the [cachyos], [cachyos-core], and [cachyos-extra] repositories
# cachyos repos
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
[cachyos-core]
Include = /etc/pacman.d/cachyos-mirrorlist
[cachyos-extra]
Include = /etc/pacman.d/cachyos-mirrorlist
```

### 6.1 Update mirrors and run reflector to new Cachy mirrors
```bash
# Update package database
pacman -Syu

# Install sudo & base-devel
pacman -S --needed sudo base-devel ccache mold

# Login to user
su - lars

# Configure ccache
mkdir -p ~/.config/ccache/
nano ~/.config/ccache/ccache.conf
```

```sh
# ~/.config/ccache/ccache.conf
cache_dir = $HOME/.cache/ccache
max_size  = 30G
```

EITHER:

1) Copy it from repo cloned before
```bash
cp /tmp/ArchLinuxTutorials/makepkg.conf ~/.makepkg.conf
```

2. Write it manually if you don't have znver4 (or skip entirely)
```bash
nano ~/.makepkg.conf
```

```sh
# ~/.makepkg.conf

# Retarget both C and C++ to znver4 while keeping Arch's hardening flags
# If you dont have a znver4 supported CPU just put "native" here instead
CFLAGS="${CFLAGS/-march=x86-64-v3/-march=znver4}"
CFLAGS="${CFLAGS/-march=x86-64-v2/-march=znver4}"
CFLAGS="${CFLAGS/-march=x86-64/-march=znver4}"

CXXFLAGS="${CXXFLAGS/-march=x86-64-v3/-march=znver4}"
CXXFLAGS="${CXXFLAGS/-march=x86-64-v2/-march=znver4}"
CXXFLAGS="${CXXFLAGS/-march=x86-64/-march=znver4}"

# LTO default if system config had !lto
OPTIONS=("${OPTIONS[@]/!lto/lto}")

# Enable ccache in the build environment
BUILDENV=("${BUILDENV[@]/!ccache/ccache}")

# mold default linker
LDFLAGS+=" -fuse-ld=mold"

# parallel builds
MAKEFLAGS="-j$(nproc)"
```

```bash
# Clone the AUR repo and build the package
cd /tmp
git clone https://aur.archlinux.org/rate-mirrors.git
cd rate-mirrors

# Build and install the package
makepkg -si

# Drop back to root in the chroot when done
exit

# Install cachyos-rate-mirrors
pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-rate-mirrors-17-1-any.pkg.tar.zst'

# Rate CachyOS Mirrors, run:
cachyos-rate-mirrors

# Enable mirror rate timer
systemctl enable cachyos-rate-mirrors.timer
```

##### Install CachyOS Kernel + Headers + SCX & Tools:

```bash
pacman -S --needed linux-cachyos linux-cachyos-lts linux-cachyos-headers \
linux-cachyos-lts-headers scx-scheds scx-tools
```

#### Tune SCX

```bash
mkdir -p /etc/scx_loader 
nano /etc/scx_loader/config.toml
```

```bash
# /etc/scx_loader/config.toml
default_sched = "scx_lavd"
default_mode = "Auto"

[scheds.scx_lavd]
auto_mode       = []
gaming_mode     = ["--performance"]
lowlatency_mode = ["--performance"]
powersave_mode  = ["--powersave"]
server_mode     = []
```

```bash
# Enable SCX
systemctl enable scx_loader.service
```

---


### 6.5 Install Packages
```bash
# Install firmware and some core packages:
# For AMD CPUs:
pacman -S --needed linux-firmware amd-ucode nano sudo zsh systemd-ukify

# For INTEL CPUs:
pacman -S --needed linux-firmware intel-ucode nano sudo zsh systemd-ukify
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

## 4.5.5 Package Choice

### Info:
I have taken the liberty to make some decisions for a few packages you will install, some of them are technically "optional" but
all of them are in my opinion essential to the well functioning of a KDE Plasma desktop except for kitty and pkgstats. 

Here's why I included those:


### pkgstats 
pkstats is a super harmless way to help out the Arch developers that work hard and mostly for free to make our wonderful distro.
It basically just advertises a list of your core and extra packages that you use to them  so they can know what packages to 
prioritize in testing and for other things. If you are extremely paranoid then you can leave it out.

### kitty 
kitty is a terminal that I think is the best sort of default terminal on Linux. It's easy to use, GPU accelerated, fast enough and hassle free.
It allows you to zoom in by pressing `CTRL + SHIFT and +` and zoom out by `CTRL + SHIFT and -` It doesn't look terrible like some terminals do.
konsole is included as a backup. If you want to use another terminal as your main, replace it.

---

## **NOT INCLUDED IN THE STEP BUT YOU MAY WANT TO INCLUDE:**

### wireless-regdb
If you use wireless then an **essential package** is also `wireless-regdb`. It installs regulatory.db, a machine-readable table of Wi-Fi rules per country  that allows you to connect properly. If regulatory.db is missing or cannot be read, Linux falls back to the “world” regdomain 00. That profile is **intentionally conservative,** which means fewer channels and more restrictions. For example, world 00 marks many 5 GHz channels as passive-scan only and limits parts of 2.4 GHz (12–13 passive, 14 effectively off).

### audiocd-kio
This adds the audiocd:/ KIO worker so Dolphin and other KDE apps can read and rip audio CDs. Not needed on non-KDE Plasma systems, but KDE has their own thing with this for some reason. If you are on a laptop with a CD player then you are going to want this.

### libdvdread, libdvdnav, and libdvdcss
This is the same as above but for DVD playback. This is needed on any DE.

### libbluray and libaacs
Same for Blu-Rays. After you have installed the system and configured an AUR helper you may also wish to install **libbdplus** from the AUR if you want for BD+ playback. From there you will have to set it up with KEYS which is shown on the Arch Wiki about Blu-Ray.

### bluez and bluez-utils
For Bluetooth support if you use Bluetooth. You will also need to enable `bluetooth.service` then at the end of the tutorial.

### cups & cups-pdf (Optional: bluez-cups for Bluetooth printers)
If you need printer support. You will also need to enable `cups.service` at the end of the tutorial.

---

# 4.6 Install the System

**EITHER**

NVIDIA: 
```bash
# pipe commands, like before type out each pipe line, press enter on each until base-devel
# then when u press enter it installs it all
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty kio-admin sddm sddm-kcm kdegraphics-thumbnailers ffmpegthumbs \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver libva-utils cuda \
  pacman-contrib git wget hunspell hunspell-en_us quota-tools usbutils \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols \
  base-devel
```

or AMDGPU:
```bash
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty kio-admin \
  sddm sddm-kcm kdegraphics-thumbnailers ffmpegthumbs \
  mesa vulkan-radeon \
  libva libva-utils \
  quota-tools hunspell hunspell-en_us usbutils \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols \
  pacman-contrib git wget \
  base-devel
```

or Intel GPUs (I think):
```bash
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty kio-admin \
  sddm sddm-kcm kdegraphics-thumbnailers ffmpegthumbs \
  mesa vulkan-intel \
  libva libva-utils intel-media-driver \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols \
  hunspell hunspell-en_us quota-tools usbutils \
  pacman-contrib git wget \
  base-devel
```



### 4.6 Configure Initramfs

```bash
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

---

# Example for MODULES if you use nvidia:
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

---

# Example for MODULES if you use amdgpu
# Officially supported kernels enable AMDGPU support for cards of the Southern Islands (GCN 1, released in 2012)
# and Sea Islands (GCN 2, released in 2013).
#
# The amdgpu kernel driver needs to be loaded before the radeon one.
# You can check which kernel driver is loaded by running lspci -k.
#
MODULES=(amdgpu)

# or if you have radeon as well
# do this so amdgpu loads first:
MODULES=(amdgpu radeon)

---

# Example for HOOKS
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)

# Key changes:
# - MUST use 'systemd' instead of 'udev' 
# - Use 'sd-vconsole' instead of 'keymap' and 'consolefont'
# - Remove 'kms' from HOOKS=() also if you use nvidia, AMDGPU can ignore this however
# - Ensure microcode is in HOOKS=()
#
# NOTE: IF you do not remove udev and if you do not replace it with systemd,
# THEN YOUR SYSTEM WILL NOT BOOT.
# This is the only pitfall with systemd-gpt-auto-generator,
#
# It's worth doublechecking.
# Check this again if your system isn't booting post-install.

```

### 4.8 Install UKIs and Configure Bootloader

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
# If you are using AMDGPU and Radeon and it insists on using Radeon instead,
# You can add either of these depending on your card here to force the loading of AMDGPU:
#
# Southern Islands (SI): radeon.si_support=0 amdgpu.si_support=1
# Sea Islands (CIK): radeon.cik_support=0 amdgpu.cik_support=1
#
## /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.compressor=lz4
```

#### Make the ESP directory
```bash
# Make ESP directory
mkdir -p /efi/EFI/Linux
```

#### Edit kernel-install config so it installs UKIs to the ESP

```bash
# Edit:
nano /etc/kernel/install.conf
```

```bash
# Add only:
layout=uki
```

#### Prevent Stale UKIs
```bash
# To prevent stale UKIs you need a hook to run after every update
# Or do it manually, but automatic is better.
#
# To do it, first login to your account in the chroot you made
# before like so:
su - lars

# Clone the AUR repo of the pacman hooks and build the package
cd /tmp
git clone https://aur.archlinux.org/pacman-hook-kernel-install.git
cd pacman-hook-kernel-install

# Build and install the package
makepkg -si

# Drop back to root in the chroot when done
exit

# And finally deactivate the mkinitcpio hooks so you don't create duplicates
ln -s /dev/null /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
ln -s /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook
```

### Now install kernel UKIs
```bash
# Simply run
kernel-install add-all
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

sysctl Optimizations:

```bash
# These are optimizations taken from CachyOS
# Ignore the comments and only write the stuff under
# The comments are there for context
nano /etc/sysctl.d/70-settings.conf

# The sysctl swappiness parameter determines the kernel's preference for pushing anonymous pages or page cache to disk in memory-starved situations.
# A low value causes the kernel to prefer freeing up open files (page cache), a high value causes the kernel to try to use swap space,
# and a value of 100 means IO cost is assumed to be equal.
vm.swappiness = 100

# The value controls the tendency of the kernel to reclaim the memory which is used for caching of directory and inode objects (VFS cache).
# Lowering it from the default value of 100 makes the kernel less inclined to reclaim VFS cache (do not set it to 0, this may produce out-of-memory conditions)
vm.vfs_cache_pressure = 50

# Contains, as bytes, the number of pages at which a process which is
# generating disk writes will itself start writing out dirty data.
vm.dirty_bytes = 268435456

# page-cluster controls the number of pages up to which consecutive pages are read in from swap in a single attempt.
# This is the swap counterpart to page cache readahead. The mentioned consecutivity is not in terms of virtual/physical addresses,
# but consecutive on swap space - that means they were swapped out together. (Default is 3)
# increase this value to 1 or 2 if you are using physical swap (1 if ssd, 2 if hdd)
vm.page-cluster = 0

# Contains, as bytes, the number of pages at which the background kernel
# flusher threads will start writing out dirty data.
vm.dirty_background_bytes = 67108864

# The kernel flusher threads will periodically wake up and write old data out to disk.  This
# tunable expresses the interval between those wakeups, in 100'ths of a second (Default is 500).
vm.dirty_writeback_centisecs = 1500

# This action will speed up your boot and shutdown, because one less module is loaded. Additionally disabling watchdog timers increases performance and lowers power consumption
# Disable NMI watchdog
kernel.nmi_watchdog = 0

# Enable the sysctl setting kernel.unprivileged_userns_clone to allow normal users to run unprivileged containers.
kernel.unprivileged_userns_clone = 1

# To hide any kernel messages from the console
kernel.printk = 3 3 3 3

# Restricting access to kernel pointers in the proc filesystem
kernel.kptr_restrict = 2

# Increase netdev receive queue
# May help prevent losing packets
net.core.netdev_max_backlog = 4096

# Set size of file handles and inode cache
fs.file-max = 2097152

# Disable extra reclaim on fragmentation events.
# Setting vm.watermark_boost_factor to 0 stops the kernel from doing
# additional aggressive reclaim when it detects fragmented memory.
# This can reduce unnecessary swap activity and page thrashing under load,
# which helps keep desktop workloads smoother and more responsive.
vm.watermark_boost_factor = 0

# Tune when kswapd starts and stops reclaiming memory.
# vm.watermark_scale_factor controls how far apart the free-memory
# watermarks are. Raising it from the default (around 10) to 125 means
# kswapd starts reclaiming earlier and maintains a larger free-memory
# buffer. That reduces chances of direct reclaim stalls and can improve
# responsiveness when the system is under memory pressure.
vm.watermark_scale_factor = 125

# update the sysctl
sysctl --system
```

#### Force GTK to use Portals
```bash
# This is important for file pickers and GTK windows on KDE
# This may mean nothing to you now, but basically its the
# difference between having a maximize button on Firefox and not.
#
mkdir -p /etc/environment.d
nano /etc/environment.d/99-portal.conf 
```

```ini
# 99-portal.conf 
GTK_USE_PORTAL=1
GDK_DEBUG=portals
```

#### Optional: Set SDDM Theme Before Reboot

```bash
# This will set your SDDM theme so you aren't
# met with an old login screen first boot
#
# If you want to do this later that's okay
mkdir -p /etc/sddm.conf.d
nano /etc/sddm.conf.d/10-breeze.conf
```

```ini
# 10-breeze.conf
[Theme]
Current=breeze
```


### 4.10 Enable Essential Services

```bash
# Enable network, display manager, and timesyncd
# Include cups.service if you are using printer
# Include bluetooth.service for Bluetooth if you installed bluez and bluez-utils
systemctl enable NetworkManager sddm systemd-timesyncd systemd-boot-update.service \
fstrim.timer reflector.timer pkgstats.timer
```

## Step 5: Complete Installation

```bash
# Exit environment
exit

# Then unmount all partitions
umount -R /mnt

# Reboot into new system
shutdown now

# Remove ArchISO USB from computer then boot back into it
#
# Howto change SDDM Theme if you didn't manually and were met with a "Classic" Theme:
# Navigate to Colors & Themes -> Login Screen (SDDM) -> then select "Breeze" and hit Apply
# It will then have applied it and on next reboot and others after it will persist
# 
# This is also the way to fix if the taskbar (panel) appears on the wrong monitor: Simply go to Global Theme
# Press Breeze or Breeze-Dark, select BOTH checkboxes and hit apply. Wait and then it will correctly apply
# This will also persist on reboots as well. 
```

---

# 1) OPTIONAL: Post-Install Tutorial
Head to `arch_kde_post_tutorial.md` to do the post-install tutorial.

---

# 2) OPTIONAL: How to fix those annoying 'missing firmware' warnings in mkinitcpio

* NOTE: This is only if you do have the `fallback` option on the UKIs which we removed in the guide, but if you kept it this will annoy you.
* Whenever you write `mkinitcpio -P` you might notice it keeps warning you about firmware that you are supposedly missing.
* If this bothers you, check out my tutorial, `mkinitcpio-fix.md` to fix this.
