# Complete Arch Linux Tutorial (KDE Plasma + Wayland w/ Automounting Partitions)

This is an Arch installation guide for regular folks who just want a working system to game on that's straight forward & optimized with a few opinionated tweaks using a DE that is most like Windows
and usually the one most people want to use because of that, at least for their first DE. I've used every DE and WM that is both trendy and some obscure,
I started with KDE Plasma and Arch Linux. I always come back to both eventually. It's fun to try out new things, but KDE Plasma is OP at the moment I am writing 
this. It's fully featured, and they finally have a good process in eliminating bugs which plagued the DE before.


# INTRODUCTION - How GPT Auto-Mounting Works

In this tutorial I will be using `systemd-gpt-auto-generator` to automatically discover and mount partitions based on specific 128-bit **UUIDs**. What that means is that your drive partitions like `boot` and `root` will not be mounted by `fstab`, instead they will automount basically by themselves. This system is useful for centralizing file system configuration in the partition table and in making configuration in `/etc/fstab` or on the kernel command line completely unnecessary.

This is still very unconventional, so it's worth familiarizing yourself with how this works before following my guide. Some things are different like mounting a new SSD drive for example, which I show how to do in [**this**](extra/tutorials/newdrive.md) guide. 


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
- `linux-zen` default kernel, `linux-lts` backup.
- zsh default shell for users, optional dash shell for /usr/bin/sh 
- systemd-boot with UKIs
- zswap with a 16 GiB swap file
- EXT4 for `/` with optional fast_commit journaling

## What my guide will primarily target:
- AMD CPU + NVIDIA GPU w/ `nvidia-open-dkms` 
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

### OPTIONAL: Using SystemRescue To Install

- While in this tutorial I will be assuming you are using the official ArchISO Installation Medium, I must concede that after installing Arch via the official medium for years I now instead opt for a live environment for my own convenience. Basically what this means is that I install Arch from another distro, and I choose the LiveISO maintenance distro [SystemRescue](https://www.system-rescue.org/) which is based on Arch and comes with the installation scripts and reflector pre-installed for maximum convenience. This is only if you already have a gist on how to install Arch and you don't want to use the TUI. - [Here](extra/misc/systemrescue.md) is more on this if you are interested.

**NB: If you choose to use SystemRescue remember to write `pacman --config=/etc/pacman-rolling.conf -Sy` in the XFCE terminal before starting the tutorial.**

---


### TUTORIAL PROPER

**GPT Auto-Mount + KDE Plasma (Wayland) + NVIDIA**

> **Prerequisites:** This guide assumes you have an AMD processor with NVIDIA graphics. For Intel CPUs, replace `amd-ucode` with `intel-ucode` throughout the installation.
For AMDGPU or Intel GPU you should look either up at the Arch Wiki and replace the corresponding packages with those. I'd rather not clutter up the guide with a bunch of different setups, especially if I've never used those. It just confuses new users, like placeholders.



## Step 0: Boot from ISO

Set up your keyboard layou if you're not on an US keyboard, and verify UEFI boot:

```zsh
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

```zsh
lsblk -l

# Set the device you want to operate on
d=/dev/nvme0n1   # change if lsblk shows a different path:
d=/dev/sda   # if sd# or sda specifically it's this instead.

# Define the desired partitions for systemd-repart using nano
mkdir -p /tmp/repart.d
```

```zsh
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

```zsh
# Create 20-root.conf
nano /tmp/repart.d/20-root.conf

# 20-root.conf
[Partition]
Type=root
Label=root
Format=ext4
```

```zsh
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

```zsh
# Mount root first
mount /dev/disk/by-label/root /mnt
```

#### Create and mount EFI directory with strict masks

```zsh
mkdir -p /mnt/efi
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

[**Here**](https://github.com/larsoyd/ArchLinuxTutorials/blob/main/why-EFI-options.md) is some information on why I use these options for mounting the EFI

---


## Step 3: Base System Install

First update mirrorlist for optimal download speeds, obv replace Norway and Germany.
A good rule of thumb here is doing your country + closest neighbours and then a few larger neighbours after that.
So for me it's Norway,Sweden,Denmark then Germany,Netherlands:

```zsh
# Update mirrorlist before install so you install with fastest mirrors
# If on SystemRescue you must run this command before Reflector can be used:
# pacman --config=/etc/pacman-rolling.conf -S reflector`
#
# PROTIP: "\" is a pipe, it basically is a fancy way to add a space to a command.
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

# When you understand all of this you can use a faster version of this command.
# This will NOT rate your mirrors by fastest mirrors by testing them,
# instead it will just sort them based on the countries:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
-l 10 --sort rate --save /etc/pacman.d/mirrorlist

# Or update reflector with this for reflector to test the mirrors and then rate them
# with a longer timeout. NOTE that this will take longer time, but may be worth it for you
# if you want the absolute best mirrors:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 30 --save /etc/pacman.d/mirrorlist
```

```zsh
# and then **Install the base of Arch Linux!** :
pacstrap /mnt base nano sudo

# Or if you use SystemRescue:
pacstrap -C /etc/pacman-rolling.conf -K /mnt base nano sudo
```

## Step 4: System Configuration

### 4.1 Enter the Base

```zsh
# However before you can say you've installed arch you need to configure the system
arch-chroot /mnt
```



### 4.5 Create User Account

```zsh
# Install zsh & git
pacman -S --needed zsh git

# Set root password
passwd

# Create user with admin privileges (wheel):
useradd -m -G wheel lars
passwd lars

# Set zsh as default shell for user
chsh -s /usr/bin/zsh lars
```

```zsh
# Finally enable sudo for wheel group
EDITOR=nano visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```


### 5.5 Install Packages
```zsh
# linux-zen is a tuned kernel for desktop use.
# it has nothing to do with the Zen architecture by AMD FYI.
pacman -S --needed linux-zen linux-lts linux-zen-headers linux-lts-headers

# Install firmware and some core packages:
# For AMD CPUs:
pacman -S --needed linux-firmware amd-ucode nano sudo systemd-ukify

# For INTEL CPUs:
pacman -S --needed linux-firmware intel-ucode nano sudo systemd-ukify
```

```zsh
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

### 4.2 Set Timezone

```zsh
# Set timezone to your own continent and city
ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime

# Set hardware clock
hwclock --systohc
```

### 4.3 Configure Locale & Keyboard

Now we are going to configure our system language. You may edit or skip depending on your language and what you want, but if unsure here is what I usually go with: 

I am configuring a system that uses the English language in every aspect except for the date format, clock and measurement units. Dates will display with Norwegian names for both days and months and the flawed American formatting for where the day and the month is placed in DD/MM/YYYY will also be fixed with this change. The clock will display as 00:00 in what the Americans call "military time" instead of 0:00 with AM and PM. I also want my measurement units to default to what my language uses. If you do not set this your system will measure itself with freedom units for things like hardware sensors, so say if you need an accurate assessment of your CPU temperature, unless you set this it will default to Fahrenheit instead of Celsius.

Using the country code in `locale.gen` with fine grained `locale.conf` settings achieves this, if you want this type of system too but with your own language/country defaults you can just use your own in place of the Norwegian one.

```zsh
# Now we are going to configure our system language.
# I am going to have my system be in English,
# but my time and date will be set as it is in Norway.
# So an English system with a DD/MM/YYYY and 00:00 "military clock".
#
# I also want to default my measurement units to what my language uses
# so instead of Fahrenheit for temperature for example I want to use Celsius.
# If you do not set this, it will default to imperial units.
#
nano /etc/locale.gen

# Go down the list and uncomment both:
Uncomment: en_US.UTF-8 UTF-8 # for U.S English
Uncomment: nb_NO.UTF-8 UTF-8 # for Bokmål Norwegian (replace with your own or leave out)

# Then generate locales
locale-gen

---

# Set system locale
nano /etc/locale.conf

# add
LANG=en_US.UTF-8    # LANG for system language
LC_TIME=nb_NO.UTF-8 # LC_TIME for date & time to my specific LANG default
LC_MEASUREMENT=nb_NO.UTF-8 # This defaults your measurement units to your LANG default

---

# Set console keymap & font
nano /etc/vconsole.conf

# add
KEYMAP=no-latin1 # Keyboard layout for the administrative console
FONT=ter-118n  # This is a console font which makes boot font larger,
               # and more easily readable.
---

# set system keymaps
#
localectl set-keymap no-latin1

# One issue with kde is that it neither respects nor inherits
# system level keymaps. It uses its own system for this.
# So in order to not boot into a system with us keymap
# and having to manually change it in system settings
# you have to make a custom user level config.

# Create config folder and
# the keymap config file
# Change "lars" to your user
mkdir -p /home/lars/.config
nano /home/lars/.config/kxkbrc
```

```ini
# Put this in the file, but edit "no" to your own country code:

[Layout]
LayoutList=no
Use=true
VariantList=
```

```zsh
# Save, then fix ownership
# again change "lars" to your user:
chown -R lars:lars /home/lars/.config
chmod 644 /home/lars/.config/kxkbrc

```

### 4.4 Set Hostname and Hosts

```zsh
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



# 4.6 Install the System

These are all the packages needed for a complete & functional KDE Plasma desktop environment.

What is included is the complete KDE Plasma desktop stack, English spell check, graphics drivers with hardware acceleration drivers, CUDA (NVIDIA), networking, various helpers for other packages like `usbutils` and `tessaract`, the Dolphin file manager and its plugins, PipeWire sound support, and fonts. 

Any other package included is technically optional, but I strongly reccommend them. [**Here's**](pkgchoices.md) why I included those. **Please review them before installing.**


NVIDIA: 
```zsh
# pipe commands, like before type out each pipe line, press enter on each until base-devel
# then when u press enter it installs it all
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty ark unarchiver unrar 7zip kamera \
  kio-admin plasma-login-manager kdegraphics-thumbnailers ffmpegthumbs kdialog \
  tesseract tesseract-data-eng \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver libva-utils cuda vulkan-headers \
  pacman-contrib git wget hunspell hunspell-en_us quota-tools usbutils \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols zsh-completions \
  base-devel
```

or AMDGPU:
```zsh
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty ark kio-admin \
  tesseract tesseract-data-eng \
  unarchiver unrar 7zip kamera vulkan-headers \
  plasma-login-manager kdegraphics-thumbnailers ffmpegthumbs kdialog \
  mesa vulkan-radeon zsh-completions \
  libva libva-utils \
  quota-tools hunspell hunspell-en_us usbutils \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols \
  pacman-contrib git wget \
  base-devel
```

or Intel GPUs (I think):
```zsh
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty ark kio-admin \
  tesseract tesseract-data-eng \
  unarchiver unrar 7zip kamera vulkan-headers \
  plasma-login-manager kdegraphics-thumbnailers ffmpegthumbs kdialog \
  mesa vulkan-intel zsh-completions \
  libva libva-utils intel-media-driver \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols \
  hunspell hunspell-en_us quota-tools usbutils \
  pacman-contrib git wget \
  base-devel
```

### OPTIONAL: wireless-regdb
If you use wireless then an **essential package** is also `wireless-regdb`. It installs regulatory.db, a machine-readable table of Wi-Fi rules per country  that allows you to connect properly. If regulatory.db is missing or cannot be read, Linux falls back to the “world” regdomain 00. That profile is **intentionally conservative,** which means fewer channels and more restrictions. For example, world 00 marks many 5 GHz channels as passive-scan only and limits parts of 2.4 GHz (12–13 passive, 14 effectively off).

This is not needed if you only use Ethernet.

```zsh
# install
pacman -S --needed wireless-regdb

# after install enable your region
nano /etc/conf.d/wireless-regdom

# For example, for Norway look for the one that says "NO",
# then uncomment the line by removing the # symbol at the beginning
# so it looks exactly like this:
WIRELESS_REGDOM="NO"

# then save
```



### 4.6 Configure Initramfs

```zsh
# Edit mkinitcpio configuration, you will have to edit both MODULES & HOOKS
# Modules loads drivers early on which prevents the race issues that plague NVIDIA on Linux
# NVIDIA users are also required to remove 'kms' from HOOKS because of this.
nano /etc/mkinitcpio.conf

---

# MODULES
#
# For amdgpu just put 'amdgpu' in modules
# NVIDIA on the other hand is as always a bit more involved:
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

---

# HOOKS
#
# - Remove consolefont since it is redundant. The feature is already satisfied by 'sd-vconsole'
# - IMPORTANT: Again, you must remove 'kms' from HOOKS=() if you use nvidia, AMDGPU can ignore this however

HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)


```

### 4.8 Install UKIs and Configure Bootloader

```zsh
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
```

#### Add a minimal cmdline with kernel option(s)
```zsh
# Open up cmdline and edit it
nano /etc/kernel/cmdline
```

```zsh
## add to /etc/kernel/cmdline :
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=30
```

With `systemd-gpt-auto-generator` you do not need to specify UUIDs of your drives, the only thing required here is `rw`. Read more about the other settings added [**here**](extra/misc/kernelflags.md).

#### Make the ESP directory
```zsh
# Make ESP directory
mkdir -p /efi/EFI/Linux
```

#### Edit kernel-install config so it installs UKIs to the ESP

```zsh
# Edit:
nano /etc/kernel/install.conf
```

```zsh
# Add only:
layout=uki
```

### Now install kernel UKIs
```zsh
# Simply run
kernel-install add-all
```

#### Configure bootloader

```zsh
# write the loader
nano /efi/loader/loader.conf

## add to loader
timeout 10
console-mode auto
editor no
```

### 4.9 Create swap file & Configure Zswap

For swapping I always go with `zswap` file instead of a swap partition or `zram`.  I used to use `zram` but I have read some write-ups done by much smarter people than myself who have come to the conclusion that for most users `zswap` is recommended. If you are curious, read [**this**](https://chrisdown.name/2026/03/24/zswap-vs-zram-when-to-use-what.html) and [**this**](https://linuxblog.io/zswap-better-than-zram/).

```zsh
# Create a 16 GiB swap file and initialize it in one step.
#   --size 16G   -> allocate a 16 GiB file
#   --file       -> create the file with correct mode and real blocks
#   -U clear     -> clear any existing UUID in the header
mkswap -U clear --size 16G --file /swapfile
```

edit:
```zsh
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
```zsh
systemctl enable swapfile.swap
```

## Kernel/sysctl Optimizations

```zsh
# Clone repo first:
cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials.git

# Then leave tmp directory
cd
# Create sysctl.d folder
mkdir -p /etc/sysctl.d/

# copy from tmp
cp /tmp/ArchLinuxTutorials/70-settings.conf /etc/sysctl.d/sysctl.d/70-settings.conf
```
These are a combination of CachyOS settings and other sources. To read what they do, click [**here.**](70-settings.conf)

```zsh
# Load settings from all system configuration files to configure kernel parameters at runtime.
sysctl --system
```

---

### Enable REISUB via sysctl

* This is an optional but highly recommended tweak which enables all the Magic SysRq functions needed for **REISUB.** This is a way to safely shut down your system if it ever freezes without having to use the power button which carries the inherent risk of corrupting your file system. - [**Read this document**](REISUB.md) carefully to understand what it is, how to use it, and why you should want to enable it despite the risks.

```zsh
# create file
nano /etc/sysctl.d/99-sysrq.conf
```

```zsh
# /etc/sysctl.d/99-sysrq.conf
#
# 244 is the sum of:
# 4: keyboard control, used by R
# 64: signal processes, used by E and I
# 16: sync filesystems, used by S
# 32: remount filesystems read-only, used by U
# 128: reboot or power off, used by B
kernel.sysrq = 244
```

```zsh
# Load settings from all system configuration files to configure kernel parameters at runtime.
sysctl --system
```

---

### Udev rules

udev is Linux’s device manager.  It reacts to hardware events, such as a disk being added or changed, and applies matching rules from .rules files. This can help tweak the system behavior to your liking. Rule files are processed in lexical order, so the numeric prefix in `60-ioschedulers.rules` for example controls when this rule is evaluated relative to other udev rules.

#### 60-ioschedulers.rules

This udev rule persistently & dynamically sets Linux block-device I/O schedulers when storage devices are added or changed based on the best scheduler for w/e you have. An I/O scheduler controls how read and write requests are ordered before they reach a storage device. The goal is better desktop responsiveness and more sensible latency behavior per drive type, instead of relying on one default for everything.

```zsh
# Create folder
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/rules.d/60-ioschedulers.rules /etc/udev/rules.d/60-ioschedulers.rules

# Manually:
nano /etc/udev/rules.d/60-ioschedulers.rules
```

```conf
# /etc/udev/rules.d/60-ioschedulers.rules
# HDD
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

# SSD
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="mq-deadline"

# NVMe SSD
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="kyber"
```

The rest of the rules are optional/hardware specific. [**Here's the list of them**](udev-rules.md) . You may pick and choose which ones seem best for your system.

---


### modprobe.d optimizations 

```zsh
# These are optimizations as well.
# Create folder
mkdir -p /etc/modprobe.d/

# These are pretty much verbatim lifted from CachyOS
# Go and analyze them yourself before copying to ensure
# you actually want their tweaks. Most of them are general
# improvements that you won't notice any regression from,
# but its still good to be certain.
#
# copy NVIDIA (if you have NVIDIA)
cp /tmp/ArchLinuxTutorials/nvidia.conf /etc/modprobe.d/20-nvidia.conf

# copy AMDGPU (if you plan to use AMDGPU)
cp /tmp/ArchLinuxTutorials/amdgpu.conf /etc/modprobe.d/21-amdgpu.conf

# copy blacklist
cp /tmp/ArchLinuxTutorials/blacklist.conf /etc/modprobe.d/22-blacklist.conf
```

---

### Fix Emojis rendering as black and white
```zsh
# Qt does not support automatically looking up the best font for emojis
# Therefore the user must manually add a color emoji font as a fallback
# or they are sometimes rendered incorrectly.
#
# This fix uses Noto-Fonts-Emoji, we installed it in the list of packages.
# If you later replace it with another Emoji package, make sure to update this
# as well.
#
mkdir -p /etc/fonts/conf.d

# copy it from tmp
cp /tmp/ArchLinuxTutorials/75-noto-color-emoji.conf /etc/fonts/conf.d/75-noto-color-emoji.conf
```

---

### Force GTK to use Portals
```zsh
# This is important for file pickers and GTK windows on KDE
# This may mean nothing to you now, but basically its the
# difference between either having a maximize button on
# the titlebar of Firefox or not.
#
mkdir -p /etc/environment.d
nano /etc/environment.d/99-portal.conf 
```

```ini
# 99-portal.conf 
GTK_USE_PORTAL=1
GDK_DEBUG=portals
```

---

### Optional: Set Login Theme Before Reboot

```zsh
# This will set your Login theme so you aren't
# met with an old login screen when you first boot
#
# If you want to do this later that's okay
mkdir -p /etc/plasmalogin.conf.d
nano /etc/plasmalogin.conf.d/10-breeze.conf
```

```ini
# 10-breeze.conf
[Theme]
Current=breeze
```

### Add a DNS Resolver (systemd-resolved)

* This is a good desktop default. What you gain over the more typical default Arch setup is DNS behavior. With plain NetworkManager plus a conventional `/etc/resolv.conf`, DNS is usually just a flat list of nameservers. With `systemd-resolved`, you get a modern stub resolver at `127.0.0.53`, per-link DNS routing, and better split-DNS behavior, which matters for VPNs and multi-network systems. The resolver also supports LLMNR, mDNS, DNSSEC controls, and DNS-over-TLS configuration, i.e it has some features you may want to learn & use in the future. 

* `systemd-resolved` maintains `/run/systemd/resolve/stub-resolv.conf` for traditional programs, and that file should be used through a symlink from `/etc/resolv.conf`. 

* **NOTE: It must be configured to use the resolver before you reboot into Arch due to the chroot environment. I show how to do that in the last step, but be very wary of not skipping it!**

```zsh
# Create NetworkManager's local config directory
mkdir -p /etc/NetworkManager/conf.d

# Create the systemd-resolved DNS config
nano /etc/NetworkManager/conf.d/20-systemd-resolved.conf
```

```ini
# /etc/NetworkManager/conf.d/20-systemd-resolved.conf

[main]
dns=systemd-resolved
rc-manager=auto
```

```zsh
# Enable the service for the installed system.
systemctl enable systemd-resolved.service
```

---


## Step 5: Complete Installation

```zsh
# Enable Essential Services
# 
# Include cups.service if you are using printer
# Include bluetooth.service for Bluetooth if you installed bluez and bluez-utils
systemctl enable NetworkManager plasmalogin systemd-timesyncd systemd-boot-update.service \
fstrim.timer reflector.timer pkgstats.timer

# Exit environment
exit

# Make /etc/resolv.conf use systemd-resolved's stub resolver.
#
# ! ENSURE you do this here before umounting !
#
# This is what makes traditional DNS clients use 127.0.0.53 correctly.
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

# When done and confirmed done, then unmount all partitions
umount -R /mnt

# And shut down system.
shutdown now
```

Remove ArchISO USB from computer then boot back into it via power button.
If you did everything correct, **congrats you just installed Arch Linux!**

---

### TROUBLESHOOT 

#### 1) "My Panel/Taskbar is not appearing! / its on the wrong monitor!"

 1. Right click on desktop and click Display Configuration. 
 2. Go to "Change Screen Priorities" and click the arrows up in prio for the monitor you want
 the panel on.
 3. Then press OK. It should refresh and show panel on your primary now. This persists on reboot. 
   
This happens to me every time I install KDE on my desktop with three monitors.  I have no idea why. Used to be worse when changing primary monitor didnt move the panel, back then you had to refresh the theme then it would move, but now all you need to do to fix this issue is this. This only happens on multi monitor setups, my laptop with one screen obv doesn't have this issue.


---

# 1) Post-Install Tutorial
Head to `arch_kde_post_tutorial.md` to do the post-install tutorial. I teach you many things you should know when using Arch so I do not consider it to be optional, but technically after this tutorial is over you have a bootable system with KDE on Arch so if you want to trial and error instead be my guest.

---

