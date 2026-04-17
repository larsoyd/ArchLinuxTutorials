# Complete Arch Linux Tutorial (KDE Plasma + Wayland w/ Automounting Partitions)

This is an **OPINIONATED** Arch installation guide for regular folks who just want a working system to game on that's straight forward with a DE that is most like Windows
and usually the one most people want to use because of that, at least for their first DE. I've used every DE and WM that is both trendy and some obscure,
I started with KDE Plasma and Arch Linux. I always come back to both eventually. It's fun to try out new things, but KDE Plasma is OP at the moment I am writing 
this. It's fully featured, they finally have a good process in eliminating bugs which plagued the DE before, and it's very easy to customize. Most DEs and WMs have
some caveat, KDE Plasma does not with the exception of one thing for some users. KDE Plasma is losing Xorg/X11 support soon, the only way forward for users who want to use X11 is to use SonicDE (A fork of KDE Plasma X11) and XLibre. An experimental script will be provided for this on the bottom. **Installing SonicDE will replace KDE Plasma, you can only use one of these sessions.**


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
- Option B) `linux-zen` default kernel, `linux-lts` backup. ~ Option A) `linux-cachyos-bore` and `linux-cachyos-lts` for optimized kernel.
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

- While in this tutorial I will be assuming you are using the official ArchISO Installation Medium, I must concede that after installing Arch via the official medium for years I now instead opt for a live environment for my own convenience. Basically what this means is that I install Arch from another distro, and I choose the LiveISO maintenance distro [SystemRescue](https://www.system-rescue.org/) which is based on Arch and comes with the installation scripts on disc for maximum convenience here. Every step except for about two are the same. If this is your first time I strongly recommend **not** doing this, but if you already have a gist on installing Arch and you don't want to use the TUI you can do it in this way as well.
- The way to do this is before you do the install as usual after having connected to the internet + configured any keyboard settings if you don't have an US keyboard in the terminal in the XFCE desktop of SystemRescue is write: `pacman --config=/etc/pacman-rolling.conf -Sy` to install the current pacman.conf instead of the snapshot version SystemRescue ships with then when you get to the `pacstrap` step you instead write: `pacstrap -C /etc/pacman-rolling.conf -K /mnt base nano sudo` in order to pacstrap with the new config. 
- If the step to partition with systemd-repart fails due to a device being "in use", you can write `partprobe` on the disk from `lsblk -l` that you are partitioning. E.g: `partprobe /dev/nvme0n1` or simply run the command again and it should work.
- **NOTE:** Pre-chroot reflector step will fail on SystemRescue as the distro does not ship with `reflector`. You can simply proceed without doing this until you chroot in, from inside your system run `pacman -S reflector` and then do the step there instead, or if you want you can install it to SystemRescue with: `pacman --config=/etc/pacman-rolling.conf -S reflector` and do it before as the tutorial recommends for ArchISO users but it's largely unnecessary unless you have mirror problems.

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

```zsh
# Update mirrorlist before install so you install with fastest mirrors
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

# When you understand all of this you can use a faster version of this
# that I like to use:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
-l 10 --sort rate --save /etc/pacman.d/mirrorlist

# Or update reflector for fastest and longer timeout
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 30 --save /etc/pacman.d/mirrorlist
```

```zsh
# and then **Install the base of Arch Linux!** :
pacstrap /mnt base nano sudo
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

# Create user with necessary groups
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

# CachyOS packages and Kernel

My reasoning for including this is that the CachyOS kernel and packages are very good at the moment.
There are two options to install the CachyOS kernels on Arch, either through adding CachyOS repos 
or the AUR (via Chaotic-AUR so you dont have to compile it which takes ages)

**NOTE:** Combining repositories like this is officially unsupported by Arch Linux, if you suffer breakages, do not
come running to me, the forums or whatever with your problems. If you can't fix it, then insert install USB again, chroot in 
and remove the kernels and the repos. 

Using unofficial kernels is also not officially supported. By using the CachyOS kernel and/or repos you 
acknowledge this.

If you don't want the Cachy kernels you skip this + the ChaoticAUR method to the **6.5 Install Packages** step showing what kernels to install
if you aren't, like linux-zen and linux-lts. 

---

### Option A) Add CachyOS Repos to Arch Linux:

* SKIP THIS IF YOUR CPU DOES NOT SUPPORT: **znver4, x86_64_v3, or x86_64_v4,**

* A separate Chaotic-AUR method to get the kernels will be provided if your CPU dont support any of those instructions. Scroll until you see "Option B)" and start from there instead.

```zsh
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

```zsh
# Now that you have added the mirrors + keys
# You need to edit /etc/pacman.conf
nano /etc/pacman.conf
```


I will add the CachyOS znver4 repos for AMD Zen 4 and Zen 5.
If your CPU don't support znver4 add any of the others that fit.

Keep the Arch repos ([core], [extra], [multilib]) exactly as they are.

---

**WARNING: CHANGE ARCHITECTURE under "Architecture = auto" to:**

* Architecture = x86_64 x86_64_v4"
  
or

* Architecture = x86_64 x86_64_v3"

**add that INSTEAD of "auto" as pacman can't resolve Cachy repos automatically**

#### ADD ONLY ONE of the 3 mirrorlists under that fit your CPU above the other repos
#### in the same section & in this direction:


```zsh
# If your CPU is based on Zen 4 or Zen 5, add [cachyos-znver4],
# [cachyos-core-znver4], and [cachyos-extra-znver4]:

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
```

```zsh
# If your CPU supports x86-64-v3, then add [cachyos-v3],[cachyos-core-v3],[cachyos-extra-v3]
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
```

```zsh
# If your CPU supports x86-64-v4, then add [cachyos-v4], [cachyos-core-v4], and [cachyos-extra-v4]
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
```

```zsh
# IMPORTANT: Update to new repos & packages when mirrors are added
# If done correctly the Cachy versions of packages will now be retrieved
#
# If one mirror 404s out it is not necssarily an  error,
# it usually just means one of the Cachy mirrors doesn't have the package
# that you are requesting. To check if the package installed you can
# sanity check w/e dependency errored with "pacman -Q (pkgname)"
# If it is returned it was retrieved. I wish that pacman would mute this
# term noise if the package was actually retrieved, but alas...
#
# Press Y for Yes to any replacements when prompted:
#
pacman -Syu
```

### 6.1 Install CachyOS Kernel + Headers:

```zsh
pacman -S --needed linux-cachyos-bore linux-cachyos-lts linux-cachyos-bore-headers \
linux-cachyos-lts-headers
```

---

### Option B) ALTERNATIVE CHAOTIC AUR METHOD:

```zsh
# Import and locally sign the Chaotic-AUR repo key
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
chmod +x chaotic-setup.sh
./chaotic-setup.sh

# Leave /tmp
cd
```

```zsh
# Now that you have added the mirrors + keys
# You need to edit /etc/pacman.conf
nano /etc/pacman.conf
```

```zsh
# Keep the Arch repos ([core], [extra], [multilib]) exactly as they are.
# Add Chaotic-AUR repo UNDER all the other ones existing.
#
# /etc/pacman.conf
# under all the other repos:

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
```

```zsh
# Update package database
pacman -Syu
```

### Install CachyOS Kernel + Headers:

```zsh
# As of writing the Chaotic-AUR does not have the CachyOS kernel I prefer to use
# which is the BORE kernel. It only packages the lts, regular and rc versions.
# Out of those I would pick both lts and regular, rc is more for realtime audio work.
pacman -S --needed linux-cachyos linux-cachyos-lts linux-cachyos-headers \
linux-cachyos-lts-headers
```

---


### 6.5 Install Packages
```zsh
# linux-zen is a tuned kernel, should work on any CPU.
# it has nothing to do with the Zen architecture by AMD FYI.
# Optional if you got the cachyos kernels already
#
# THIS IS REQUIRED IF YOU DONT GET CACHYOS KERNEL:
pacman -S --needed linux-zen linux-lts linux-zen-headers linux-lts-headers

---
REGARDLESS OF WHAT KERNEL YOU GOT, CONTINUE FROM HERE:

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

```zsh
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

---

# Set system locale
nano /etc/locale.conf

# add
LANG=en_US.UTF-8    # LANG for system language
LC_TIME=nb_NO.UTF-8 # LC_TIME for date & time to my specific LANG default

---

# Set console keymap & font
nano /etc/vconsole.conf

# add
KEYMAP=no-latin1 # Skip this if US keyboard
FONT=ter-118n  # But add this.
               # This is a console font which makes it larger,
               # and more easily readable on boot
---

# set system keymaps
#
localectl set-keymap no-latin1

# FYI, x11 should be done even if you are only using wayland
# as the default is still sourced from systemd-localed (locale1) 
# and the generated /etc/X11/xorg.conf.d/00-keyboard.conf
#
# Also note: pc105 is what I have and its the default in most countries
# but in the US pc104 is the default. Check what model you use beforehand.
localectl set-x11-keymap no pc105

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

## 4.5.5 Package Choice

### Info:
I have taken the liberty to make some decisions for a few packages you will install, some of them are technically "optional" but
all of them are in my opinion essential to the well functioning of a KDE Plasma desktop. 

Here's why I included those:


### pkgstats 
pkstats is a super harmless way to help out the Arch developers that work hard and mostly for free to make our wonderful distro.
It basically just advertises a list of your core and extra packages that you use to them  so they can know what packages to 
prioritize in testing and for other things. If you are extremely paranoid then you can leave it out.

### kitty 
kitty is a terminal that I think is the best sort of default terminal on Linux. It's easy to use, GPU accelerated, fast enough and hassle free.
It allows you to zoom in by pressing `CTRL + SHIFT and +` and zoom out by `CTRL + SHIFT and -` It doesn't look terrible like some terminals do.
konsole is included as a backup. If you want to use another terminal as your main, replace it.

### ark
ark is a KDE developed method to unzip archive files on your computer. "Optional" but you are going to want this. It supports various optional additions included like `7zip` and `unrar` .7Z and .RAR format support respectively. 

---

## **NOT INCLUDED IN THE STEP BUT YOU MAY WANT TO INCLUDE:**

### wireless-regdb
If you use wireless then an **essential package** is also `wireless-regdb`. It installs regulatory.db, a machine-readable table of Wi-Fi rules per country  that allows you to connect properly. If regulatory.db is missing or cannot be read, Linux falls back to the “world” regdomain 00. That profile is **intentionally conservative,** which means fewer channels and more restrictions. For example, world 00 marks many 5 GHz channels as passive-scan only and limits parts of 2.4 GHz (12–13 passive, 14 effectively off).

```zsh
# after install enable your region
nano /etc/conf.d/wireless-regdom

# For example, for the United States look for the one that says "US",
# then uncomment the line by removing the # symbol at the beginning
# so it looks exactly like this:
WIRELESS_REGDOM="US"

# then save
```

### audiocd-kio
This adds the audiocd:/ KIO worker so Dolphin and other KDE apps can read and rip audio CDs. Not needed on non-KDE Plasma systems, but KDE has their own thing for this. If you are on a laptop with a CD player and/or ever need to play audio CDs on your PC then you are going to want this.

### libdvdread, libdvdnav, and libdvdcss
This is the same as above but for DVD playback. 

### libbluray and libaacs
Same for Blu-Rays. After you have installed the system and configured an AUR helper you may also wish to install **libbdplus** from the AUR if you want for BD+ playback. From there you will have to set it up with KEYS which is shown on the Arch Wiki about Blu-Ray.

### bluez and bluez-utils
For Bluetooth support if you use Bluetooth. You will also need to enable `bluetooth.service` then at the end of the tutorial.

### cups & cups-pdf (Optional: bluez-cups for Bluetooth printers)
If you need printer support. You will also need to enable `cups.service` at the end of the tutorial. For GUI support you need to also install `system-config-printer` & `cups-pk-helper`.

---

# 4.6 Install the System

**EITHER**

NVIDIA: 
```zsh
# pipe commands, like before type out each pipe line, press enter on each until base-devel
# then when u press enter it installs it all
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty ark unarchiver unrar 7zip kamera \
  kio-admin plasma-login-manager kdegraphics-thumbnailers ffmpegthumbs kdialog \
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



### 4.6 Configure Initramfs

```zsh
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

---

# Example for MODULES if you use nvidia:
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

---

# Example for MODULES if you use amdgpu
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
# - MUST use 'systemd' instead of 'udev' - UPDATE: Arch now defaults to systemd instead of udev,
#   so here you just need to check if it's right.
#
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
# All the other zswap kernel settings are default on Arch native kernels.
# I included them to ensure they are loaded regardless.
#
## /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=30
```

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

### Kernel Optimizations :

```zsh
# These are a combination of CachyOS settings and other sources
# Create sysctl.d folder
mkdir -p /usr/lib/sysctl.d/

# copy from tmp
cp /tmp/ArchLinuxTutorials/70-settings.conf /usr/lib/sysctl.d/70-settings.conf
```

```conf
# The value controls the tendency of the kernel to reclaim the memory.
# It's used for caching of directory and inode objects (VFS cache).
# Lowering it from the default value of 100 makes the kernel less inclined -
# - to reclaim VFS cache (do not set it to 0, this may produce out-of-memory conditions)
vm.vfs_cache_pressure = 50

# Contains, as bytes, the number of pages at which a process which is
# generating disk writes will itself start writing out dirty data.
vm.dirty_bytes = 268435456

# page-cluster controls the number of pages up to which consecutive pages are read in from swap in a single attempt.
# This is the swap counterpart to page cache readahead. The mentioned consecutivity is not in terms of virtual/physical addresses,
# but consecutive on swap space - that means they were swapped out together. (Default is 3)
# increase this value to 1 or 2 if you are using physical swap (1 if ssd, 2 if hdd)
vm.page-cluster = 1

# Contains, as bytes, the number of pages at which the background kernel
# flusher threads will start writing out dirty data.
vm.dirty_background_bytes = 67108864

# The kernel flusher threads will periodically wake up and write old data out to disk.  This
# tunable expresses the interval between those wakeups, in 100'ths of a second (Default is 500).
vm.dirty_writeback_centisecs = 1500

# This action will speed up your boot and shutdown, because one less module is loaded.
# Additionally disabling watchdog timers increases performance and lowers power consumption
# Disable NMI watchdog
kernel.nmi_watchdog = 0

# Enable the sysctl setting kernel.unprivileged_userns_clone to allow normal users to run unprivileged containers.
kernel.unprivileged_userns_clone = 1

# To hide any kernel messages from the console
kernel.printk = 3 3 3 3

# Restricting access to kernel pointers in the proc filesystem
kernel.kptr_restrict = 2

# Disable kexec as a security measure
kernel.kexec_load_disabled=1

# Many Windows games need this disabled to run properly.
# They abuse split locks
kernel.split_lock_mitigate = 0

# Increase netdev receive queue
# May help prevent losing packets
net.core.netdev_max_backlog = 4096

# Set size of file handles and inode cache
fs.file-max = 2097152

# Use 'bbr' to achieve higher throughput when sending to high-latency destinations.
# Also 'fq' to prevent one greedy app from causing lag (bufferbloat) for everything else.
# `bbr` relies on pacing, and thus performs better with the `fq` qdisc.
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# The sysctl swappiness parameter determines the kernel's preference for pushing anonymous pages or page cache to disk in memory-starved situations.
# A low value causes the kernel to prefer freeing up open files (page cache), a high value causes the kernel to try to use swap space,
# and a value of 100 means IO cost is assumed to be equal.
vm.swappiness = 100

# Ensure that applications don't break/complain from hitting the limit
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
```

```zsh
# Load settings from all system configuration files to configure kernel parameters at runtime.
sysctl --system
```

### modprobe.d optimizations 

```zsh
# These are optimizations as well.
# Create folder
mkdir -p /usr/lib/modprobe.d/

# These are pretty much verbatim lifted from CachyOS
# Analyze them yourself if curious
#
# copy NVIDIA (if you have NVIDIA)
cp /tmp/ArchLinuxTutorials/nvidia.conf /usr/lib/modprobe.d/nvidia.conf

# copy AMDGPU (if you plan to use AMDGPU)
cp /tmp/ArchLinuxTutorials/amdgpu.conf /usr/lib/modprobe.d/amdgpu.conf

# copy blacklist
cp /tmp/ArchLinuxTutorials/blacklist.conf /usr/lib/modprobe.d/blacklist.conf
```

### Force GTK to use Portals
```zsh
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

### Fix Emojis rendering as black and white
```zsh
# Qt does not support automatically looking up the best font for emojis
# Therefore the user must manually add a color emoji font as a fallback.
# This fix uses Noto-Fonts-Emoji, we installed it in the list of packages.
#
# If you later replace it with another Emoji package, make sure to update this
# as well.
#
mkdir -p /etc/fonts/conf.d

# copy from tmp
cp /tmp/ArchLinuxTutorials/75-noto-color-emoji.conf /etc/fonts/conf.d/75-noto-color-emoji.conf
```

```conf
# /etc/fonts/conf.d/75-noto-color-emoji.conf
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

    <!-- Add generic family. -->
    <match target="pattern">
        <test qual="any" name="family"><string>emoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <!-- This adds Noto Color Emoji as a final fallback font for the default font families. -->
    <match target="pattern">
        <test name="family"><string>sans</string></test>
        <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test name="family"><string>serif</string></test>
        <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test name="family"><string>sans-serif</string></test>
        <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test name="family"><string>monospace</string></test>
        <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
    </match>

    <!-- Block Symbola from the list of fallback fonts. -->
    <selectfont>
        <rejectfont>
            <pattern>
                <patelt name="family">
                    <string>Symbola</string>
                </patelt>
            </pattern>
        </rejectfont>
    </selectfont>

    <!-- Use Noto Color Emoji when other popular fonts are being specifically requested. -->
    <match target="pattern">
        <test qual="any" name="family"><string>Apple Color Emoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Segoe UI Emoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Segoe UI Symbol</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Android Emoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Twitter Color Emoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Twemoji</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Twemoji Mozilla</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>TwemojiMozilla</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>EmojiTwo</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Emoji Two</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>EmojiSymbols</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

    <match target="pattern">
        <test qual="any" name="family"><string>Symbola</string></test>
        <edit name="family" mode="assign" binding="same"><string>Noto Color Emoji</string></edit>
    </match>

</fontconfig>
```

### Optional: Set Login Theme Before Reboot

```zsh
# This will set your Login theme so you aren't
# met with an old login screen first boot
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

This is a good desktop default. What you gain over the more typical default Arch setup is DNS behavior. With plain NetworkManager plus a conventional /etc/resolv.conf, DNS is usually just a flat list of nameservers. With systemd-resolved, you get a local caching stub resolver, per-link DNS routing, and better split-DNS behavior, which matters for VPNs and multi-network systems. The resolver also supports LLMNR, mDNS, DNSSEC controls, and DNS-over-TLS configuration. Red Hat’s networking docs describe this model as NetworkManager writing 127.0.0.53 to /etc/resolv.conf while systemd-resolved dynamically routes queries to the right upstream DNS servers for each connection. 

```zsh
mkdir -p /usr/lib/NetworkManager/conf.d/
nano /usr/lib/NetworkManager/conf.d/dns.conf
```

```ini
# /usr/lib/NetworkManager/conf.d/dns.conf
[main]
dns=systemd-resolved
```

```zsh
# Enable the service
systemctl enable systemd-resolved.service
```

### 4.10 Enable Essential Services

```zsh
# Enable network, display manager, and timesyncd
# Include cups.service if you are using printer
# Include bluetooth.service for Bluetooth if you installed bluez and bluez-utils
systemctl enable NetworkManager plasmalogin systemd-timesyncd systemd-boot-update.service \
fstrim.timer reflector.timer pkgstats.timer
```

---


### OPTIONAL: SonicDE/XLibre Install Script (EXPERIMENTAL)

- KDE Plasma is losing X11 support next major release to become a Wayland only DE. If you are new to Linux and dont know what any of that means then you can just skip this part to Step 5. 

- For those who want to continue using X11 **instead** of Wayland on Plasma, your only option atm is to migrate to XLibre and SonicDE. XLibre is a continually maintained fork of X11, while SonicDE is the same but for KDE Plasma 6 (X11). I have written a script for you that *should* work if you want to migrate to both.

- Please be aware before you do that SonicDE by the virtue of the decreasing demand for X11 is a niche option, this is because Wayland is finally maturing for many users. As such it is not going to be as healthy of a project as KDE Plasma both was for X11 and is for Wayland, and that also means that *some* regressions are probably inevitable. This is not me dunking on SonicDE, it's just how it is whether you like Wayland or not. XLibre have similar problems on top of a complex reputation due to the personal politics of the head maintainer/creator behind it, google it if you are worried about this.

- **NOTE: If you install SonicDE it WILL replace your KDE Plasma session. You sadly can't run KDE Plasma (Wayland) and SonicDE on your system at the same time.**

```zsh
# Login to your user
su - lars

# Clone to user
mkdir -p git
cd /git
git clone https://github.com/larsoyd/ArchLinuxTutorials.git
cd ArchLinuxTutorials

# Install SonicDE + XLibre
chmod +x xlibre-sonicde.sh
./xlibre-sonicde.sh

# Logout
exit

# disable Plasma Login Manager
systemctl disable plasmalogin

# Enable SDDM
systemctl enable sddm
```

## Step 5: Complete Installation

```zsh
# Exit environment
exit

# Then unmount all partitions
umount -R /mnt

# Reboot into new system
shutdown now

# Remove ArchISO USB from computer then boot back into it
#
# This is also the way to fix if the taskbar (panel) appears on the wrong monitor: Simply go to Global Theme
# Press Breeze or Breeze-Dark, select BOTH checkboxes and hit apply. Wait and then it will correctly apply
# This will also persist on reboots as well. 
```

---

# 1) Post-Install Tutorial
Head to `arch_kde_post_tutorial.md` to do the post-install tutorial. This is not optional.

---

# 2) OPTIONAL: How to fix those annoying 'missing firmware' warnings in mkinitcpio

* NOTE: This is only if you do have the `fallback` option on the UKIs which we removed in the guide, but if you kept it this will annoy you.
* Whenever you write `mkinitcpio -P` you might notice it keeps warning you about firmware that you are supposedly missing.
* If this bothers you, check out my tutorial, `mkinitcpio-fix.md` to fix this.
