# OPTIONAL: Post-Install Tutorial

## 1 · Update Base System

```bash
# Bring everything to the latest version
sudo pacman -Syu
```

---

## 2 · Install AUR Helper (yay)

### 2.1 Prerequisites

### Set Kitty as default terminal in KDE:

* Go to System Settings
* Then to Default Applications
* locate "Terminal Emulator"
* Set it to `kitty`

### Clear Konsole Global Shortcut and set it to Kitty instead

* System Settings → Shortcuts → Global Shortcuts → search for `konsole`
* Unbind Konsole from Ctrl+Alt+T
* After you clear its shortcut, hit Apply. 

### Bind Kitty to Ctrl+Alt+T
* While still in Global Shortcuts, click “Add Application,” pick `kitty`, set the shortcut to `Ctrl+Alt+T`, then Apply.
* If a conflict dialog appears, choose to reassign.
* Test it by pressing the shortcut. `kitty` should now launch with it instead of `konsole`

### Launch Kitty

* Either open it with your shortcut, or click the application launcher located on the bottom left of the panel.
* Navigate to the "System" submenu, then locate & launch the program entitled: `kitty`
* Afterwards you can right click on the icon on your Task Manager and pin it for easy access later.

### Essential build tools, you already installed these during install but just to be sure
```bash
sudo pacman -S --needed base-devel git  # when you run pacman with the --needed flag it will skip
                                        # any package that is already on the system.
                                        #
                                        # If you don't do this it will reinstall packages you already have,
                                        # so it's good to just do it by default to be sure.
```

### DISCLAIMER FOR THE AUR:

**NOTE:** Before installing anything other than what is in this tutorial from the AUR, 
**read the PKGBUILD first.**

```md
To do so with `neofetch` for example, go to:
https://aur.archlinux.org/packages/neofetch
and click on the hyperlink that says "PKGBUILD"

LLMs can help in parsing them if you are new, but *try* to learn how to read them without it.
What you are looking out for are malicious links or anything else out of the ordinary.
```

### Build and install yay
```bash
cd /tmp                                      # go to the temporary directory
git clone https://aur.archlinux.org/yay.git  # clone the yay pkgbuild from the aur
cd yay                                       # enter the cloned folder
makepkg -si                                  # build the package, then install it and deps
cd ~ && rm -rf /tmp/yay                      # go home, remove the temporary build folder

yay --version  # quick test | NOTE: Whenever you run any 'yay' command, do not use 'sudo' before it.
```

### Shell and terminal bliss
```bash
# Oh-my-zsh makes your terminal nicer, zsh-autosuggestions and the other are plugins
# More on them later.
yay -S --needed oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
```

### Copy .zshrc default template config

```bash
# This makes it so you don't have to write out a buncha crap
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
```

### Configure ~/.zshrc

```bash
# Tip: You can press F12 to insert the letter ~ into the terminal
# This avoids having to spider-man hand ALT + whatever to write it
#
nano ~/.zshrc

# Scroll to the bottom, add these two lines to the bottom:
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# also add this under the two lines to turn on autocomplete
autoload -Uz compinit
compinit

# You are also going to want to set your name in PROMPT, otherwise it will just be `~`
# The "PROMPT" below will look like this: [ArchLars], with Arch in Arch blue and Lars in white, same with brackets.
# The ~ will be in cyan, which is your working directory.
# This is a fine early profile name, you can make it nicer later.
#
# Replace "Lars" with your own name and add this to the very bottom of ~/.zshrc:
#
PROMPT='%F{white}%B[%F{#1793d1}Arch%F{white}Lars%F{white}] %F{cyan}%~ %f%(!.#.$) '

# Also optionally add any aliases here
#
# Here is one for installing packages:
alias pacin='yay -S --needed'
#
# with this you can just write 'pacin' and then package to install anything
# Example: pacin firefox
```

### Reload & Guide
```bash
# Then reload zshrc like so:
source ~/.zshrc
```
#### TERMINAL USAGE GUIDE w/ AUTOSUGGESTIONS AND SYNTAX HIGHLIGHTING:

- Right arrow: accept a suggestion to autocomplete a command you've run before. 

- Up arrow: recall a previous command that starts the same way. 
For example, type 'sudo', then press Up, and it fills in the rest. 
This is useful when installing packages, like you will in this tutorial.
Every time you type 'yay', you can press Up to autofill your usual flags, 
then replace the package name with something else.

- Syntax highlighting makes commands easier to read, and helps you spot obvious mistakes.

## 3 · System Optimisation

### 3.1 Pacman candy
Edit `/etc/pacman.conf`:
```bash
sudo nano /etc/pacman.conf
```
```ini
# Color adds color (duh),
# To add it you need to "Uncomment" the setting,
# what this means is removing the #'s in front of it.
# whenever I say to uncomment in the future that is what that means btw.
#
# ILoveCandy is a fun setting that adds animations to when you update pacman.
Color                      # uncomment
ILoveCandy                 # write this manually under Color
```

### Enable syntax highlighting in nano
```bash
# This command `mkdir -p` is essentially, "if it doesnt exist, create it + w/ the subfolder"
# If it already exists it will skip the action, it doesn't overwrite the folder that's there
# This is a good way to prevent issues where you try to make a file in a folder that dont exist.
#
mkdir -p ~/.config/nano

# package with enhanced rules
yay -S --needed nano-syntax-highlighting

# enable all bundled syntaxes
# paste into terminal with CTRL + SHIFT + V:
printf 'include "/usr/share/nano/*.nanorc"\ninclude "/usr/share/nano/extra/*.nanorc"\n' >> ~/.config/nano/nanorc
echo 'include "/usr/share/nano-syntax-highlighting/*.nanorc"' >> ~/.config/nano/nanorc

# enable it system wide
# paste into terminal with CTRL + SHIFT + V:
sudo tee -a /etc/nanorc >/dev/null <<'EOF'
include "/usr/share/nano/*.nanorc"
include "/usr/share/nano/extra/*.nanorc"
include "/usr/share/nano-syntax-highlighting/*.nanorc"
EOF
```
### Turn off that incessant beeping in kitty without doing it system wide.
```bash
# You can turn this off system wide in KDE settings, but that is a bit overkill.
nano ~/.config/kitty/kitty.conf

# Add these lines
# to bottom of file:
enable_audio_bell no
visual_bell_duration 0
window_alert_on_bell no
bell_on_tab none

# reload the config
CTRL + SHIFT + F5

# Test that the violation of the Geneva Convention is gone.
# Printing '\a' should send the BEL character which triggers it if not.
printf '%b' '\a'
```

### Show asterisks when typing your sudo password
Use `visudo` and add the `pwfeedback` default. This is the safe way to edit sudoers.
```bash
# open a drop-in with visudo
sudo EDITOR=/usr/bin/nano visudo -f /etc/sudoers.d/pwfeedback

# add exactly this line, then save and exit
Defaults pwfeedback

# test by forcing a fresh prompt
sudo -k
sudo true
```
### Persist configure X11 keymap for non-normative U.S keyboards

```bash
# If you are using a non-normative U.S keyboard like me,
# it's worth setting the default keymap for X11 sessions.
#
# If it doesn't exist, create directory
sudo mkdir -p /etc/X11/xorg.conf.d

# even if you dont use x11 it's good to set this just in case
# ignore if you dont use a weird keyboard (non US one = weird)
sudo tee /etc/X11/xorg.conf.d/00-keyboard.conf >/dev/null <<'EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "no"
    Option "XkbModel" "pc105"
EndSection
EOF
```
### Install Basic packages:

```bash
# essential stuff to have.
yay -S --needed informant \
gst-libav gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly \
systemd-timer-notify rebuild-detector aurutils \
python-pip kdeconnect journalctl-desktop-notification

# add yourself to group informant
sudo usermod -aG informant $USER

# then log out and back in and confirm you are in that group by running:
groups

# browser
yay -S --needed firefox

# or anything else
yay -S --needed chromium   # example of "anything else"
```

### Fixing Firefox:

These optional knobs are only if the GDK portal we set up in the install itself didn't work.
Sometimes after install Firefox looks odd, some buttons are off and incorrect. 
The technical reason is a bit out of scope for this tutorial, but essentially it thinks that it is
in another desktop environment. Portals are supposed to fix that, but if they don't you can try these
fixes:

#### (Optional) - Force Firefox to use Dolphin
```bash
# Optional if needed. GDK_DEBUG=portals set earlier should have done it.
# If not, force Firefox to do it, open about:config and set:
widget.use-xdg-desktop-portal.file-picker → 1 (always)
```

#### (Optional) - Add all buttons to Firefox
```bash
# Sometimes Firefox does not have the minimize and maximize buttons
# You can try this remedy:
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
# Then log out and back in

# If that still doesn't work, then try:
yay -S --needed xdg-desktop-portal-gtk
```

### Configuring Firefox:

#### Make Firefox follow your KDE default apps via mimeapps.list on Arch.
```bash
# create if not already created
mkdir -p ~/.local/share/applications

# backup if a real file already exists
[ -f ~/.local/share/applications/mimeapps.list ] && \
  mv ~/.local/share/applications/mimeapps.list ~/.local/share/applications/mimeapps.list.bak

# symlink
ln -sf ~/.config/mimeapps.list ~/.local/share/applications/mimeapps.list
```
#### Add VA-API to Firefox (GPU accelerated video)
```bash
# Confirm VA-API support
vainfo

# Open up about:config and set:
media.hardware-video-decoding.force-enabled → true
```

#### Ensure Firefox media keys dont conflict with Plasma
```bash
# open about:config and set
media.hardwaremediakeys.enabled → false
```

---

## 4 · Essential security and quality of life

### 4.0 Firmware Updates
```bash
# You are going to need to update your firmware
# To do this install fwupd and start the service
sudo pacman -S ---needed fwupd
sudo systemctl start --now fwupd.service

# Sidenote: topgrade which I will talk about later can do all the get updates and install steps for you
# If you are going to use it, you can skip the manual steps below.
#
# If you wish to do it manually:
# First display all devices detected by fwupd
$ fwupdmgr get-devices

# To download the latest metadata from the Linux Vendor firmware Service (LVFS): 
$ fwupdmgr refresh

# To list updates available for any devices on the system: 
$ fwupdmgr get-updates

# To install updates:
$ fwupdmgr update

```

### 4.1 Firewall
```bash
sudo pacman -S --needed firewalld python-pyqt6
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --zone=public --add-service=kdeconnect
sudo firewall-cmd --reload
```

### 4.2 Enable multilib for 32-bit support (pre-Steam)

```bash
# to enable 32-bit support you need to uncomment
# a new repository, essentially add it and then update system.
sudo nano /etc/pacman.conf
```

Uncomment in `/etc/pacman.conf`:
```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```
Update your system to include multilib:

Option 1) Topgrade - Update everything on your system with one command! :
```bash
# Topgrade is an optional but super quality of life package
# With one command of `topgrade` you can upgrade all your packages of any type on your entire system...
# That is *all* your packages, including flatpaks, sys packages like the kernel, AUR, Rust crate, etc.
# It also shows available firmware to upgrade. It is so helpful that even though its a bit out there...
# ... I still think it's essential for QoL on any Arch system.
# If you think this sounds neat then I strongly reccomend it.
#
yay -S --needed topgrade-bin

# If you want you can add an alias to topgrade
# so that you better remember it and it fits more
# in line with the other commands that start with "pac".
# First edit:
nano ~/.zshrc

# Then add this to the bottom:
alias pacup='topgrade'

# Save and exit, then reload zshrc like so:
source ~/.zshrc

# Then either write + press enter:
pacup

# or if you didn't add the alias:
topgrade
```

Option 2) with yay:
```bash
# Tip/Fun Fact: You can update your system by just writing 'yay'.
# This is actually ideal, as pacman -Syu does not update your AUR packages.
# Try it:
yay

# This is a good time to teach you the habit of running `checkrebuild` after updates.
# 'checkrebuild' checks if you need to rebuild any packages towards new dependencies.
#
# If you don't do that when needed, it can lead to instability.
checkrebuild

# usually it doesn't list anything, that means you're good, but if it does you need to run
# yay  -S <pkg> --rebuild
```

### 4.2.5 Steam & 32-bit Libraries
```bash
# then after enabling multilib DL Steam 
yay -S --needed steam

# Run Steam in terminal to install it:
steam

# OPTIONAL: Consider also getting the 32-bit versions of GStreamer plugins.
# This gives you support for a number of audio & video formats on 32-bit software.
#
# For gaming on Proton it is NOT vital, Proton and ProtonGE bundle their own GStreamer, but
# for any other 32-bit application like say if you want to run WINE yourself for stuff
# then they are vital to not get issues with playback with MP3 for example through Windows software.
#
# NOTE: lib32-gst-plugins-ugly, lib32-gst-libav & lib32-gst-plugins-bad are from the AUR
# which means they are packaged by a third party.
# Check the PKGBUILD of both before installing or leave them out. But if you do be aware
# that lib32-*-ugly is required for MP3 on 32-bit apps. WINE generally reccomends you get *-bad and *-libav.
yay -S --needed lib32-gst-plugins-base lib32-gst-plugins-good lib32-gst-plugins-ugly lib32-gst-plugins-bad lib32-gst-libav
```

### 4.2.6 plocate - Quickly find any file or folder on your Arch Linux system
```bash
# To quickly learn how to find steamapps for example without googling you can use plocate
# It's the fastest way to find any file or folder on your system, first install plocate:
yay -S --needed plocate

# Then build the database:
sudo updatedb

# And finally write a command like so to find steamapps for example:
locate -b '\steamapps'   # instant results

# You may also want to enable the daily systemd timer to update the database automatically:
sudo systemctl start --now plocate-updatedb.timer
```

### ProtonUp-Qt:
```bash
# install protonup qt (ProtonGE)
yay -S --needed protonup-qt
```

### Configure Proton GE as the default in Steam after installing Proton GE from ProtonUp-Qt:

0. Open up ProtonUp-Qt and install the latest version of Proton GE
1. Launch Steam and open **Settings → Compatibility**.  
2. In the dropdown, choose **Proton GE**.  
3. Click OK and restart Steam.

ProtonGE is a good default for a lot of games, works just as well as regular Proton for most games and for other games include 
propietary codecs and such that Valve cannot package themselves, this helps with video files and music with odd formats.



---

## 5 · Maintenance hooks
```bash
# these hooks are great for system maintenance
#
# pacdiff shows you if any .pacnew is on your system needed to merge
#
# reflector will run reflector any time mirrorlist updates
#
# paccache-hook is the GOAT. it cleans your cache after using pacman.
yay -S --needed \
  pacdiff-pacman-hook-git \
  reflector-pacman-hook-git \
  paccache-hook
```

### Install & Enable Nohang:
```bash
# This is an OOM killer. DON'T SKIP. It's VITAL.
yay -S --needed nohang-git 

# Reason why it's vital is this:
# If your system fills up it's swap and RAM then this will terminate offending processes before your system freeze up.
# So if you don't have this your computer will just freeze if you are unlucky and this happens to you for w/e reason.
sudo systemctl enable --now nohang-desktop.service
```

### Set Journalctl limit:
```bash
# SUPER important, DO NOT SKIP. The journal on desktop use fills up very quickly which takes space
# a large one can slow down boot times after a while.
sudo mkdir -p /etc/systemd/journald.conf.d
sudo nano /etc/systemd/journald.conf.d/00-journal-size.conf
```
```ini
[Journal]
SystemMaxUse=50M
```

### USB autosuspend
The Linux kernel automatically suspend USB devices when they are not in use. 
This can sometimes save quite a bit of power, however some USB devices are not compatible with USB power saving and start to misbehave (common for USB mice/keyboards). Some keyboards and mice
will "fall asleep" and there will be some latency after idle. This is enough to drive you crazy if you don't know what's going on.

udev rules based on whitelist or blacklist filtering can help to mitigate the problem. ATTR{power/control}="on" disables runtime autosuspend for the matched devices; "auto" enables it for all others.  

#### RECCOMENDED OPTION A) The example is enabling autosuspend for all USB devices except for keyboards and mice: 

Try this before you do Option B, it's simpler
and it is the reccomended way to do it on the ArchWiki:

```bash
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```
```bash
ACTION=="add", SUBSYSTEM=="usb", ATTR{product}!="*Mouse", ATTR{product}!="*Keyboard", TEST=="power/control", ATTR{power/control}="auto"
```

#### ADVANCED OPTION B) More specific exemptions based on Base Classes:

You can make it more specific like so if you know what you are doing and Option A did not work.
Often the reason why Option A don't work is due to the mouse and keyboard having a name without
advertising their function ("Keyboard" and "Mouse").

The HEX codes should be correct according to the Official USB-IF Class Code Specifications. 
They represent a specific hierarchy of device identification: 

03: The Base Class for HID (Human Interface Device).
01: The Subclass code for Boot Interface, indicating the device supports the simplified "boot" communication mode.
01 or 02: The Protocol code, where 01 is for Keyboard and 02 is for Mouse.

```bash
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```
```bash
# Default: enable autosuspend on USB devices
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTR{power/control}="auto"

# Keep HID boot keyboard (030101) and mouse (030102) awake
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030101:*", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030102:*", ATTR{power/control}="on"
```

Apply and retrigger, then recheck:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add

# Check to see if either approach worked:
grep -H . /sys/bus/usb/devices/*/power/{control,runtime_status}
```

## YT-DLP and aliases I use with it:

YT-DLP is a downloader for online media hosted on sites. It's very good.

Install:
```bash
yay -S --needed yt-dlp
```

#### OPTIONAL QoL FOR YT-DLP:

- Here are some aliases I use, add to `~/.zshrc` with `nano` on the bottom:

```bash
alias ytdla='yt-dlp -f bestaudio \
                 --extract-audio \
                 --audio-format mp3 \
                 -o "/home/$USER/Music/%(title)s.%(ext)s"'

alias ytdlv='yt-dlp -f bestvideo+bestaudio \
    --merge-output-format mkv \
    -o "$HOME/Videos/%(title)s.%(ext)s"'
```

Save and then run: `source ~/.zshrc`

#### How to use:

ytdla downloads audio, ytdlv downloads video and places them in appropriate folders with names.
You simply write either of these and a link. 

- Here is a script I made that makes clipping videos easier.

```bash
mkdir -p /home/$USER/bin/
nano /home/$USER/bin/ytclip
```

Add this script:
```bash                             
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: ytclip <url> <start> - <end> [best|360p|720p|1080p]"
  echo "Examples:"
  echo "  ytclip 'www.example.fake' 3:51 - 3:54 360p"
  echo "  ytclip 'www.example.fake' 00:03:51 - 00:03:54 best"
  exit 1
}

command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp not found"; exit 2; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found"; exit 2; }

[[ $# -lt 4 ]] && usage

URL="$1"
# Support either "<start> - <end>" or "<start>-<end>"
if [[ "${3:-}" == "-" ]]; then
  START="$2"
  END="$4"
  QUALITY="${5:-best}"
elif [[ "$2" == *"-"* && -n "${3:-}" ]]; then
  IFS='-' read -r START END <<<"$2"
  START="$(echo "$START" | tr -d ' ')"
  END="$(echo "$END" | tr -d ' ')"
  QUALITY="${3:-best}"
else
  # Fallback: <url> <start> <end> [quality]
  START="$2"
  END="$3"
  QUALITY="${4:-best}"
fi

# Normalise quality label
QUALITY="$(echo "$QUALITY" | tr '[:upper:]' '[:lower:]')"

# Map quality to a yt-dlp format selector.
# Height filters use official format selection syntax.
case "$QUALITY" in
  best)
    FMT='bv*+ba/best'
    ;;
  360p)
    FMT='bv*[height<=360]+ba/b[height<=360]'
    ;;
  720p)
    FMT='bv*[height<=720]+ba/b[height<=720]'
    ;;
  1080p)
    FMT='bv*[height<=1080]+ba/b[height<=1080]'
    ;;
  *)
    echo "Unknown quality: $QUALITY"
    usage
    ;;
esac

# Prefer broadly compatible outputs and containers.
# -S sorts formats to prefer h264+aac and mp4 where possible.
SORT_PREF='res,codec:av1:vp9:h264,ext'

# Safe tags for filename (turn 3:51 into 3m51s)
start_tag="${START//:/m}s"
end_tag="${END//:/m}s"

# Perform frame-accurate clipping by forcing keyframes at cuts.
# This re-encodes the segment for accuracy.
exec yt-dlp "$URL" \
  -f "$FMT" -S "$SORT_PREF" --merge-output-format mp4/mkv \
  --download-sections "*${START}-${END}" --force-keyframes-at-cuts \
  -o "%(id)s_${start_tag}_${end_tag}.%(ext)s"
  ```

#### How to use:

```bash
ytclip <url> <start> - <end> [best|360p|720p|1080p]
Examples:
  ytclip '(link)' 3:51 - 3:54 360p
  ytclip '(link)' 00:03:51 - 00:03:54 best
```

#### DISCLAIMER: I do not condone breaking site ToS with this tool, nor any other form of piracy.


## Video Playback

My advice is pick one here, you can do both but it's best to not clutter your system.

### Option 1) VLC

#### VLC Install:
```bash
# VLC is the only officially supported third-party player with official Phonon support on KDE.
# It's more fully featured than MPV, MPV requires more manual config to look better.
#
# install vlc (video)
yay -S --needed vlc vlc-plugins-all

# Hardware Acceleration:
## VLC automatically tries to use an available API
## You can override it by going to Tools > Preferences > Input & Codecs.
## Choose the suitable option under Hardware-accelerated decoding,

# Phonon backend (for integration within KDE):
yay -S --needed phonon-qt6-vlc

# OPTIONAL: Plugin to allow you to click on the video inside VLC's window
# and it will be paused or resumed. This is a commonly expected behavior:
yay -S --needed vlc-pause-click-plugin
```

### Option 2) MPV
#### MPV Install:
```bash
# Has become more popular in recent years, is very powerful but a bit nerdy
# If you care about manual configs and stuff use MPV, otherwise use VLC
#
# install mpv (video)
yay -S --needed mpv  

# (Third-party) Phonon Support for mpv
yay -S --needed phonon-qt6-mpv

# You have to do this if you want GPU acceleration for your wholesome entertainment
mkdir -p ~/.config/mpv
echo "hwdec=auto" > ~/.config/mpv/mpv.conf
```

## Final Reboot

#### Reboot again into new system and you can finally sit back, relax, and use arch btw

```bash
# before reboot it's worth learning how to find all orphaned packages
# (those that were installed as dependencies but are no longer needed by anything),
# and completely remove them, including their configuration files and any now-unused dependencies.
#
# This keeps your system without lingering dependencies you aren't using. Try to run it periodically:
sudo pacman -Rns $(pacman -Qtdq)

# reboot
reboot

# after reboot open kitty (CTRL + ALT + T)
yay -S --needed fastfetch

# Then run it to see your glorious fetch
fastfetch

# press prt scr to take a desktop photo
# save it
```

# EXTRA TUTORIAL: How to add a new Drive/SSD to GPT-Auto Setups


- Name of drive will be `data`, 
- Replace ALL instances of `data` in this guide if you don't want that name for your drive.
- And by all I mean ALL instances, even in the .mount & .automount files

#### 0) Identify the new disk (double check before you write to it)
```bash
lsblk -e7 -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL
DEV=/dev/nvme1n1    # <-- set this to your new disk
```
#### 1) Create a GPT partition and give it a PARTLABEL
```bash
#    WARNING: the zap step is destructive. Save data on disk first.
sudo sgdisk --zap-all "$DEV"
sudo sgdisk -n1:0:0 -t1:8300 -c1:"data" "$DEV"   # one Linux partition named "data"
```
#### 2) Make a filesystem (example: ext4)
```bash
sudo mkfs.ext4 -L data "${DEV}p1"   # remove p like in install if ur disk is 'sda' and not nvme
```
#### 3) Verify the persistent symlink created by udev, then wait if needed
```bash
ls -l /dev/disk/by-partlabel/ | grep ' data$' || true
sudo udevadm settle
```
#### 4) Create the mount point
```bash
sudo mkdir -p /mnt/data
```
#### 5) Create a native systemd mount unit
```bash
sudo nano /etc/systemd/system/mnt-data.mount

# add
[Unit]
Description=Data SSD via PARTLABEL

[Mount]
What=/dev/disk/by-partlabel/data
Where=/mnt/data
Type=ext4
Options=noatime

[Install]
WantedBy=multi-user.target
```
#### Create an automount for on-demand mounting
```bash
sudo nano /etc/systemd/system/mnt-data.automount

# add
[Unit]
Description=Auto-mount /mnt/data

[Automount]
Where=/mnt/data

[Install]
WantedBy=multi-user.target
```
#### 6) Enable it
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-data.automount
```
#### 7) Test
```bash
systemctl status mnt-data.automount
df -h /mnt/data
touch /mnt/data/it-works
```

# NVIDIA GSP ISSUES - TUTORIAL (2025)

As of now there is an issue on Wayland with NVIDIA where the power state goes down too low on idle which causes lag and a jump during various use like desktop animations etc. The only solution for this is to either turn off GSP which you need the propietary driver to do (i.e not open kernel modules) or set minimum and max clocks so it doesn't enter that idle state. This is how to do the latter with a systemd service I wrote for it. There are trade offs to this obv, but I have done it as safe as possible by locking the VRAM clocks to a valid safe range chosen from the device’s supported table.

### 0) confirm driver + tool exist
```bash
nvidia-smi || { echo "nvidia-smi not found or driver not loaded"; exit 1; }

# try idling a bit in firefox wait 5 seconds then scroll
# you will see a noticable jump or lag when doing so, esp on 4k.

# try it again and this time run this in another monitor on a terminal:
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1

# you will see the jump happens from when the clocks readjust from a very low point
```

### 1) create the clock-locking script
```bash
# to solve this we will set minimum clock speed
# what it does: installs /usr/local/sbin/lock-nvidia-mem.sh with a safe, dynamic min/max picker
sudo nano /usr/local/sbin/lock-nvidia-mem.sh
```

```bash
# ----- /usr/local/sbin/lock-nvidia-mem.sh -----
#!/usr/bin/env bash
set -euo pipefail

GPU=${GPU:-0}
PCT=${PCT:-0.70}   # 0..1 percentile anchor
# piecewise β parameters (MHz breakpoints and targets)
B1=${B1:-5000};  B2=${B2:-10000}; B3=${B3:-15000}
V1=${V1:-0.60};  V2=${V2:-0.75};  V3=${V3:-0.80}

SUDO=""; (( EUID != 0 )) && SUDO="sudo"

# Supported memory clocks (MHz), ascending unique
mapfile -t S < <(nvidia-smi -i "$GPU" \
  --query-supported-clocks=memory --format=csv,noheader,nounits \
  | tr -d ' ' | sort -nu)
((${#S[@]})) || { echo "no supported clocks for GPU $GPU"; exit 1; }

MAX="${S[-1]}"

beta() { # β(MAX) piecewise-linear
  local m="$1"
  if   (( m <= B1 )); then
    awk -v v="$V1" 'BEGIN{print v}'
  elif (( m <= B2 )); then
    awk -v v1="$V1" -v v2="$V2" -v m="$m" -v b1="$B1" -v b2="$B2" \
      'BEGIN{print v1 + (v2-v1)*(m-b1)/(b2-b1)}'
  elif (( m <= B3 )); then
    awk -v v2="$V2" -v v3="$V3" -v m="$m" -v b2="$B2" -v b3="$B3" \
      'BEGIN{print v2 + (v3-v2)*(m-b2)/(b3-b2)}'
  else
    awk -v v="$V3" 'BEGIN{print v}'
  fi
}

# snap helper: largest supported ≤ target
pick_le() { awk -v t="$1" '$1<=t{m=$1} END{if(m)print m}'; }

# 1) Percentile anchor within supported set
k=${#S[@]}
q=$(awk -v p="$PCT" -v k="$k" 'BEGIN{printf("%d",(p*k==int(p*k)?p*k:(int(p*k)+1)))}')
(( q<1 )) && q=1
(( q>k )) && q=k
S_Q="${S[$((q-1))]}"

# 2) Fractional floor from β(MAX)
BETA=$(beta "$MAX")
TGT=$(awk -v b="$BETA" -v m="$MAX" 'BEGIN{printf("%.0f", b*m)}')
S_F="$(printf "%s\n" "${S[@]}" | pick_le "$TGT")"
[[ -n "$S_F" ]] || S_F="${S[0]}"

# 3) Final MIN = max(percentile anchor, fractional floor)
MIN="$S_Q"; (( S_F > MIN )) && MIN="$S_F"; (( MIN > MAX )) && MIN="$MAX"

echo "GPU=$GPU k=${#S[@]} MIN=$MIN MAX=$MAX (percentile=${PCT}, beta=${BETA})"

# Lock memory clocks and enable persistence
if ! $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks="$MIN","$MAX"; then
  $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks-deferred="$MIN" || true
fi
$SUDO nvidia-smi -i "$GPU" -pm 1
```

### 2) make it executable
```bash
# what it does: sets correct mode so systemd can run it
sudo chmod 755 /usr/local/sbin/lock-nvidia-mem.sh
```

### 3) create env overrides
```bash
# what it does: lets you change GPU/PCT/B1..B3/V1..V3 without editing the script
sudo nano /etc/default/nvidia-lock
```

```bash
# ----- /etc/default/nvidia-lock -----
# GPU index and percentile
GPU=0
PCT=0.70
# MHz breakpoints
B1=5000
B2=10000
B3=15000
# β targets
V1=0.60
V2=0.75
V3=0.80
```

### 4) create a systemd unit
```bash
# what it does: runs the lock at boot and keeps state via persistence
sudo nano /etc/systemd/system/nvidia-lock.service
```
```bash
# ----- /etc/systemd/system/nvidia-lock.service -----
[Unit]
Description=Lock NVIDIA memory clocks and enable persistence
Wants=nvidia-persistenced.service
After=multi-user.target nvidia-persistenced.service

[Service]
Type=oneshot
EnvironmentFile=-/etc/default/nvidia-lock
ExecStart=/usr/local/sbin/lock-nvidia-mem.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

### 5) enable NVIDIA persistence daemon
```bash
# what it does: keeps GPU initialized so your lock survives idle periods
sudo systemctl enable --now nvidia-persistenced.service
```
### 6) reload units and enable our service
```bash
# what it does: starts clock lock at boot and immediately
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-lock.service
```
### 7) verify supported clocks + current locks
```bash
# what it does: shows supported memory clocks and the lock status
nvidia-smi -i "${GPU:-0}" -q -d SUPPORTED_CLOCKS | head -n 60
nvidia-smi -i "${GPU:-0}" -q -d CLOCK | head -n 80
```
### 8) test run manually (optional)
```bash
# what it does: prints chosen MIN/MAX and applies lock interactively
sudo /usr/local/sbin/lock-nvidia-mem.sh

# now test again with the script from step 0 and see the difference
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1

# this also allows you to keep an eye on temps and power.
```

---
