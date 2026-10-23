# Arch Linux installation with KDE Plasma and Wayland

This is my opinionated guide to an Arch Linux desktop for gaming and daily use. It uses KDE Plasma, systemd-boot, and GPT partition discovery. I keep coming back to Arch and KDE because they give me the flexibility and desktop features I want.

The examples target an AMD CPU, an NVIDIA GPU, and a single NVMe SSD. AMD and Intel GPU package lists are included, but I have less experience with those setups. Check the Arch Wiki for your hardware before installing. The NVIDIA example assumes a Turing (NV160/TUXXX) or newer card supported by `nvidia-open-dkms`.

## Contents

- [How GPT auto-mounting works](#how-gpt-auto-mounting-works)
- [Prerequisites and example values](#prerequisites-and-example-values)
- [Step 0: Boot the installation medium](#step-0-boot-the-installation-medium)
- [Step 1: Partition the disk](#step-1-partition-the-disk)
- [Step 2: Mount filesystems](#step-2-mount-filesystems)
- [Step 3: Install the base system](#step-3-install-the-base-system)
- [Step 4: Configure the system](#step-4-configure-the-system)
- [Kernel and desktop settings](#kernel-and-desktop-settings)
- [Step 5: Complete the installation](#step-5-complete-the-installation)
- [Troubleshooting](#troubleshooting)
- [Next steps](#next-steps)

## How GPT auto-mounting works

`systemd-gpt-auto-generator` discovers and mounts partitions using their GPT partition type UUIDs. In this setup, root and other supported partitions are discovered without entries in `/etc/fstab`. This keeps their layout information in the partition table.

There are a few limitations to understand first:

- Automatic discovery is tied to the physical disk containing the root partition. This guide does not cover a root filesystem spread across multiple disks, such as a Btrfs RAID setup.
- The boot loader must set the `LoaderDevicePartUUID` EFI variable for root partition discovery. This guide uses systemd-boot, which supports it.
- Only the first partition of each supported type is mounted. For example, multiple partitions with type code `8302` do not all become home directories.
- Additional drives need their own configuration. See [mounting a new drive](extra/tutorials/newdrive.md).

For reference, GRUB can set `LoaderDevicePartUUID` when its `bli` module is loaded from `grub.cfg`:

```sh
if [ "$grub_platform" = "efi" ]; then
  insmod bli
fi
```

I like this approach because the disk describes its own layout, can move between machines without changing `fstab`, and works with tools such as systemd-nspawn. It also removes one source of mount configuration errors.

The resulting system uses:

- KDE Plasma on Wayland.
- `linux-zen` as the main kernel and `linux-lts` as a backup.
- Zsh as the user shell, with an optional switch to Dash for `/usr/bin/sh`.
- systemd-boot with Unified Kernel Images (UKIs).
- Zswap backed by a 16 GiB swap file.
- Ext4 for root, with optional `fast_commit` journaling.

## Prerequisites and example values

You need a bootable Arch Linux USB, an internet connection, and a UEFI system.

I use real values in the examples so you can see how the commands fit together. Replace these with your own before running the relevant commands:

| Example | Replace with |
|---|---|
| `/dev/nvme0n1` | Your installation disk, confirmed with `lsblk -l` |
| `lars` | Your username |
| `BigBlue` | Your hostname |
| `no-latin1`, `no`, `nb_NO.UTF-8` | Your keyboard layout and regional locale |
| `Europe/Oslo` | Your timezone |
| Norway and nearby mirror countries | Countries near you |

The examples use English for the system language and Norwegian formats for dates, time, and measurements. US keyboard users can skip changing the live console keymap.

### Optional: Using SystemRescue to install

I sometimes install from [SystemRescue](https://www.system-rescue.org/) because it provides a graphical live environment and Arch installation tools. The main guide assumes the official Arch ISO. If you prefer SystemRescue and already understand the installation process, read the [SystemRescue notes](extra/misc/systemrescue.md) first.

Before following the guide from SystemRescue, run `pacman --config=/etc/pacman-rolling.conf -Sy` in its XFCE terminal. Use the SystemRescue variants where shown below.

## Step 0: Boot the installation medium

Run these commands in the live environment. Each line is a separate command unless it ends with `\`, which continues the command on the next line. A continuation backslash must be the last character on its line.

### Keyboard and console font

List available keymaps, or filter the list using part of your country's name or code:

```zsh
# Browse available keyboard layouts
localectl list-keymaps | less
# Find layouts matching Norway
localectl list-keymaps | grep -i -E 'no'
```

For my Norwegian keyboard, I use `no-latin1`. Test the layout after loading it and choose another if needed. On a Nordic keyboard using the US layout, the key labelled `\` near Backspace produces `-`.

```zsh
# Load the Norwegian console layout
loadkeys no-latin1
```

Choose a readable console font. Start with:

```zsh
# Use a larger console font
setfont ter-118n
```

If it is too small, try:

```zsh
# Try the next font size
setfont ter-132n
```

For a larger version:

```zsh
# Double the console font size
setfont -d ter-132n
```

---

### UEFI and clock

Confirm that the firmware variables are available. The command should finish with `UEFI firmware detected`:

```zsh
# Confirm that the ISO booted in UEFI mode
ls /sys/firmware/efi/efivars && echo "UEFI firmware detected"
# Enable network time synchronization
timedatectl set-ntp true
```

---

### Network connection

Check the available interfaces and their state:

```zsh
# List network interfaces
ip link
# Show interface connection states
networkctl list
```

**Ethernet:** DHCP should be automatic on the ISO. Look for an address and gateway:

```zsh
# Show network addresses and gateways
networkctl status | sed -n '1,80p'
```

**Wi-Fi:** Check for a soft block, unblock wireless if needed, and identify your wireless device:

```zsh
# Check whether wireless is blocked
rfkill list
```

If wireless is soft-blocked:

```zsh
# Clear software blocks on wireless devices
rfkill unblock all
```

List devices, then replace `YOUR-DEV` and `YOUR-SSID` in the connection commands. Keep the quotes, especially when the network name contains spaces. `iwctl` prompts for the passphrase.

```zsh
# Find the wireless device name
iwctl device list
# Scan for nearby networks
iwctl station "YOUR-DEV" scan
# List the networks found
iwctl station "YOUR-DEV" get-networks
# Connect to the chosen network
iwctl station "YOUR-DEV" connect "YOUR-SSID"
```

Check IP connectivity, DNS resolution, and HTTPS access. For the final command, expect a successful response or a redirect such as HTTP 301 or 302:

```zsh
# Test connectivity without DNS
ping -c 3 1.1.1.1
# Check DNS resolution
resolvectl query archlinux.org
# Test connectivity by hostname
ping -c 3 archlinux.org
# Check the HTTPS response
curl -I https://archlinux.org
```

Confirm the clock status before partitioning:

```zsh
# Check the clock and synchronization status
timedatectl status | sed -n '1,12p'
```

## Step 1: Partition the disk

**The apply commands below erase the selected disk. Confirm the device before continuing.**

```zsh
# Identify the installation disk
lsblk -l
```

Set `d` to your installation disk. Choose **one** assignment. For the NVMe example:

```zsh
d=/dev/nvme0n1
```

For a disk shown as `/dev/sda` instead:

```zsh
d=/dev/sda
```

Create the directory for the partition definitions:

```zsh
mkdir -p /tmp/repart.d
nano /tmp/repart.d/10-esp.conf
```

Contents of `/tmp/repart.d/10-esp.conf`:

```ini
[Partition]
Type=esp
Label=EFI
Format=vfat
SizeMinBytes=2G
SizeMaxBytes=2G
```

Create the root partition definition:

```zsh
nano /tmp/repart.d/20-root.conf
```

Contents of `/tmp/repart.d/20-root.conf`:

```ini
[Partition]
Type=root
Label=root
Format=ext4
```

Preview the layout:

```zsh
# Preview the partition layout without writing it
systemd-repart \
  --definitions=/tmp/repart.d \
  --empty=force \
  --discard=no \
  "$d"
```

Choose **one** of the following apply commands.

**Standard Ext4:**

```zsh
# Erase the disk and create the partitions
systemd-repart \
  --definitions=/tmp/repart.d \
  --dry-run=no \
  --empty=force \
  --discard=no \
  "$d"
```

**Optional Ext4 fast commits:** `fast_commit` is an alternative journaling option. There have been reports of problems with it, so review whether you want it before choosing this variant.

```zsh
# Erase the disk and format root with fast commits
SYSTEMD_REPART_MKFS_OPTIONS_EXT4='-O fast_commit' \
  systemd-repart \
    --definitions=/tmp/repart.d \
    --dry-run=no \
    --empty=force \
    --discard=no \
    "$d"
```

Inspect the resulting filesystems:

```zsh
lsblk -f "$d"
```

If you chose fast commits, look for `fast_commit` in the features and inspect the fast commit length:

```zsh
tune2fs -l /dev/disk/by-label/root | grep features
dumpe2fs -h /dev/disk/by-label/root | grep -i 'Fast commit length'
```

## Step 2: Mount filesystems

Mount root first:

```zsh
# Mount the installed root filesystem
mount /dev/disk/by-label/root /mnt
```

Then create and mount the EFI directory:

```zsh
mkdir -p /mnt/efi
# Mount the EFI partition with restricted access
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

See [why I use these EFI mount options](extra/misc/why-EFI-options.md) for an explanation of the masks and restrictions.

## Step 3: Install the base system

### Choose mirrors

Use nearby countries for the mirror list. My example starts with Norway and its neighbours, then includes Germany and the Netherlands.

On SystemRescue, install Reflector with `pacman --config=/etc/pacman-rolling.conf -S reflector` before this step.

Choose one of these Reflector commands. The expanded form is easier to read:

```zsh
# Rank nearby mirrors and save the mirror list
reflector \
      --country 'Norway,Sweden,Denmark,Germany,Netherlands' \
      --age 12 \
      --protocol https \
      --sort rate \
      --latest 10 \
      --save /etc/pacman.d/mirrorlist
```

The shorter form uses country codes:

```zsh
# Rank nearby mirrors and save the mirror list
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
-l 10 --sort rate --save /etc/pacman.d/mirrorlist
```

Alternatively, allow a longer download timeout when testing mirrors:

```zsh
# Rank nearby mirrors and save the mirror list
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 30 --save /etc/pacman.d/mirrorlist
```

---

### Install the base packages

From the official Arch ISO:

```zsh
# Install the base system from the Arch ISO
pacstrap /mnt base nano sudo
```

From SystemRescue, use this instead:

```zsh
pacstrap -C /etc/pacman-rolling.conf -K /mnt base nano sudo
```

## Step 4: Configure the system

### 4.1 Enter the installed system

```zsh
# Enter the installed system
arch-chroot /mnt
```

Run the following installation commands inside this chroot until the guide tells you to exit it.

---

### 4.2 Create a user account

Install Zsh and Git, set the root password, and create your user. Replace `lars` with your chosen username:

```zsh
# Install Zsh and Git
pacman -S --needed zsh git

# Set the root password
passwd

# Create the user with administrator group membership
useradd -m -G wheel lars
# Set the user password
passwd lars

chsh -s /usr/bin/zsh lars
```

Enable sudo for the `wheel` group:

```zsh
EDITOR=nano visudo
```

In the editor, uncomment `%wheel ALL=(ALL:ALL) ALL`, then save.

---

### 4.3 Install kernels and firmware

Install the main and backup kernels with their headers. The name `linux-zen` refers to desktop tuning, not AMD's Zen CPU architecture.

```zsh
# Install both kernels and their headers
pacman -S --needed linux-zen linux-lts linux-zen-headers linux-lts-headers
```

Choose the firmware command for your CPU. For AMD:

```zsh
# Install firmware and AMD microcode
pacman -S --needed linux-firmware amd-ucode nano sudo systemd-ukify
```

For Intel, use this instead:

```zsh
# Install firmware and Intel microcode
pacman -S --needed linux-firmware intel-ucode nano sudo systemd-ukify
```

#### Optional: Use Dash for sh scripts

I use Dash for `/usr/bin/sh` to reduce shell startup overhead. Scripts that assume Bash features while declaring themselves as `sh` can fail with this change. Skip it if you prefer to keep the existing shell. `checkbashisms` can help identify such scripts.

```zsh
# Install Dash and the shell compatibility checker
pacman -S --needed dash checkbashisms

ln -sfT dash /usr/bin/sh
```

---

### 4.4 Set the timezone

Replace `Europe/Oslo` with your timezone, then set the hardware clock:

```zsh
# Set the system timezone
ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime

# Write system time to the hardware clock
hwclock --systohc
```

---

### 4.5 Configure language and keyboard

My setup uses English for the interface, Norwegian day and month names, a 24-hour clock, and metric measurements. Replace the Norwegian locale with your own regional choice, or leave out those overrides to use the main locale throughout.

Open the locale list:

```zsh
nano /etc/locale.gen
```

Uncomment these entries, substituting your regional locale if needed:

```text
en_US.UTF-8 UTF-8
nb_NO.UTF-8 UTF-8
```

Generate the locales and open the system locale configuration:

```zsh
# Generate the selected locales
locale-gen
nano /etc/locale.conf
```

Contents of `/etc/locale.conf`. `LANG` sets the main language; the other two settings override time and measurement formats:

```ini
LANG=en_US.UTF-8
LC_TIME=nb_NO.UTF-8
LC_MEASUREMENT=nb_NO.UTF-8
```

Set the console keymap and a larger console font:

```zsh
nano /etc/vconsole.conf
```

Contents of `/etc/vconsole.conf`:

```ini
KEYMAP=no-latin1
FONT=ter-118n
```

KDE has its own keyboard configuration. Create it for your user so the desktop starts with the intended layout:

```zsh
mkdir -p /home/lars/.config
nano /home/lars/.config/kxkbrc
```

Contents of `kxkbrc`. Replace `no` with your layout code:

```ini
[Layout]
LayoutList=no
Use=true
VariantList=
```

Save the file, then set its ownership and permissions. Replace both instances of `lars` in the ownership argument as well as the home directory:

```zsh
# Give the user ownership of their configuration
chown -R lars:lars /home/lars/.config
chmod 644 /home/lars/.config/kxkbrc
```

---

### 4.6 Set the hostname

Replace `BigBlue` with the name you want for this computer:

```zsh
# Set the computer hostname
echo "BigBlue" > /etc/hostname
nano /etc/hosts
```

Add these entries to `/etc/hosts`, using the same hostname:

```text
127.0.0.1 localhost BigBlue
::1       localhost
```

---

### 4.7 Install the desktop packages

These lists include KDE Plasma, Dolphin and its plugins, PipeWire audio, fonts, networking, graphics drivers, and supporting tools. Read the [package explanations](extra/misc/pkgchoices.md#essential-packages-included) before installing.

**Privacy choice:** The lists include `pkgstats`, which sends package usage information to Arch Linux. You can omit it and other optional packages. The [package choices guide](extra/misc/pkgchoices.md) explains my reasoning.

Choose **one** package list for your GPU.

#### NVIDIA

```zsh
# Install KDE and the NVIDIA graphics stack
pacman -S --needed \
  networkmanager reflector pkgstats \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  plasma-meta dolphin dolphin-plugins konsole kitty ark unarchiver unrar 7zip kamera \
  kio-admin plasma-login-manager kdegraphics-thumbnailers ffmpegthumbs kdialog \
  tesseract tesseract-data-eng \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver libva-utils cuda vulkan-headers \
  pacman-contrib git wget hunspell hunspell-en_us quota-tools usbutils ttf-roboto \
  noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji terminus-font \
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols zsh-completions \
  base-devel
```

#### AMDGPU

```zsh
# Install KDE and the AMD graphics stack
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
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols ttf-roboto \
  pacman-contrib git wget \
  base-devel
```

#### Intel GPU

I have not verified this setup on my own hardware. Check the package choices for your GPU before using it.

```zsh
# Install KDE and the Intel graphics stack
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
  ttf-dejavu ttf-liberation ttf-nerd-fonts-symbols ttf-roboto \
  hunspell hunspell-en_us quota-tools usbutils \
  pacman-contrib git wget \
  base-devel
```

#### Wi-Fi regulatory database

If you use Wi-Fi, install `wireless-regdb` and set your region. Its regulatory database describes the channels and restrictions for each country. Without a usable database, the conservative world domain can limit available channels. Ethernet-only systems can skip this step.

```zsh
# Install the wireless regulatory database
pacman -S --needed wireless-regdb
nano /etc/conf.d/wireless-regdom
```

Uncomment the entry for your country. For Norway:

```sh
WIRELESS_REGDOM="NO"
```

---

### 4.8 Configure the initramfs

Edit both `MODULES` and `HOOKS` in `/etc/mkinitcpio.conf`:

```zsh
nano /etc/mkinitcpio.conf
```

For NVIDIA, the guide loads these modules early and omits `kms` from the hooks:

```sh
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)
```

For AMDGPU, use `amdgpu` in `MODULES`; the NVIDIA instruction to remove `kms` does not apply.

---

### 4.9 Install UKIs and configure the boot loader

Install systemd-boot. Keep `--variables=yes` so bootctl writes the firmware boot variables from the chroot. Without that override, container detection introduced in systemd 257 can cause that step to be skipped.

```zsh
# Install systemd-boot and its firmware entry
bootctl install --esp-path=/efi --variables=yes
```

#### Kernel command line

`/etc/kernel/cmdline` holds the parameters embedded in the UKIs. This guide also puts root mount options there because it uses GPT discovery instead of a root entry in `fstab`.

```zsh
nano /etc/kernel/cmdline
```

Contents of `/etc/kernel/cmdline`, all on one line:

```text
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=zstd zswap.max_pool_percent=30
```

GPT discovery avoids needing a root filesystem UUID here. Read the [kernel flag explanations](extra/misc/kernelflags.md) before choosing the additional settings.

#### Generate the UKIs

Create the directory and open the kernel-install configuration:

```zsh
mkdir -p /efi/EFI/Linux
```

```zsh
nano /etc/kernel/install.conf
```

Contents of `/etc/kernel/install.conf`:

```ini
layout=uki
```

Install the kernel images:

```zsh
# Generate and install the kernel images
kernel-install add-all
```

Open the boot loader configuration:

```zsh
nano /efi/loader/loader.conf
```

Contents of `/efi/loader/loader.conf`:

```text
timeout 10
console-mode auto
editor no
```

---

### 4.10 Create a swap file

I use Zswap with a swap file rather than Zram. For background on that choice, see [Chris Down's Zswap and Zram comparison](https://chrisdown.name/2026/03/24/zswap-vs-zram-when-to-use-what.html) and [LinuxBlog's discussion of Zswap](https://linuxblog.io/zswap-better-than-zram/).

Create and initialize a 16 GiB swap file. `--file` creates the file with the required allocation and permissions; `-U clear` clears its UUID:

```zsh
# Create and initialize the 16 GiB swap file
mkswap -U clear --size 16G --file /swapfile
```

Create the swap unit:

```zsh
nano /etc/systemd/system/swapfile.swap
```

Contents of `/etc/systemd/system/swapfile.swap`:

```ini
[Unit]
Description=Swap file

[Swap]
What=/swapfile
Priority=100

[Install]
WantedBy=swap.target
```

Enable it for boot:

```zsh
# Enable the swap file at boot
systemctl enable swapfile.swap
```

## Kernel and desktop settings

### Kernel settings

Files in `/etc/sysctl.d/` configure kernel parameters at boot. My settings combine choices from CachyOS and other sources. Read the [settings and their explanations](extra/misc/kernel-settings.md) before applying them.

Clone this repository and copy the configuration:

```zsh
cd /tmp
# Download the tutorial configuration files
git clone https://github.com/larsoyd/ArchLinuxTutorials.git

cd
mkdir -p /etc/sysctl.d/

# Install the supplied kernel settings
cp /tmp/ArchLinuxTutorials/configs/70-settings.conf /etc/sysctl.d/70-settings.conf
```

Load the system's sysctl settings:

```zsh
# Apply the configured kernel parameters
sysctl --system
```

---

### Enable REISUB via sysctl

This optional setting enables the Magic SysRq functions used by REISUB to recover from a frozen system. Read the [REISUB instructions and risks](extra/misc/REISUB.md) before enabling it.

```zsh
nano /etc/sysctl.d/99-sysrq.conf
```

Contents of `/etc/sysctl.d/99-sysrq.conf`:

```conf
kernel.sysrq = 244
```

The value `244` combines keyboard control (`4`), process signals (`64`), filesystem sync (`16`), read-only remounts (`32`), and reboot or power off (`128`).

Apply the settings:

```zsh
# Apply the configured kernel parameters
sysctl --system
```

---

### Udev rules

Udev reacts to device events and processes `.rules` files in filename order. This rule selects I/O schedulers for hard disks, SATA/MMC SSDs, and NVMe SSDs.

Create the directory:

```zsh
mkdir -p /etc/udev/rules.d
```

Choose either **copying the supplied rule**:

```zsh
# Install the disk scheduler rules
cp /tmp/ArchLinuxTutorials/rules.d/60-ioschedulers.rules /etc/udev/rules.d/60-ioschedulers.rules
```

Or **creating it manually**:

```zsh
nano /etc/udev/rules.d/60-ioschedulers.rules
```

For the manual option, use these contents:

```conf
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="mq-deadline"

ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="kyber"
```

See the [optional udev rules](extra/tutorials/udev-rules.md) for other hardware-specific choices.

---

### Module settings

These settings are adapted from CachyOS. Review the [module settings and tradeoffs](extra/misc/kernel-settings.md#module-settings) and choose the files that apply to your hardware.

```zsh
mkdir -p /etc/modprobe.d/
```

For NVIDIA:

```zsh
# Install the NVIDIA module settings
cp /tmp/ArchLinuxTutorials/configs/nvidia.conf /etc/modprobe.d/20-nvidia.conf
```

For AMDGPU, if you want the supplied driver selection settings:

```zsh
# Install the AMDGPU driver selection settings
cp /tmp/ArchLinuxTutorials/configs/amdgpu.conf /etc/modprobe.d/21-amdgpu.conf
```

To apply the watchdog blacklist:

```zsh
# Install the watchdog module blacklist
cp /tmp/ArchLinuxTutorials/configs/blacklist.conf /etc/modprobe.d/22-blacklist.conf
```

---

### Colour emoji fallback

Some applications select monochrome emoji fonts. This configuration adds Noto Color Emoji as an explicit fallback. The package list above includes `noto-fonts-emoji`; update the configuration if you later choose another emoji font.

```zsh
mkdir -p /etc/fonts/conf.d

# Install the colour emoji fallback
cp /tmp/ArchLinuxTutorials/configs/75-noto-color-emoji.conf /etc/fonts/conf.d/75-noto-color-emoji.conf
```

---

### GTK portals

These settings request portal integration for GTK applications on KDE, including file pickers:

```zsh
mkdir -p /etc/environment.d
nano /etc/environment.d/99-portal.conf
```

Contents of `/etc/environment.d/99-portal.conf`:

```ini
GTK_USE_PORTAL=1
GDK_DEBUG=portals
```

---

### Configure systemd-resolved

I use systemd-resolved for its local DNS stub, per-link DNS routing, and split-DNS support for VPNs and multiple networks. It also offers LLMNR, mDNS, DNSSEC controls, and DNS-over-TLS configuration.

Create NetworkManager's configuration:

```zsh
mkdir -p /etc/NetworkManager/conf.d

nano /etc/NetworkManager/conf.d/20-systemd-resolved.conf
```

Contents of `/etc/NetworkManager/conf.d/20-systemd-resolved.conf`:

```ini
[main]
dns=systemd-resolved
rc-manager=auto
```

Enable the resolver:

```zsh
# Enable the DNS resolver at boot
systemctl enable systemd-resolved.service
```

**Complete the resolver symlink step below after leaving the chroot and before unmounting.** Traditional DNS clients need `/etc/resolv.conf` to point to the stub configuration.

## Step 5: Complete the installation

Inside the chroot, enable the services. Include `cups.service` if you use a printer, and `bluetooth.service` if you installed `bluez` and `bluez-utils` for Bluetooth.

```zsh
# Enable desktop services and maintenance timers
systemctl enable NetworkManager plasmalogin systemd-timesyncd systemd-boot-update.service \
fstrim.timer reflector.timer pkgstats.timer
```

Exit the chroot:

```zsh
# Leave the installed system
exit
```

Back in the live environment, create the resolver symlink **before unmounting**:

```zsh
# Connect DNS clients to the local resolver
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
```

Unmount the installed system and shut down:

```zsh
# Unmount the installed system
umount -R /mnt
# Shut down before removing the installation USB
shutdown now
```

Remove the installation USB, then turn the computer back on. You should now be able to boot into Arch and KDE Plasma.

## Troubleshooting

### The panel is missing or on the wrong monitor

1. Right-click the desktop and open **Display Configuration**.
2. Open **Change Screen Priorities** and move your preferred monitor up the list.
3. Apply the change. The panel should move to the primary screen and remain there after rebooting.

I encounter this on my desktop with three monitors. Changing the screen priority has been enough to fix it on that setup.

## Next steps

Continue with the [post-install tutorial](arch_kde_post_tutorial.md) for my preferred desktop settings, applications, and maintenance tools. It is optional, but I recommend reading it even if you only adopt some of the choices.

For boot security and encryption, see the [Secure Boot guide](extra/tutorials/secureboot.md) and [LUKS guide](extra/tutorials/luks.md).
