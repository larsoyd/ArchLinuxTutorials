# KDE Plasma post-install tutorial

This guide covers my preferred applications, desktop settings, and maintenance tools after installing Arch. The choices are opinionated: read each section and keep what suits your system. Start with the [optional KDE preferences](extra/misc/misc.md) if you want to change session restoration, cursor effects, or volume feedback.

Run terminal commands as your normal desktop user. Commands that need administrator access use `sudo`. Configuration examples belong in the named file; they are not commands to paste into the terminal.

## Contents

- [1. Chaotic-AUR](#1-chaotic-aur)
- [2. Terminal and AUR setup](#2-terminal-and-aur-setup)
- [3. Desktop and application settings](#3-desktop-and-application-settings)
- [4. Firmware, security, and gaming](#4-firmware-security-and-gaming)
- [5. Maintenance](#5-maintenance)
- [6. Keyboard and USB settings](#6-keyboard-and-usb-settings)
- [7. Media tools](#7-media-tools)
- [8. Optional display and hardware tweaks](#8-optional-display-and-hardware-tweaks)
- [Finish](#finish)

## 1. Chaotic-AUR

Chaotic-AUR provides prebuilt packages from the AUR, saving local compilation time. I recommend it for convenience, but it is optional. Installing prebuilt packages means trusting that repository and its build process; it does not replace reviewing what you install.

Open Kitty from the application launcher under **System**. If Zsh asks about an initial configuration, choose an empty `.zshrc` for now. We will configure it below. Paste terminal commands with Ctrl+Shift+V.

Import and locally sign the repository key, then install the keyring and mirror list:

```zsh
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
```

Open pacman's configuration:

```zsh
sudo nano /etc/pacman.conf
```

Add this at the end of `/etc/pacman.conf`:

```ini
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
```

Update the system and populate the package file databases. Repeat the file database update when adding another repository:

```zsh
sudo pacman -Syu

sudo pacman -Fy
```

## 2. Terminal and AUR setup

### Configure Kitty

In **System Settings → Default Applications**, set **Terminal Emulator** to Kitty.

To launch it with Ctrl+Alt+T:

1. Open **System Settings → Shortcuts → Global Shortcuts** and find Konsole.
2. Remove Konsole's Ctrl+Alt+T shortcut and apply the change.
3. Choose **Add Application**, select Kitty, and assign Ctrl+Alt+T.
4. Apply and test the shortcut. You can also pin Kitty to the task manager.

#### Optional copy and paste shortcuts

Add these bindings to `~/.config/kitty/kitty.conf` if you prefer Ctrl+C and Ctrl+V for copying and pasting. Ctrl+C copies a selection or interrupts when nothing is selected; Ctrl+Shift+C sends the interrupt character explicitly.

```conf
map ctrl+shift+v no_op
map ctrl+v paste_from_clipboard

map ctrl+shift+c no_op
map ctrl+c copy_and_clear_or_interrupt
map ctrl+shift+c send_text all \x03
```

#### Optional zoom shortcuts

To use Ctrl+Plus and Ctrl+Minus without Shift, add:

```conf
map ctrl+plus change_font_size all +2.0
map ctrl+equal change_font_size all +2.0
map ctrl+kp_add change_font_size all +2.0

map ctrl+minus change_font_size all -2.0
map ctrl+kp_subtract change_font_size all -2.0

map ctrl+shift+plus no_op
map ctrl+shift+equal no_op
map ctrl+shift+kp_add no_op

map ctrl+shift+minus no_op
map ctrl+shift+kp_subtract no_op
```

#### Font size and remote control

These are my settings for a larger font and remote control. Add them to `~/.config/kitty/kitty.conf` if wanted:

```conf
allow_remote_control yes

font_size 18
```

Reload Kitty's configuration with Ctrl+Shift+F5.

### Build tools and compiler caches

Make sure the basic build tools are installed. `--needed` skips packages that are already up to date:

```zsh
sudo pacman -S --needed base-devel git
```

My build setup uses ccache and sccache for compiler caching, mold for linking, and rustup for the Rust toolchain. It enables local CPU optimizations and link-time optimization where supported while retaining the other existing compiler flags.

These settings affect software you compile locally, including AUR packages. They do not change prebuilt repository packages. Binaries built with `native` CPU settings may not run on other CPUs, so do not use this configuration for builds you intend to distribute without reviewing it.

```zsh
sudo pacman -S --needed ccache mold rustup sccache

rustup default stable

mkdir -p ~/.config/ccache/
mkdir -p ~/.cargo
```

Open the ccache configuration:

```zsh
nano ~/.config/ccache/ccache.conf
```

Contents of `~/.config/ccache/ccache.conf`:

```conf
cache_dir = $HOME/.cache/ccache
max_size  = 30G
```

Open Cargo's configuration:

```zsh
nano ~/.cargo/config.toml
```

Contents of `~/.cargo/config.toml`:

```toml
[build]
rustc-wrapper = "sccache"

[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "target-cpu=native", "-C", "link-arg=-fuse-ld=mold"]
```

Create a makepkg drop-in for Rust builds:

```zsh
sudo mkdir -p /etc/makepkg.conf.d
sudo nano /etc/makepkg.conf.d/rust.conf
```

Contents of `/etc/makepkg.conf.d/rust.conf`:

```sh
RUSTFLAGS="-C link-arg=-fuse-ld=mold -C target-cpu=native"
```

For the user makepkg configuration, choose **one** method.

**Copy the supplied file:** if the repository is already cloned at `/tmp/ArchLinuxTutorials`, skip the clone command.

```zsh
cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials
cp /tmp/ArchLinuxTutorials/configs/makepkg.conf ~/.makepkg.conf
cd
```

**Or create it manually:**

```zsh
nano ~/.makepkg.conf
```

Contents of `~/.makepkg.conf`. This enables compiler caching and mold, disables debug packages, and configures parallel builds:

```sh
CFLAGS="${CFLAGS/-march=x86-64-v4/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64-v3/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64-v2/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64/-march=native}"

CXXFLAGS="${CXXFLAGS/-march=x86-64-v4/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64-v3/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64-v2/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64/-march=native}"

OPTIONS=("${OPTIONS[@]/!lto/lto}")

OPTIONS+=(!debug)

BUILDENV=("${BUILDENV[@]/!ccache/ccache}")

LDFLAGS+=" -fuse-ld=mold"

MAKEFLAGS="-j$(nproc)"
```

### Review AUR packages

Read the `PKGBUILD` before installing an AUR package. On an AUR package page, such as the [neofetch page](https://aur.archlinux.org/packages/neofetch), follow the **PKGBUILD** link. Check its sources and build commands for anything unexpected. An LLM can help explain the file, but learning to read it yourself is useful.

### Install Pikaur

Pikaur is my preferred AUR helper because it shows PKGBUILDs with syntax highlighting during installation and updates. Use another helper if you prefer, but the examples below use Pikaur. Run `pikaur` as your normal user, without a `sudo` prefix.

Choose **one** installation method.

**From Chaotic-AUR:**

```zsh
sudo pacman -S --needed pikaur-git
```

**Or build from the AUR:**

```zsh
cd /tmp
git clone https://aur.archlinux.org/pikaur.git
cd pikaur
makepkg -si
cd ~ && rm -rf /tmp/pikaur
```

Check the installed version:

```zsh
pikaur --version
```

### Clean the Pikaur package cache

Pikaur stores built packages in `~/.cache/pikaur/pkg`. Its example pacman hook uses `paccache` from `pacman-contrib` to remove old cached versions after package transactions.

Install the dependency and copy the hook. `install -D` creates the destination directory if needed:

```zsh
sudo pacman -S --needed pacman-contrib
```

```zsh
sudo install -Dm644 \
  /usr/share/pikaur/examples/pikaur-cache.hook \
  /etc/pacman.d/hooks/pikaur-cache-cleanup.hook
```

Replace the hook's `YOUR_USER` placeholder with the username from your current shell:

```zsh
sudo sed -i "s|YOUR_USER|$USER|g" \
  /etc/pacman.d/hooks/pikaur-cache-cleanup.hook
```

The example keeps one version. I prefer two so the previous package remains available for a downgrade:

```zsh
sudo sed -i 's|--keep 1|--keep 2|' \
  /etc/pacman.d/hooks/pikaur-cache-cleanup.hook
```

Inspect the result:

```zsh
cat /etc/pacman.d/hooks/pikaur-cache-cleanup.hook
```

The action section should resemble this, with your actual username in place of `YOUR_USERNAME`:

```ini
[Action]
Description = Remove unused package files cached by pikaur in user's home directory
Depends = bash
Depends = pacman-contrib
When = PostTransaction
Exec = /usr/bin/bash -c '/usr/bin/paccache --cachedir /home/YOUR_USERNAME/.cache/pikaur/pkg --verbose --remove --keep 2;'
```

Check that the original placeholder is gone. No output means no matches were found:

```zsh
grep -n 'YOUR_USER' /etc/pacman.d/hooks/pikaur-cache-cleanup.hook
```

Preview a cleanup without deleting packages:

```zsh
paccache \
  --cachedir "$HOME/.cache/pikaur/pkg" \
  --dryrun \
  --keep 2 \
  --verbose
```

To perform that cleanup manually:

```zsh
paccache \
  --cachedir "$HOME/.cache/pikaur/pkg" \
  --remove \
  --keep 2 \
  --verbose
```

The installed hook handles subsequent package transactions. Pacman's cache at `/var/cache/pacman/pkg` is separate; install its cleanup hook too:

```zsh
pikaur -S --needed paccache-hook
```

### Set up Zsh

Install Oh My Zsh, autosuggestions, and syntax highlighting:

```zsh
pikaur -S --needed oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
```

Copy the default template and open it:

```zsh
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
```

```zsh
nano ~/.zshrc
```

#### Command search path

Add this near the beginning of `~/.zshrc`. Zsh's `path` array keeps the search path readable; `typeset -U` removes duplicate entries. The order gives your Cargo and user-installed commands priority over later entries.

```zsh
typeset -U path PATH

path=(
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "$HOME/bin"
  /usr/local/bin
  $path
)

export PATH
```

#### Autosuggestions and prompt

After the line that loads Oh My Zsh, add:

```zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
```

This prompt shows `[ArchLars]` and the current directory in colour. Replace `Lars` with your name:

```zsh
PROMPT='%F{white}%B[%F{#1793d1}Arch%F{white}Lars] %F{cyan}%~ %f%b%(!.#.$) '
```

An optional package-install alias:

```zsh
alias pacin='pikaur -S --needed'
```

With that alias, these two examples do the same thing. Run either one when you want to install Firefox:

```zsh
pacin firefox
```

```zsh
pikaur -S --needed firefox
```

#### Syntax highlighting

Keep this at the **bottom of `~/.zshrc`**, after the rest of the interactive configuration. It hooks into Zsh's line editor and needs to load last:

```zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

#### Optional prompt separator

A separator makes it easier to distinguish command output from the next prompt. Add this before the syntax-highlighting line in `~/.zshrc`. The `precmd` hook runs before each prompt and leaves other hooks intact.

```zsh
autoload -Uz add-zsh-hook

prompt_separator() {
  local width=${COLUMNS:-80}
  local line

  # Avoid Kitty wrapping when the line reaches the final column.
  (( width > 1 )) && (( width-- ))

  printf -v line '%*s' "$width" ''
  print -P "%F{244}${line// /─}%f"
}

# Avoid duplicate hooks when reloading
add-zsh-hook -d precmd prompt_separator 2>/dev/null
add-zsh-hook precmd prompt_separator
```

Example terminal output:

```text
───────────────────────────────────────────────────────────────

[ArchLars] ~ $ checkupdates

...

───────────────────────────────────────────────────────────────

[ArchLars] ~ $ pacman -Ss bibata
```

Reload your shell configuration:

```zsh
source ~/.zshrc
```

### Kitty and Fastfetch appearance

The supplied script applies a Nord theme inspired by [Chris Titus's terminal setup](https://youtu.be/hnNjFysodRo?t=2143). It backs up existing Kitty and Fastfetch configuration files before writing its settings.

Install the dependencies, then run the script. Skip cloning if the repository already exists at `/tmp/ArchLinuxTutorials`:

```zsh
sudo pacman -S --needed zsh kitty fastfetch ttf-meslo-nerd

cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials
cd ArchLinuxTutorials

chmod +x scripts/terminal.zsh

./scripts/terminal.zsh

cd
```

#### Text rendering and cursor trail

Add these settings to `~/.config/kitty/kitty.conf`. The text composition setting changes font rendering. The remaining settings enable a cursor trail, set its fade time in seconds, and require a jump of at least two cells:

```conf
text_composition_strategy 1.7 0

cursor_trail 1

cursor_trail_decay 0.1 0.4

cursor_trail_start_threshold 2
```

#### Terminal shortcuts

- Press **Right Arrow** to accept an autosuggestion.
- Type the beginning of a previous command, then press **Up Arrow** to recall a matching command. This is useful for reusing package-install flags.
- Watch the syntax highlighting for misspelled commands and other obvious mistakes.

## 3. Desktop and application settings

### Pacman appearance

```zsh
sudo nano /etc/pacman.conf
```

In `/etc/pacman.conf`, uncomment `Color` and add `ILoveCandy` beneath it. Uncommenting means removing the leading `#`:

```conf
Color
ILoveCandy
```

### Nano syntax highlighting

Create Nano's configuration directory and install additional syntax rules. `mkdir -p` also creates missing parent directories and leaves an existing directory intact.

The commands below enable the rules for your user and system-wide:

```zsh
mkdir -p ~/.config/nano

pikaur -S --needed nano-syntax-highlighting

printf 'include "/usr/share/nano/*.nanorc"\ninclude "/usr/share/nano/extra/*.nanorc"\n' >> ~/.config/nano/nanorc
echo 'include "/usr/share/nano-syntax-highlighting/*.nanorc"' >> ~/.config/nano/nanorc

sudo tee -a /etc/nanorc >/dev/null <<'EOF'
include "/usr/share/nano/*.nanorc"
include "/usr/share/nano/extra/*.nanorc"
include "/usr/share/nano-syntax-highlighting/*.nanorc"
EOF
```

### Disable Kitty's bell

Open the configuration:

```zsh
nano ~/.config/kitty/kitty.conf
```

Add these settings:

```conf
enable_audio_bell no
visual_bell_duration 0
window_alert_on_bell no
bell_on_tab none
```

Reload with Ctrl+Shift+F5. This command sends a bell character so you can check the result:

```zsh
printf '%b' '\a'
```

### Show asterisks at the sudo password prompt

Use `visudo` to edit a drop-in:

```zsh
sudo EDITOR=/usr/bin/nano visudo -f /etc/sudoers.d/pwfeedback
```

Contents of `/etc/sudoers.d/pwfeedback`:

```sudoers
Defaults pwfeedback
```

Save and test with a fresh password prompt:

```zsh
sudo -k
sudo true
```

### Maintenance and multimedia packages

This list adds Arch news notices through Informant, GStreamer codecs, rebuild detection, AUR utilities, Python's package installer, and community maintenance tools. They are useful additions, though not all are required for a desktop.

Install them and add your user to the Informant group:

```zsh
pikaur -S --needed informant \
gst-libav gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly \
rebuild-detector aurutils \
python-pip archlinux-contrib
sudo usermod -aG informant $USER
reboot
```

After rebooting, confirm that `informant` appears in your groups, then read the news:

```zsh
groups
informant read
```

### Browser

I use Firefox:

```zsh
pikaur -S --needed firefox
```

Chromium is another option:

```zsh
pikaur -S --needed chromium
```

### NVIDIA session variables

Plasma loads session environment scripts from `~/.config/plasma-workspace/env`. The following examples use separate `.sh` files for NVIDIA settings. Apply only the sections relevant to your hardware.

#### Video acceleration

```zsh
nano ~/.config/plasma-workspace/env/libva-values.sh
```

Contents of `libva-values.sh`:

```sh
export LIBVA_DRIVER_NAME=nvidia
export MOZ_DISABLE_RDD_SANDBOX=1
export NVD_BACKEND=direct
```

For NVIDIA driver **580.105.08 or newer**, also add:

```sh
export CUDA_DISABLE_PERF_BOOST=1
```

Log out of Plasma completely and log back in. If you added the last setting, check that it returns `1`:

```zsh
printenv CUDA_DISABLE_PERF_BOOST
```

#### GStreamer decoder preference

If GStreamer chooses Libav decoders instead of NVIDIA's hardware decoders, this setting raises the NVIDIA decoder ranks:

```zsh
nano ~/.config/plasma-workspace/env/gst-nvidia-values.sh
```

Contents of `gst-nvidia-values.sh`:

```sh
export GST_PLUGIN_FEATURE_RANK=nvmpegvideodec:MAX,nvmpeg2videodec:MAX,nvmpeg4videodec:MAX,nvh264sldec:MAX,nvh264dec:MAX,nvjpegdec:MAX,nvh265sldec:MAX,nvh265dec:MAX,nvvp9dec:MAX
```

Without AV1 hardware support, you may also want to append `avdec_av1:NONE` and `av1dec:NONE` to the comma-separated list, for example when using a WebKitGTK browser.

#### GLX driver selection

Libglvnd normally selects the OpenGL vendor automatically. If an application selects the wrong renderer, this setting explicitly requests NVIDIA:

```zsh
nano ~/.config/plasma-workspace/env/glx-nvidia-values.sh
```

Contents of `glx-nvidia-values.sh`:

```sh
export __GLX_VENDOR_LIBRARY_NAME=nvidia
```

### Firefox settings

Check VA-API support in the terminal:

```zsh
vainfo
```

Open `about:config` in Firefox and apply the preferences you want:

| Preference | Value | Purpose |
|---|---|---|
| `media.hardware-video-decoding.force-enabled` | `true` | Request hardware video decoding |
| `media.hardwaremediakeys.enabled` | `false` | Avoid media-key conflicts with Plasma |
| `middlemouse.paste` | `false` | Disable middle-click paste in Firefox |

To disable middle-click paste in Plasma too, open **System Settings → Workspace → General Behavior** and turn off **Middle Click: Paste selected text**. Log out and back in, or restart, to apply it fully.

#### Optional: Remove tab close and mute buttons

I close tabs with the middle mouse button, so I hide the close and audio buttons. This CSS marks a tab playing audio with an Arch-blue border instead.

1. In `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`.
2. Open `about:support`, find **Profile Folder**, and select **Open Folder**.
3. Create a `chrome` directory inside the profile, then a `userChrome.css` file inside it.
4. Add the CSS below and restart Firefox completely.

```css
/* Remove the tab close icon/button */
.tab-close-button,
.tab-close-button.close-icon {
  display: none !important;
}

/* Remove tab audio (speaker/mute/autoplay-blocked) indicators in all tab-strip modes */
.tab-audio-button,
.tab-icon-overlay:is([soundplaying], [muted], [activemedia-blocked]) {
  display: none !important;
}

/* Light blue border around tabs that are currently playing audio */
.tabbrowser-tab[soundplaying] .tab-background {
  box-shadow: inset 0 0 0 2px #1793d1 !important;
}
```

#### Optional: Match the window buttons to your theme

To use GTK theme button assets, append this CSS to the same `userChrome.css`. If you skipped the previous section, follow its profile-folder steps first. Credit goes to the author of [this Firefox customization example](https://www.reddit.com/r/firefox/comments/1newm16/working_code_for_userchromecss_for_firefoxnightly/?utm_source=share&utm_medium=mweb3x&utm_name=mweb3xcss&utm_term=1).

```css
/* Minimize button */
.titlebar-min > .toolbarbutton-icon {
    background-image: url("buttons/minimize-normal.svg") !important;
    background-repeat: no-repeat !important;
    background-size: 18px 18px !important;
    background-position: center !important;
    background-color: transparent !important;
    color: transparent !important;
}
.titlebar-min:hover > .toolbarbutton-icon {
    background-image: url("buttons/minimize-hover.svg") !important;
    background-color: transparent !important;
    color: transparent !important;
    background-size: 20px 20px !important;
}

/* Maximize button */
.titlebar-max > .toolbarbutton-icon {
    background-image: url("buttons/maximize-normal.svg") !important;
    background-repeat: no-repeat !important;
    background-size: 18px 18px !important;
    background-position: center !important;
    background-color: transparent !important;
    color: transparent !important;
}
.titlebar-max:hover > .toolbarbutton-icon {
    background-image: url("buttons/maximize-hover.svg") !important;
    background-color: transparent !important;
    color: transparent !important;
    background-size: 20px 20px !important;
}

/* Restore button */
.titlebar-restore > .toolbarbutton-icon {
    background-image: url("buttons/maximized-normal.svg") !important;
    background-repeat: no-repeat !important;
    background-size: 18px 18px !important;
    background-position: center !important;
    background-color: transparent !important;
    color: transparent !important;
}
.titlebar-restore:hover > .toolbarbutton-icon {
    background-image: url("buttons/maximized-hover.svg") !important;
    background-color: transparent !important;
    color: transparent !important;
    background-size: 20px 20px !important;
}

/* Close button */
.titlebar-close > .toolbarbutton-icon {
    background-image: url("buttons/close-normal.svg") !important;
    background-repeat: no-repeat !important;
    background-size: 18px 18px !important;
    background-position: center !important;
    background-color: transparent !important;
    color: transparent !important;
}
.titlebar-close:hover > .toolbarbutton-icon {
    background-image: url("buttons/close-active.svg") !important;
    background-color: transparent !important;
    color: transparent !important;
    background-size: 20px 20px !important;
}
```

Link the theme assets into the profile's `chrome` directory. Replace `PROFILE_ID_HERE` with your actual profile ID, then restart Firefox:

```zsh
cd ~/.config/mozilla/firefox/PROFILE_ID_HERE.default-release/chrome

ln -sfn ~/.config/gtk-3.0/assets buttons
```

#### Optional portal and window-button fixes

Use these only if the portal settings from the installation guide did not give you the expected file picker or window buttons.

For the file picker, set `widget.use-xdg-desktop-portal.file-picker` to `1` in `about:config`.

For missing minimize or maximize buttons, try:

```zsh
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
```

Log out and back in. If the problem remains, the original workaround also suggests installing the GTK portal:

```zsh
pikaur -S --needed xdg-desktop-portal-gtk
```

## 4. Firmware, security, and gaming

### Firmware updates

Install fwupd and start its service:

```zsh
sudo pacman -S --needed fwupd
sudo systemctl start --now fwupd.service
```

Topgrade, introduced below, can handle the update checks. To do them manually, list devices, refresh LVFS metadata, inspect available updates, and install them:

```zsh
fwupdmgr get-devices
fwupdmgr refresh
fwupdmgr get-updates
fwupdmgr update
```

### Optional Bluetooth adjustments

#### Faster connections

On adapters that support it, fast connectability can shorten connection time at the cost of more power use.

```zsh
sudo mkdir -p /etc/bluetooth
sudo nano /etc/bluetooth/main.conf
```

Find `FastConnectable` in `/etc/bluetooth/main.conf`, uncomment it, and set:

```conf
FastConnectable = true
```

#### Mouse stutter while reconnecting other devices

On my MX Master 4, frequent scans for paired devices that were switched off coincided with dropped mouse reports. Increasing the scan interval made the mouse smoother, with the tradeoff that those other devices took a few seconds longer to reconnect.

```zsh
sudo nano /etc/bluetooth/main.conf
```

Under `[LE]`, uncomment and set these values:

```conf
ScanIntervalAutoConnect=2048
ScanWindowAutoConnect=18
```

Restart Bluetooth:

```zsh
sudo systemctl restart bluetooth
```

### Firewall

Install and enable firewalld, then allow KDE Connect in the public zone:

```zsh
sudo pacman -S --needed firewalld firewall-applet
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --zone=public --add-service=kdeconnect
sudo firewall-cmd --reload
```

### Enable multilib

Steam needs 32-bit package support. Open `/etc/pacman.conf`:

```zsh
sudo nano /etc/pacman.conf
```

Uncomment this repository section:

```ini
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Then update the system using **one** of the following methods.

#### Option 1: Topgrade

Topgrade can coordinate updates across system packages, AUR packages, Flatpaks, language-specific tools, and firmware. I find it convenient on a system with several package managers.

This example installs the standalone binary. Find the version you want on the [Topgrade releases page](https://github.com/topgrade-rs/topgrade/releases) and replace `vXX.X.X` before running the block. The example target is x86-64 Linux.

```zsh
ver='vXX.X.X'
target='x86_64-unknown-linux-gnu'
tmpdir="$(mktemp -d)"
mkdir -p "$HOME/.local/bin"
cd "$tmpdir" || exit 1
curl -fLO "https://github.com/topgrade-rs/topgrade/releases/download/$ver/topgrade-$ver-$target.tar.gz"
tar -xzf "topgrade-$ver-$target.tar.gz"
install -m 0755 topgrade "$HOME/.local/bin/topgrade"
topgrade --version
cd
```

Optionally add a shorter alias to `~/.zshrc`:

```zsh
nano ~/.zshrc
```

Add this line:

```zsh
alias pacup='topgrade'
```

Reload the file:

```zsh
source ~/.zshrc
```

Run either the alias:

```zsh
pacup
```

Or the original command:

```zsh
topgrade
```

After updating, check for packages that need rebuilding against changed libraries:

```zsh
checkrebuild
```

For future updates, you can combine the commands. Choose the form that matches whether you added the alias:

```zsh
topgrade && checkrebuild
```

```zsh
pacup && checkrebuild
```

#### Option 2: Pikaur

Running Pikaur without arguments updates both repository and AUR packages:

```zsh
pikaur
checkrebuild
```

For future updates, the combined form is:

```zsh
pikaur && checkrebuild
```

No output from `checkrebuild` normally means it found nothing to rebuild. If it lists a package, rebuild that package with `pikaur -S <pkg> --rebuild`, replacing `<pkg>` with its name.

### Games and Steam

With multilib enabled, install Steam. The optional packages add legacy X11 fonts and automatic loading of the ntsync module:

```zsh
pikaur -S --needed steam xorg-fonts-misc ntsync-autoload

steam
```

#### Fix legacy X11 fonts

Make sure those fonts are indexed. `xorg-fonts-misc` can be installed while `/usr/share/fonts/misc/fonts.dir` is missing, leaving X11 unable to find its Unicode fonts. English can still work through built-in Latin-1 fonts, making this easy to miss for other languages.

Run this as your normal desktop user. `xorg-mkfontscale` supplies `mkfontdir`, and `xorg-xset` supplies `xset` to refresh the running X11 or Xwayland font path:

```zsh
pikaur -S --needed xorg-mkfontscale xorg-xset &&
sudo mkfontdir /usr/share/fonts/misc &&
if [ -n "${DISPLAY:-}" ] && timeout 5s xset q >/dev/null 2>&1; then
    # remove the old entry first so rerunning this doesn't add duplicates
    timeout 5s xset -fp /usr/share/fonts/misc 2>/dev/null &&
    timeout 5s xset +fp /usr/share/fonts/misc &&
    timeout 5s xset fp rehash
else
    echo "No X display available. Font index saved for the next desktop session."
fi
```

You can run this again to refresh an existing index. Without a reachable X display, it saves the index and skips the live refresh. Restart Steam afterwards if it was already running.

#### Fix Steam MP4 playback

If MP4 playback in Steam Chat is broken, close Steam completely and run its H.264 decoder unlock:

```zsh
steam steam://unlockh264/
```

Let Steam finish the download or setup it opens, quit it, then start it normally.

#### Optional: Load ntsync at boot

Skip this if you installed `ntsync-autoload`. Ntsync implements Windows-style synchronization in the kernel for Wine. I use it as a possible performance improvement over earlier synchronization methods.

```zsh
sudo mkdir -p /usr/lib/modules-load.d/
sudo nano /usr/lib/modules-load.d/ntsync.conf
```

Contents of `/usr/lib/modules-load.d/ntsync.conf`:

```conf
ntsync
```

#### Shader preprocessing threads

Shader compilation can use substantial CPU time. If Steam's background preprocessing is using too few threads, you can set the count explicitly. This example uses eight; choose a lower value if you need CPU capacity for other work. Restart Steam after changing it.

```zsh
mkdir -p ~/.steam/steam

printf 'unShaderBackgroundProcessingThreads 8\n' > ~/.steam/steam/steam_dev.cfg
```

The resulting `~/.steam/steam/steam_dev.cfg` contains:

```cfg
unShaderBackgroundProcessingThreads 8
```

### Find files with plocate

Plocate searches a file database, which makes it useful for finding directories such as `steamapps`. Install it, build the database, and try a search:

```zsh
pikaur -S --needed plocate
sudo updatedb
locate -b '\steamapps'
```

Start the daily database-update timer:

```zsh
sudo systemctl start --now plocate-updatedb.timer
```

### Proton GE

Install ProtonUp-Qt:

```zsh
pikaur -S --needed protonup-qt
```

1. Open ProtonUp-Qt and install the Proton GE version you want.
2. Open **Steam → Settings → Compatibility**.
3. Choose **Proton GE** from the dropdown and restart Steam.

I like Proton GE for games that need additional codecs or compatibility fixes, especially older games with unusual video or audio formats.

## 5. Maintenance

### Package hooks

These hooks check for `.pacnew` files that need merging, run Reflector after mirror-list updates, and clean pacman's cache:

```zsh
pikaur -S --needed \
  pacdiff-pacman-hook-git \
  reflector-pacman-hook-git \
  paccache-hook
```

### Keep UKIs current

Install the kernel-install hook to rebuild UKIs after updates:

```zsh
pikaur -S --needed pacman-hook-kernel-install
```

The guide masks these mkinitcpio hooks to avoid duplicate handling. Their presence can vary by setup:

```zsh
sudo ln -s /dev/null /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
sudo ln -s /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook
```

### Nohang

I recommend Nohang to terminate processes under severe memory pressure before the desktop becomes unresponsive:

```zsh
pikaur -S --needed nohang

sudo systemctl enable --now nohang-desktop.service
```

### Journal size limit

I limit the persistent journal to keep disk usage small:

```zsh
sudo mkdir -p /etc/systemd/journald.conf.d
sudo nano /etc/systemd/journald.conf.d/00-journal-size.conf
```

Contents of `/etc/systemd/journald.conf.d/00-journal-size.conf`:

```ini
[Journal]
SystemMaxUse=50M
```

## 6. Keyboard and USB settings

### X11 keyboard layout

For a non-US keyboard, I also configure an X11 layout for compatibility even though the main desktop uses Wayland. The command generates `/etc/X11/xorg.conf.d/00-keyboard.conf`.

Replace `no` and `pc105` with your layout and keyboard model. My Norwegian keyboard uses `pc105`; some US keyboards use `pc104`.

```zsh
sudo localectl set-x11-keymap no pc105
```

### USB autosuspend

Autosuspend saves power, but some keyboards and mice respond poorly after idling. The rules below keep selected input devices awake while allowing other USB devices to suspend. `power/control="on"` disables autosuspend; `"auto"` allows it.

Choose **one** rule set for `/etc/udev/rules.d/50-usb_power_save.rules`.

#### Option A: Match product names

This is the simpler example. It excludes products whose names end in `Mouse` or `Keyboard`:

```zsh
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```

File contents:

```udev
ACTION=="add", SUBSYSTEM=="usb", ATTR{product}!="*Mouse", ATTR{product}!="*Keyboard", TEST=="power/control", ATTR{power/control}="auto"
```

#### Option B: Match interface classes

Use this alternative when product names do not identify the devices. It keeps HID boot keyboards (`030101`) and mice (`030102`) awake. The components are class `03` for HID, subclass `01` for the boot interface, and protocol `01` or `02` for keyboard or mouse.

```zsh
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```

Alternative file contents:

```udev
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTR{power/control}="auto"

ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030101:*", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030102:*", ATTR{power/control}="on"
```

Reload the rules, retrigger USB events, and inspect the power state:

```zsh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add

grep -H . /sys/bus/usb/devices/*/power/{control,runtime_status}
```

## 7. Media tools

### Install yt-dlp

Yt-dlp downloads media from supported websites. Choose **one** installation method.

#### Option A: uv

I prefer the upstream installation through uv. These packages need their own updates through `uv tool upgrade --all`, or a tool such as Topgrade that includes uv updates.

The example uses `UV_NO_MODIFY_PATH=1` with the installer. The earlier Zsh setup already includes `~/.local/bin` in `PATH`.

```zsh
UV_NO_MODIFY_PATH=1 curl -LsSf https://astral.sh/uv/install.sh | sh
rehash
type -a uv uvx
uv --version
uv self update
uv tool install 'yt-dlp[default,curl-cffi]'
```

The extras provide yt-dlp's default optional dependencies and browser impersonation through `curl_cffi` for sites that need it.

#### Option B: Repository packages

If you prefer package-manager updates, install:

```zsh
pikaur -S --needed yt-dlp python-curl_cffi
```

#### JavaScript support

After either installation method, install the runtimes and add the remote-component setting:

```zsh
pikaur -S --needed deno nodejs
mkdir -p ~/.config/yt-dlp && echo "--remote-components ejs:github" >> ~/.config/yt-dlp/config
```

### Optional yt-dlp aliases

Add these to `~/.zshrc`. `ytdla` downloads MP3 audio to Music and uses Firefox cookies; `ytdlv` downloads video to Videos. Change the browser argument if needed, though I have only tested the Firefox version.

```zsh
alias ytdla='yt-dlp \
    --cookies-from-browser firefox \
    --js-runtimes deno \
    -f "bestaudio/best" \
    --extract-audio \
    --audio-format mp3 \
    --embed-metadata \
    --embed-thumbnail \
    -o "$HOME/Music/%(title)s.%(ext)s"'

alias ytdlv='yt-dlp --js-runtimes deno -f "bestvideo+bestaudio" \
    --merge-output-format mkv \
    -o "$HOME/Videos/%(title)s.%(ext)s"'
```

Save and run `source ~/.zshrc`. Use either alias followed by the media URL.

### Clip a video

This script accepts a URL, a start and end time, and an optional quality limit. It requires yt-dlp and FFmpeg.

```zsh
mkdir -p /home/$USER/bin/
nano /home/$USER/bin/ytclip
```

Contents of `/home/$USER/bin/ytclip`:

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

# Limit the selected video height
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

# Format sorting preference
SORT_PREF='res,codec:av1:vp9:h264,ext'

# Safe tags for filename (turn 3:51 into 3m51s)
start_tag="${START//:/m}s"
end_tag="${END//:/m}s"

# Re-encode at cut points for accurate clipping
exec yt-dlp "$URL" \
  -f "$FMT" -S "$SORT_PREF" --merge-output-format mp4/mkv \
  --download-sections "*${START}-${END}" --force-keyframes-at-cuts \
  -o "%(id)s_${start_tag}_${end_tag}.%(ext)s"
```

Make it executable:

```zsh
chmod +x /home/$USER/bin/ytclip
```

Usage and examples, with the example URL replaced by your own:

```text
ytclip <url> <start> - <end> [best|360p|720p|1080p]
Examples:
  ytclip '(link)' 3:51 - 3:54 360p
  ytclip '(link)' 00:03:51 - 00:03:54 best
```

Use the tool in accordance with the site's terms and the rights to the media you download.

### Video players

Choose the player you prefer. I currently use Haruna, but VLC and MPV are alternatives.

#### Haruna

Haruna combines MPV playback with a Qt interface that fits KDE. This also installs the third-party MPV Phonon backend and enables automatic hardware decoding in MPV's configuration:

```zsh
pikaur -S --needed haruna

pikaur -S --needed phonon-qt6-mpv

mkdir -p ~/.config/mpv
echo "hwdec=auto" > ~/.config/mpv/mpv.conf
```

#### VLC

VLC offers a broad GUI and a Phonon backend. In my experience, YouTube playback and NVIDIA hardware acceleration have been less reliable than I would like.

```zsh
pikaur -S --needed vlc vlc-plugins-all
pikaur -S --needed phonon-qt6-vlc
```

For hardware decoding, check **Tools → Preferences → Input & Codecs → Hardware-accelerated decoding**.

Optionally install click-to-pause support:

```zsh
pikaur -S --needed vlc-pause-click-plugin
```

#### MPV

Choose MPV if you prefer a minimal interface and manual configuration. This also installs the third-party Phonon backend and enables automatic hardware decoding:

```zsh
pikaur -S --needed mpv

pikaur -S --needed phonon-qt6-mpv

mkdir -p ~/.config/mpv
echo "hwdec=auto" > ~/.config/mpv/mpv.conf
```

### Music: Elisa

I use Elisa for its KDE integration:

```zsh
pikaur -S --needed elisa
```

## 8. Optional display and hardware tweaks

### Font rendering

I prefer Lucidglyph's slightly heavier rendering. It does not affect Chromium browsers in the setup described here. See the [font-rendering discussion](https://old.reddit.com/r/linuxquestions/comments/1qzah2h/the_font_rendering_on_linux_is_just_bad_has/) for the background that led me to try it.

Install the font and Lucidglyph:

```zsh
pikaur -S --needed ttf-dejavu-nerd
git clone https://github.com/maximilionus/lucidglyph
cd lucidglyph
sudo ./lucidglyph.sh install
```

In **System Settings → Appearance → Fonts**:

- Set the fixed-width font to **DejaVu Sans Mono**.
- Set General, Small, Toolbar, Menu, and Window title to **Noto Sans**.
- Set hinting to **Slight** and subpixel rendering to **None**, then apply.

In `~/.config/kitty/kitty.conf`, use:

```conf
text_composition_strategy 1.7 0
```

Reboot to see the result:

```zsh
reboot
```

If you want to undo Lucidglyph, run this from its checkout and reboot again:

```zsh
sudo ./lucidglyph.sh uninstall
reboot
```

### Apple device fast charging

The [Apple fast-charging guide](extra/tutorials/applefastcharge.md) uses the kernel's `apple-mfi-fastcharge` driver and a udev rule to request faster charging for supported devices.

The reported `charge_type` is usually `Trickle` or `Fast`. `Fast` confirms the request, not the actual electrical power draw. Use an inline USB power meter to measure watts or amps.

### Advanced: Qt animations on high-refresh-rate monitors

**This replaces `qt6-base`, a package KDE Plasma depends on, with a third-party patched build. A broken or delayed update can leave the desktop unusable and may require recovery from a live environment.**

Only consider it if you are comfortable entering a chroot and reinstalling the official `qt6-base` package to recover.

The workaround targets Qt animations that appear capped around 60 frames per second on faster displays, such as scrolling in Dolphin or System Settings. The patch changes a timing value from 16 to 4. See the [KDE discussion of high-refresh-rate animations](https://www.old.reddit.com/r/kde/comments/1p26pu0/highrefreshrate_users_were_working_on_removing/) for context.

```zsh
pikaur -S --needed qt6-base-hifps
```

## Finish

Before the final reboot, you can remove orphaned packages: dependencies no longer required by installed packages. Review the removal list before confirming. The command also removes their configuration files and any dependencies that become unused:

```zsh
sudo pacman -Rns $(pacman -Qtdq)
reboot
```

After rebooting, open Kitty with Ctrl+Alt+T and try Fastfetch:

```zsh
pikaur -S --needed fastfetch
fastfetch
```

Press Print Screen if you want a screenshot of your desktop.

For further setup, see [Secure Boot](extra/tutorials/secureboot.md), [LUKS encryption](extra/tutorials/luks.md), and [mounting another drive](extra/tutorials/newdrive.md). Enjoy Arch!
