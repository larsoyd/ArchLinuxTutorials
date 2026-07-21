# Post-Install Tutorial (KDE)

Welcome to the post-install tutorial where we will set up your KDE Plasma install to proper defaults and configurations, before we begin I strongly recommend you go over [**this**](misc.md) list of optional misc. settings you might want to turn off/on that I couldn't find a good place to put in the tutorial itself.




## 1 · Chaotic-AUR
```zsh
# Chaotic-AUR is a repository that provides a large number of packages for Arch Linux.
# Its a binary repository that builds packages from the AUR on Arch. This is good if
# you don't want to compile packages and if you do not trust yourself to read PKGBUILDs
# Not required, but I recommend adding it.
#
# First, retrieve the primary key to enable
# the installation of Chaotic-AUR's keyring and mirror list:
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

# This allows you to install Chaotic-AUR's
# chaotic-keyring and chaotic-mirrorlist packages:
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
```

```conf
# Add the mirrorlist to the end of /etc/pacman.conf:
sudo nano /etc/pacman.conf

# /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
```

```zsh
# Then sync the mirrorlist:
sudo pacman -Syu

# And finally install all database files for new repository
# This needs to be done after adding any new repo
# like if you want to use CachyOS's repos for example:
sudo pacman -Fy
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

---

### Optional: Rebind CTRL + C to copy and CTRL + V to paste
Here is how to rebind CTRL + C and CTRL + V to copy + paste, Add this to your `kitty` config, `~/.config/kitty/kitty.conf`:

```conf
map ctrl+shift+v no_op
map ctrl+v paste_from_clipboard

map ctrl+shift+c no_op
map ctrl+c copy_and_clear_or_interrupt
map ctrl+shift+c send_text all \x03
```


### Optional: Rebind Ctrl + Plus and Ctrl + Minus to Zoom
Ditto as above but for zooming.

```conf
# Zoom font with Ctrl + plus/minus instead of Ctrl + Shift + plus/minus
map ctrl+plus change_font_size all +2.0
map ctrl+equal change_font_size all +2.0
map ctrl+kp_add change_font_size all +2.0

map ctrl+minus change_font_size all -2.0
map ctrl+kp_subtract change_font_size all -2.0

# Disable Kitty's default Ctrl + Shift zoom bindings
map ctrl+shift+plus no_op
map ctrl+shift+equal no_op
map ctrl+shift+kp_add no_op

map ctrl+shift+minus no_op
map ctrl+shift+kp_subtract no_op
```

### Increase Default Zoom & Allow Changing Kitty Config In Terminal

```conf
# Remote Control
allow_remote_control yes

# Font Size
font_size 18
```

Then reload Kitty’s config with Ctrl+Shift+F5.

### Essential build tools, you already installed these during install but just to be sure
```zsh
sudo pacman -S --needed base-devel git  # when you run pacman with the --needed flag it will skip
                                        # any package that is already on the system.
                                        #
                                        # If you don't do this it will reinstall packages you already have,
                                        # so it's good to just do it by default to be sure.
```

### Optimize Build Environment:

```zsh
sudo pacman -S --needed ccache mold rustup sccache

# setup rustup
rustup default stable

# Configure ccache
mkdir -p ~/.config/ccache/
mkdir -p ~/.cargo
```

```sh
nano ~/.config/ccache/ccache.conf

# ~/.config/ccache/ccache.conf
cache_dir = $HOME/.cache/ccache
max_size  = 30G
```

```sh
nano ~/.cargo/config.toml

# ~/.cargo/config.toml
[build]
rustc-wrapper = "sccache"

[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "target-cpu=native", "-C", "link-arg=-fuse-ld=mold"]
```

```sh
sudo mkdir -p /etc/makepkg.conf.d
sudo nano /etc/makepkg.conf.d/rust.conf
```

```zsh
# /etc/makepkg.conf.d/rust.conf
RUSTFLAGS="-C link-arg=-fuse-ld=mold -C target-cpu=native"
```

EITHER:

1) Copy it from my repo
```zsh
cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials
cp /tmp/ArchLinuxTutorials/makepkg.conf ~/.makepkg.conf
cd
```

2. Write it manually
```zsh
nano ~/.makepkg.conf
```

```conf
# ~/.makepkg.conf

# Retarget both C and C++ to native while keeping Arch's hardening flags
CFLAGS="${CFLAGS/-march=x86-64-v4/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64-v3/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64-v2/-march=native}"
CFLAGS="${CFLAGS/-march=x86-64/-march=native}"

CXXFLAGS="${CXXFLAGS/-march=x86-64-v4/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64-v3/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64-v2/-march=native}"
CXXFLAGS="${CXXFLAGS/-march=x86-64/-march=native}"

# LTO default if system config had !lto
OPTIONS=("${OPTIONS[@]/!lto/lto}")

# No Debug Packages
OPTIONS+=(!debug)

# Enable ccache in the build environment
BUILDENV=("${BUILDENV[@]/!ccache/ccache}")

# mold default linker
LDFLAGS+=" -fuse-ld=mold"

# parallel builds
MAKEFLAGS="-j$(nproc)"
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

### Either build yay from AUR or install it via Chaotic-AUR
```zsh
# If you enabled Chaotic-AUR you can just install it like so:
sudo pacman -S --needed yay

# But if you want to build it from the AUR
# without installing from Chaotic-AUR:
#
# go to the temporary directory
cd /tmp

# clone the yay pkgbuild from the aur                                      
git clone https://aur.archlinux.org/yay.git

# enter the cloned folder
cd yay

# build the package, then install it and deps
makepkg -si

# go home, remove the temporary build folder
cd ~ && rm -rf /tmp/yay                      

yay --version  # quick test | NOTE: Whenever you run any 'yay' command, do not use 'sudo' before it.
```

### Shell and terminal bliss
```zsh
# Oh-my-zsh makes your terminal nicer, zsh-autosuggestions and the other are plugins
# More on them later.
yay -S --needed oh-my-zsh-git zsh-autosuggestions zsh-syntax-highlighting
```

### Copy .zshrc default template config

```zsh
# This makes it so you don't have to write out a buncha crap
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
```

### Configure ~/.zshrc

```ini
# Tip: You can press F12 to insert the letter ~ into the terminal
# This avoids having to spider-man hand ALT + whatever to write it
#
nano ~/.zshrc

# Before scrolling to the bottom uncomment the PATH like so:
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Add this under the path above so you also can use your Rust packages.
export PATH="$HOME/.cargo/bin:$PATH"

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
```zsh
# Then reload zshrc like so:
source ~/.zshrc
```

### Make Kitty Look Nice
```zsh
# Ensure you have the dependencies.
sudo pacman -S --needed zsh kitty fastfetch ttf-meslo-nerd

# Install the Terminal config slightly mocking Chris Titus's look in:
# https://youtu.be/hnNjFysodRo?t=2143

# Clone repo if you haven't
cd /tmp
git clone https://github.com/larsoyd/ArchLinuxTutorials
cd ArchLinuxTutorials

# Make rice script executible
chmod +x terminal.zsh

# Run it
./terminal.zsh

# Go back to HOME
cd
```

#### Add Cursor Trail to Kitty & Font Rendering Improvement

```zsh
# Cursor trail is a cool animated trail and text composition strategy improves the
# font rendering
#
# Add these to ~/.config/kitty/kitty.conf :

# Text comp
text_composition_strategy 1.7 0

# Optional: Enable the cursor trail (set value > 0)
cursor_trail 1

# Optional: Adjust how fast the trail fades (min and max seconds)
cursor_trail_decay 0.1 0.4

# Optional: Minimum distance (in cells) the cursor must jump to trigger a trail
cursor_trail_start_threshold 2
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
```zsh
sudo nano /etc/pacman.conf
```
```conf
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
```zsh
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
```zsh
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
```zsh
# open a drop-in with visudo
sudo EDITOR=/usr/bin/nano visudo -f /etc/sudoers.d/pwfeedback

# add exactly this line, then save and exit
Defaults pwfeedback

# test by forcing a fresh prompt
sudo -k
sudo true
```
### Install Basic packages:

```zsh
# essential stuff to have.
yay -S --needed informant \
gst-libav gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly \
rebuild-detector aurutils \
python-pip kdeconnect

# add yourself to group informant
sudo usermod -aG informant $USER

# then reboot 
reboot

# afterwards confirm you are in that group by running:
groups

# if you are run informant
informant --check
```

### Browser
```zsh
# recommended:
yay -S --needed firefox

# or anything else
yay -S --needed chromium   # example of "anything else"
```

### How to add Environmental Variables:

On Arch with KDE Plasma, you should put environmental variables in Plasma’s session environment directory. This is located in `~/.config/plasma-workspace/env` Create a small .sh file there for each variable. For example, for decoding with NVIDIA you create `~/.config/plasma-workspace/env/libva-values.sh`

For SonicDE you have to replace `plasma-workspace` with `sonicde-workspace` instead.


### Hardware Acceleration on NVIDIA 

```zsh
# Create the file:
nano ~/.config/plasma-workspace/env/libva-values.sh
```

```sh
# Options added to ensure hardware acceleration works
# on NVIDIA.
# ~/.config/plasma-workspace/env/libva-values.sh
export LIBVA_DRIVER_NAME=nvidia
export MOZ_DISABLE_RDD_SANDBOX=1
export NVD_BACKEND=direct

# Only if your NVIDIA driver is version
# 580.105.08 or newer
export CUDA_DISABLE_PERF_BOOST=1
```


Then log out of Plasma completely and log back in. After that, check any value with:

```zsh
# For example:
printenv CUDA_DISABLE_PERF_BOOST
```

It should return `1`

### NVIDIA GST Libav Fix:

For some NVIDIA users, gst-libav may prioritize the Libav decoder over nvcodec decoders which will inhibit hardware acceleration. The GST_PLUGIN_FEATURE_RANK environment variable can be used to rank decoders and thus alleviate this issue. See "GST_PLUGIN_FEATURE_RANK" in the documentation for more information.

```zsh
# Create the file:
nano ~/.config/plasma-workspace/env/gst-nvidia-values.sh
```

```sh
# ~/.config/plasma-workspace/env/gst-nvidia-values.sh
export GST_PLUGIN_FEATURE_RANK=nvmpegvideodec:MAX,nvmpeg2videodec:MAX,nvmpeg4videodec:MAX,nvh264sldec:MAX,nvh264dec:MAX,nvjpegdec:MAX,nvh265sldec:MAX,nvh265dec:MAX,nvvp9dec:MAX
```

Those without AV1 hardware support may also want to disable AV1 decoders (e.g., for YouTube on webkit2gtk based browsers) by appending `avdec_av1:NONE` and `av1dec:NONE` to the list above. 

### NVIDIA GLX Helper:

Modern Linux systems use libglvnd, a vendor-neutral OpenGL dispatch layer. Its job is to choose whether OpenGL calls go to Mesa, NVIDIA, etc. By adding this you help many games and relevant apps use the NVIDIA driver instead of falling back to Mesa, llvmpipe, or the wrong GPU. If you do not set this explicitly and you happen to have this problem the games will run at single digit FPS and you have no idea why. Pretty fun.

```zsh
# Create the file:
nano ~/.config/plasma-workspace/env/glx-nvidia-values.sh
```

```sh
# ~/.config/plasma-workspace/env/glx-nvidia-values.sh
export __GLX_VENDOR_LIBRARY_NAME=nvidia
```

### Configuring Firefox:

#### Add VA-API to Firefox (GPU accelerated video)
```zsh
# Confirm VA-API support
vainfo

# Open up about:config and set:
media.hardware-video-decoding.force-enabled → true
```

#### Ensure Firefox media keys dont conflict with Plasma
```zsh
# open about:config and set
media.hardwaremediakeys.enabled → false
```


#### Turn off Middle Click Paste on Firefox
```zsh
# open about:config and set
middlemouse.paste → false
```

Then turn off Middle Click Paste on KDE Plasma:

```zsh
# You also need to set this globally.
System Settings → Workspace → General Behavior → Middle Click: Paste selected text → Off
```
Finally, log out/in or restart for it to fully apply.

---

### OPTIONAL: Remove the Close + Mute button on Tabs

If you are like me you close tabs with middle mouse click and you don't care to mute the tab has sound on it then you want to remove these buttons on the tabs since they get in the way. These changes removes those buttons then puts a light blue (`#1793d1`) border around the tab icon instead to indicate what tab is playing audio. Why light blue? It harmonizes with the primary color of Arch Linux and KDE Plasma. Feel free to change it in the code if you like.

1. First, go to `about:config` in URL bar and then put in `toolkit.legacyUserProfileCustomizations.stylesheets` and set it to `true`
2. Then write `about:support` in the URL bar and press enter.
3. Go to `Profile Folder` section and press `Open Folder`
4. Create a new folder in the directory called `chrome` (Yes I know, that is what it is called)
5. Create a file in there called `userChrome.css` with these contents :

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

6. Completely quit and restart Firefox for the changes to take effect. 
7. Enjoy!

### OPTIONAL: Fix The Appearance of The Firefox Buttons

By default Firefox hardcodes its own buttons regardless of your system theme. This makes Firefox look gross compared to other applications. To fix this you need to add this to your `userChrome.css`. If you skipped the previous step you must create it before applying this fix.
Credit to [this wonderful person](https://www.reddit.com/r/firefox/comments/1newm16/working_code_for_userchromecss_for_firefoxnightly/?utm_source=share&utm_medium=mweb3x&utm_name=mweb3xcss&utm_term=1) for figuring out how to do this.

**If you skipped the previous step, do this first:**

1. First, go to `about:config` in URL bar and then put in `toolkit.legacyUserProfileCustomizations.stylesheets` and set it to `true`
2. Then write `about:support` in the URL bar and press enter.
3. Go to `Profile Folder` section and press `Open Folder`
4. Create a new folder in the directory called `chrome` (Yes I know, that is what it is called)
5. Create a file in there called `userChrome.css` with these contents :

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

Then after adding this, symlink this to your Firefox chrome directory. Replace profile id with yours:

```zsh
cd ~/.config/mozilla/firefox/PROFILE_ID_HERE.default-release/chrome

ln -sfn ~/.config/gtk-3.0/assets buttons
```

And finally restart Firefox.

### OPTIONAL: Various Fixes for Firefox That Might Help You

Sometimes after install Firefox looks odd, some buttons are off and incorrect. 
**These optional knobs are only if the GDK portal we set up in the install itself didn't work.**
**Skip** if whatever entry does not apply to Firefox on your system.
The technical reason is a bit out of scope for this tutorial, but essentially it thinks that it is
in another desktop environment. Portals are supposed to fix that, but if they don't you can try these
fixes:

#### (Optional) - Force Firefox to use Dolphin
```zsh
# Optional if needed. GDK_DEBUG=portals set earlier should have done it.
# If not, force Firefox to do it, open about:config and set:
widget.use-xdg-desktop-portal.file-picker → 1 (always)
```

#### (Optional) - Add all buttons to Firefox
```zsh
# Sometimes Firefox does not have the minimize and maximize buttons
# You can try this remedy:
gsettings set org.gnome.desktop.wm.preferences button-layout 'icon:minimize,maximize,close'
# Then log out and back in

# If that still doesn't work, then try:
yay -S --needed xdg-desktop-portal-gtk
```

---

## 4 · Essential security and quality of life

### 4.0 Firmware Updates
```zsh
# You are going to need to update your firmware
# To do this install fwupd and start the service
sudo pacman -S --needed fwupd
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
```zsh
sudo pacman -S --needed firewalld firewall-applet
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --zone=public --add-service=kdeconnect
sudo firewall-cmd --reload
```

### 4.2 Enable multilib for 32-bit support (pre-Steam)

```zsh
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
```zsh
# Topgrade is an optional but super quality of life package
# With one command of `topgrade` you can upgrade all your packages of any type on your entire system...
# That is *all* your packages, including flatpaks, sys packages like the kernel, AUR, Rust crate, etc.
# It also shows available firmware to upgrade. It is so helpful that even though its a bit out there...
# ... I still think it's essential for QoL on any Arch system.
# If you think this sounds neat then I strongly recommend it.
#
# I am going to show you how to install the self updating binary which is easier to use than the
# one packaged by the AUR which can't update itself.
# First go to https://github.com/topgrade-rs/topgrade/releases and look for ver number,
# the result should be the latest one. replace this ver= with number you find.
# Paste each line by line.
#
# 1. example: ver=v17.0.0
ver='vXX.X.X'

# 2. This targets your architecture
target='x86_64-unknown-linux-gnu'

# 3. Sets a tmpdir
tmpdir="$(mktemp -d)"

# 4. Creates the binary programs folder in HOME folder if it dont exist
mkdir -p "$HOME/.local/bin"

# 5. Goes to tmpdir 
cd "$tmpdir" || exit 1

# 6. curl to install the binary
curl -fLO "https://github.com/topgrade-rs/topgrade/releases/download/$ver/topgrade-$ver-$target.tar.gz"

# 7. Untar the binary
tar -xzf "topgrade-$ver-$target.tar.gz"

# 8. Install binary to HOME binary programs folder
install -m 0755 topgrade "$HOME/.local/bin/topgrade"

# 9. Check version to ensure it worked.
topgrade --version

# 10. Go back HOME
cd

# --- OPTIONAL ALIAS:

# If you want you can add an alias to run topgrade with a
# better command name
#
# worth it so that you better remember it and to make it fit
# more in line with the other commands that start with "pac".
#
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

# ---

# This is a good time to teach you the habit of running `checkrebuild` after updates.
# 'checkrebuild' checks if you need to rebuild any packages towards new dependencies.
#
# If you don't do that when needed, it can lead to instability.
checkrebuild

# If you don't want to remember this, just run this once and then use it from history
# every time you update. It simply runs topgrade and then after runs checkrebuild in
# one command:
topgrade && checkrebuild

# Or for alias:

pacup && checkrebuild

# usually it doesn't list anything, that means you're good, but if it does you need to run
# yay  -S <pkg> --rebuild
```

Option 2) with yay:
```zsh
# Tip/Fun Fact: You can update your system by just writing 'yay'.
# This is actually ideal, as pacman -Syu does not update your AUR packages.
# Try it:
yay

# This is a good time to teach you the habit of running `checkrebuild` after updates.
# 'checkrebuild' checks if you need to rebuild any packages towards new dependencies.
#
# If you don't do that when needed, it can lead to instability.
checkrebuild

# If you don't want to remember this, just run this once and then use it from history
# every time you update. It simply updates and then after runs checkrebuild in
# one command:
yay && checkrebuild

# usually it doesn't list anything, that means you're good, but if it does you need to run
# yay  -S <pkg> --rebuild
```

### 4.2.5 Games & Steam
```zsh
# then after enabling multilib DL Steam
# 
# xorg-fonts-misc is an optional addition to Steam that was recently added.
# It simply provides fonts for for non-latin locales. Neat to have.
yay -S --needed steam xorg-fonts-misc

# Run Steam in terminal to install it:
steam
```

### Fix Steam MP4 Playback
By default MP4 playthrough in Steam Chat is broken under Linux. To fix this you need to run Steam’s H.264 decoder unlock for the Linux web component. Run this with Steam fully closed:

```zsh

steam steam://unlockh264/

```

Then let Steam finish whatever it opens/downloads, quit Steam again, and start it normally. 

### Enable ntsync by default
```zsh
# ntsync is an experimental Linux kernel driver mimicking Windows synchronization mechanisms.
# It should improve performance of Wine synchronization syscalls comparing to their previous,
# more user-space-based implementations (esync, fsync). Emphasis on should. I have personally
# noticed no regressions. 
sudo mkdir -p /usr/lib/modules-load.d/
sudo nano /usr/lib/modules-load.d/ntsync.conf
```

Add this:

```conf
# /usr/lib/modules-load.d/ntsync.conf
ntsync
```

### Make Shader Pre-Compilation Faster

When running games under Proton the shader compilation can legitimately hit high CPU usage because it is parallel work. This can create runtime stuttering if done during play. To mitigate this shader preprocessing is set on by default beforehand. This usually takes seconds, but sometimes under certain circumstances™ shader pre-compilation may only use one core for w/e reason and that is when people usually get frustrated by it and learn bad habits like skipping, however this flaw can be overridden by the user by adding a conf file that makes Steam always use more cores for shader comp. Example number is 8 cores, modify the number depending your own CPU and workload. Shader comp is heavy on the CPU so if you are doing other things like streaming or w/e you might want to set a lower number than all the cores. Restart Steam afterwards if it was already running:


Here is how to set it:


```zsh
mkdir -p ~/.steam/steam
printf 'unShaderBackgroundProcessingThreads 8\n' > ~/.steam/steam/steam_dev.cfg
```

This is how ~/.steam/steam/steam_dev.cfg will look like afterwards when correctly done:

```cfg
unShaderBackgroundProcessingThreads 8
```



### 4.2.6 plocate - Quickly find any file or folder on your Arch Linux system
```zsh
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
```zsh
# install protonup qt (ProtonGE)
yay -S --needed protonup-qt
```

### Configure Proton GE as the default in Steam after installing Proton GE from ProtonUp-Qt:

0. Open up ProtonUp-Qt and install the latest version of Proton GE
1. Launch Steam and open **Settings → Compatibility**.  
2. In the dropdown, choose **Proton GE**.  
3. Click OK and restart Steam.

ProtonGE is a good default for a lot of games IMO, works just as well as regular Proton for most games and **BETTER** for other games that include 
propietary codecs and such that Valve cannot package themselves. This helps with games that rely on video files and music with odd/outdated formats.



---

## 5 · Maintenance hooks
```zsh
# these hooks are great for system maintenance
#
# pacdiff shows you if any .pacnew is on your system needed to merge
#
# reflector will run reflector any time mirrorlist updates
#
# paccache-hook is the GOAT. it cleans your cache after using pacman.
#
# yaycache-hook will remove old and uninstalled packages from yay cache
yay -S --needed \
  pacdiff-pacman-hook-git \
  reflector-pacman-hook-git \
  paccache-hook yaycache-hook
```


### How to Prevent Stale UKIs
```zsh
# To prevent stale UKIs you need a hook to run after every update
# Or do it manually, but automatic is better.
#
yay -S --needed pacman-hook-kernel-install

# NOTE: This may not be needed, sometimes they are not installed
# other times they are. I have had mixed results. Good to run both
# anyways just to ensure they are removed.
#
# Mask the mkinitcpio hooks to prevent duplicates::
sudo ln -s /dev/null /etc/pacman.d/hooks/60-mkinitcpio-remove.hook
sudo ln -s /dev/null /etc/pacman.d/hooks/90-mkinitcpio-install.hook
```

### Install & Enable Nohang:
```zsh
# This is an OOM killer. DON'T SKIP. It's VITAL.
yay -S --needed nohang-git 

# Reason why it's vital is this:
# If your system fills up it's swap and RAM then this will terminate offending processes before your system freeze up.
# So if you don't have this your computer will just freeze if you are unlucky and this happens to you for w/e reason.
sudo systemctl enable --now nohang-desktop.service
```

### Set Journalctl limit:
```zsh
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

```zsh
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```
```zsh
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

```zsh
sudo nano /etc/udev/rules.d/50-usb_power_save.rules
```
```zsh
# Default: enable autosuspend on USB devices
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", TEST=="power/control", ATTR{power/control}="auto"

# Keep HID boot keyboard (030101) and mouse (030102) awake
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030101:*", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:030102:*", ATTR{power/control}="on"
```

Apply and retrigger, then recheck:
```zsh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add

# Check to see if either approach worked:
grep -H . /sys/bus/usb/devices/*/power/{control,runtime_status}
```

## YT-DLP and aliases I use with it:

YT-DLP is a downloader for online media hosted on sites. It's very good.

Install (pick one option):
```zsh
OPTION A)
# From uv (Rust based Python manager, very good)
#
# This is recommended as its upstream, though ensure you keep it up to date.
# If you simply run `yay` or `pacman -Syu` it will NOT update this package.
# You must run `uv tool upgrade --all` as well. This is tedious.
# The best way instead is to update your system using topgrade since it will
# automatically detect that uv is on your system and then
# update that too when ran without you needing to do a damn thing.
#
# Yes, topgrade is an amazing tool. I am not sponsored by them
#
# UV_NO_MODIFY_PATH=1 prevent the installer from editing shell files.
# ~/.local/bin is already on your PATH from ~/.zshrc step earlier
UV_NO_MODIFY_PATH=1 curl -LsSf https://astral.sh/uv/install.sh | sh

# Refresh command cache
rehash

# Verify the standalone uv is first
type -a uv uvx
uv --version

# Set it to self update
uv self update

# Install yt-dlp via uv
uv tool install yt-dlp

--

OPTION B)
# From official repository
#
# If not using topgrade / don't want pipx, you can also get it from the
# repositories, reason why its not reccomended is it may lag behind
# the official package
yay -S --needed yt-dlp

---

# Then install deno and nodejs
yay -S --needed deno nodejs

# And finally add a config file to use the solver each time
mkdir -p ~/.config/yt-dlp && echo "--remote-components ejs:github" >> ~/.config/yt-dlp/config
```

#### OPTIONAL QoL FOR YT-DLP:

- Here are some aliases I use, add to `~/.zshrc` with `nano` on the bottom:

```zsh
alias ytdla='yt-dlp --js-runtimes deno -f "bestaudio/best" \
                 --extract-audio \
                 --audio-format mp3 \
                 -o "/home/$USER/Music/%(title)s.%(ext)s"'

alias ytdlv='yt-dlp --js-runtimes deno -f "bestvideo+bestaudio" \
    --merge-output-format mkv \
    -o "$HOME/Videos/%(title)s.%(ext)s"'
```

Save and then run: `source ~/.zshrc`

#### How to use:

ytdla downloads audio, ytdlv downloads video and places them in appropriate folders with names.
You simply write either of these and a link. 

- Here is a script I made that makes clipping videos easier.

```zsh
mkdir -p /home/$USER/bin/
nano /home/$USER/bin/ytclip
```

Add this script:
```zsh                             
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

```zsh
# make it executable
chmod +x /home/$USER/bin/ytclip
```

#### How to use:

```zsh
ytclip <url> <start> - <end> [best|360p|720p|1080p]
Examples:
  ytclip '(link)' 3:51 - 3:54 360p
  ytclip '(link)' 00:03:51 - 00:03:54 best
```

#### DISCLAIMER: I do not condone breaking site ToS with this tool, nor any other form of piracy.


## Video Playback

My advice is pick one here, you can do both but it's best to not clutter your system.

### Option 1) Haruna

```zsh
# Haruna is KDE's official video player, it is based on MPV but with a Qt based GUI frontend that
# integrates natively into your KDE Plasma system. This is what I use at the moment. Works with
# YouTube Playback well.
#
# install Haruna (video)
yay -S --needed haruna

# You have to do this if you want GPU acceleration for your wholesome entertainment
mkdir -p ~/.config/mpv
echo "hwdec=auto" > ~/.config/mpv/mpv.conf
```

### Option 2) VLC

#### VLC Install:
```zsh
# VLC is the only officially supported third-party player with official Phonon support on KDE.
# It's more fully featured than MPV, MPV requires more manual config to look better.
# However it is buggy in some aspects, like using it for YouTube playback has not been good IMO.
# It also is not reliable for hardware acceleration on NVIDIA IMO
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

### Option 3) MPV
#### MPV Install:
```zsh
# Has become more popular in recent years, is very powerful but a bit nerdy
# If you care about manual configs and stuff use MPV, otherwise use VLC or Haruna
#
# install mpv (video)
yay -S --needed mpv  

# (Third-party) Phonon Support for mpv
yay -S --needed phonon-qt6-mpv

# You have to do this if you want GPU acceleration for your wholesome entertainment
mkdir -p ~/.config/mpv
echo "hwdec=auto" > ~/.config/mpv/mpv.conf
```

## Music Playback

### Elisa

```zsh
# Elisa is KDE's official music player, it also has a Qt based GUI frontend that
# integrates natively into your KDE Plasma system. This is what I use at the moment.
#
# install Elisa (music)
yay -S --needed elisa
```

## Optional: Improve Font Rendering
```zsh
# some people have criticized the font rendering on Linux
# there is a good thread on this here:
# https://old.reddit.com/r/linuxquestions/comments/1qzah2h/the_font_rendering_on_linux_is_just_bad_has/
#
# I installed this and in my opinion it looks better, albeit a bit more bold but I like that personally.
#
# The only real caveat is that it does not work on Chromium browsers.
# If you use those then you wont see a difference on the internet,
# but the rest of the system will look better.
# I prefer it, but YMMV. Try it and see if it works for you,
# if it doesn't remove it with `sudo pacman -Rns lucidglyph` and then
# reboot again.
yay -S --needed lucidglyph ttf-dejavu-nerd

# Set the fonts in KDE Plasma 6
   a) Open: System Settings
   b) Go to: Appearance -> Fonts
   c) Check/Set these entries:
      - General: Noto Sans
      - Fixed width: DejaVu Sans Mono
      - Small: Noto Sans
      - Toolbar: Noto Sans
      - Menu: Noto Sans
      - Window title: Noto Sans

   d) Click: Apply

3) Set Font Hinting to “Slight” (and confirm)
   a) In the same screen: System Settings -> Appearance -> Fonts
   b) Click: Font Management (or “Configure…” button for anti-aliasing, wording varies)
   c) In “Anti-Aliasing” / “Sub-pixel rendering” section:
      - Hinting: Slight
      - Ensure that "Sub-pixel rendering" is set to "None"
   d) Click: Apply

# Kitty Terminal
# add to ~/.config/kitty/kitty.conf
text_composition_strategy 1.7 0
```

## OPTIONAL: Enable iPhone Fast Charging on Linux with a udev Rule

What many do not know is that Linux is capable of fast charging iOS devices. This is set off by default, so here is how you can set up Linux to request fast charging for an iPhone or another supported Apple iOS device using the kernel's `apple-mfi-fastcharge` driver automatically with an udev rule.

### What this checks

The `charge_type` file usually reports one of these values:

```text
Trickle
Fast
```

- `Trickle` means Linux has not requested fast charging.
- `Fast` means Linux has requested fast charging.
- This does not measure real watts or amps. Use an inline USB power meter if you want to verify actual electrical draw.


The fix works by writing `Fast` to the kernel power-supply attribute:

```text
/sys/class/power_supply/apple_mfi_fastcharge*/charge_type
```

### 1. Plug in the iPhone

First plug the iPhone into a USB data-capable port. Open your phone and trust the computer.

Wait a few seconds.

### 2. Load the kernel module

Run:

```zsh
sudo modprobe apple-mfi-fastcharge
```

This should be harmless if the module is already loaded.

### 3. Check the current charge mode

Run:

```zsh
typeset -a charge_files
charge_files=(/sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N))

if (( ${#charge_files} == 0 )); then
  print -r -- "No apple_mfi_fastcharge charge_type file found."
  print -r -- ""
  print -r -- "Try these checks:"
  print -r -- "  sudo modprobe apple-mfi-fastcharge"
  print -r -- "  unplug and replug the iPhone"
  print -r -- "  sudo dmesg | grep -iE 'apple.*mfi|fastcharge|iphone'"
  exit 1
fi

for charge_file in "${charge_files[@]}"; do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Before the fix, you may see something like:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Trickle
```

Older kernels may use a path without the bus/device suffix:

```text
/sys/class/power_supply/apple_mfi_fastcharge/charge_type: Trickle
```

Both path styles are fine.

### 4. Manually enable fast charging once

Before adding the udev rule, test that the kernel attribute works manually:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "Setting $charge_file to Fast"
  print Fast | sudo tee "$charge_file" >/dev/null
done
```

### 5. Check whether the manual change worked

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Expected result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

If this does not change to `Fast`, the udev rule will not fix it either. Check the troubleshooting section first.

### 6. Create the udev rule

Create this file:

```zsh
sudo tee /etc/udev/rules.d/99-apple-mfi-fastcharge.rules >/dev/null <<'EOF'
# Enable fast charging for Apple iPhone/iPad devices handled by apple-mfi-fastcharge.
# Match the power_supply device because the sysfs charge_type file may not exist yet on the first USB add event.
SUBSYSTEM=="power_supply", KERNEL=="apple_mfi_fastcharge*", ACTION=="add|change", RUN+="/bin/sh -c 'echo Fast > /sys%p/charge_type || :'"
EOF
```

Important detail:

```text
/sys%p/charge_type
```

`%p` expands to the sysfs device path relative to `/sys`.

So this becomes something like:

```text
/sys/devices/pci0000:00/.../power_supply/apple_mfi_fastcharge_1-12/charge_type
```

### 7. Reload udev rules

Run:

```zsh
sudo udevadm control --reload-rules
```

### 8. Trigger the rule without rebooting

Run:

```zsh
sudo udevadm trigger --subsystem-match=power_supply --action=change
```

Wait briefly:

```zsh
sleep 1
```

### 9. Check the charge mode after the udev rule

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Correct result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

If it says `Fast`, the rule is working.

### 10. Test by unplugging and replugging

Unplug the iPhone.

Wait a few seconds.

Plug it back in.

Then run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Expected result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

### General Troubleshooting

#### No `apple_mfi_fastcharge` path exists

Run:

```zsh
sudo modprobe apple-mfi-fastcharge
```

Then unplug and replug the iPhone.

Check kernel logs:

```zsh
sudo dmesg | grep -iE 'apple.*mfi|fastcharge|iphone'
```

#### Check whether udev sees the power_supply event

Run this in one terminal:

```zsh
sudo udevadm monitor --kernel --udev --property --subsystem-match=power_supply
```

Then unplug and replug the iPhone.

You should see an event for a device whose name starts with:

```text
apple_mfi_fastcharge
```

#### Check the udev properties for the device

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  device_dir=${charge_file:h}
  print -r -- "Device directory: $device_dir"
  udevadm info --query=property --path="${device_dir#/sys}"
done
```

#### Manually test the exact path style used by the udev rule

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  device_dir=${charge_file:h}
  sys_rel_path=${device_dir#/sys}
  print -r -- "Testing /sys${sys_rel_path}/charge_type"
  print Fast | sudo tee "/sys${sys_rel_path}/charge_type" >/dev/null
done
```

Then check again:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

#### Alternative rule if `/sys%p` does not work on your system

Try this version instead:

```zsh
sudo tee /etc/udev/rules.d/99-apple-mfi-fastcharge.rules >/dev/null <<'EOF'
# Enable fast charging for Apple iPhone/iPad devices handled by apple-mfi-fastcharge.
SUBSYSTEM=="power_supply", KERNEL=="apple_mfi_fastcharge*", ACTION=="add|change", RUN+="/bin/sh -c 'echo Fast > /sys/class/power_supply/%k/charge_type || :'"
EOF
```

Reload and trigger again:

```zsh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply --action=change
sleep 1
```

Check:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

## ADVANCED: Fix Low FPS in Qt6 Applications on Monitors Over 60Hz
```zsh
# ---
# !WARNING!: THIS WILL REPLACE A QT6 SYSTEM PACKAGE WHICH KDE PLASMA DEPENDS ON WITH
# A PATCHED qt6-base PACKAGE MAINTAINED BY A THIRD PARTY
# 
# WHILE IN THEORY IT SHOULD NOT BE A PROBLEM AND APPLY CLEANLY,
# THIS WILL STILL COME WITH THE RISK OF ISSUES IF SAID THIRD PARTY FAILS TO UPDATE
# THE PACKAGE, POTENTIALLY LEADING TO UNBOOTABLE SYSTEMS! - If you are okay
# with chrooting in and reversing a broken update and this issue matters enough to you as it
# does for me, then continue. If not, DO NOT DO THIS. There is no other fix for this than
# doing this.
# ---
#
# There is a long-standing issue with Qt that makes animations such as Overview transitions and scrolling animations
# get capped at 60 frames per second on Qt based applications. on KDE Plasma the best way to see this in action is
# to open up Dolphin (File Manager) or System Settings and then scroll the list up & down on a monitor
# with a high refresh rate (over 60Hz)
#
# This is still unresolved after more than a year and a half due to the way animations are done in Qt.
# More information on this can be found here:
# https://www.old.reddit.com/r/kde/comments/1p26pu0/highrefreshrate_users_were_working_on_removing/
#
# Basically Qt6's animations are hard coded to only run at a certain refresh rate due to tech debt of the Qt Framework itself.
# As of now (2026) the only fix is to use a patched version of qt6-base from the AUR that lowers the hard coded number
# from 16 (around 60Hz) to 4.
yay -S --needed qt6-base-hifps
```

## Final Reboot

#### Reboot again into new system and you can finally sit back, relax, and use arch btw

```zsh
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

---

### EXTRA TUTORIAL: Enable Secure Boot with systemd-boot + UKIs + sbctl

This tutorial uses:

* UEFI firmware
* systemd-boot
* An EFI System Partition mounted at `/efi`
* `kernel-install`
* `mkinitcpio` for the initramfs
* `systemd-ukify` for creating Unified Kernel Images
* UKIs stored inside `/efi/EFI/Linux`

**ONLY follow this section if you installed Arch using this tutorial.**

This is not written for GRUB, shim, rEFInd, split kernel/initramfs booting, or an EFI partition mounted somewhere other than `/efi`.

Secure Boot makes the firmware reject untrusted or modified EFI boot files. In this setup that includes systemd-boot and the UKI containing your kernel, initramfs, microcode, and embedded kernel command line.

**Secure Boot does not encrypt your files.** For protection against someone removing the SSD and reading it from another computer, you also need LUKS encryption.

---


### 0) INTRO: If Dual-Booting Windows with Secure Boot

If you followed my tutorial but also have Windows installed on another partition or drive, read this part before you start the tutorial.

When clearing the keys you will not render your Windows partition unbootable. Windows does not require the original OEM Platform Key. You can replace the Platform Key with your custom sbctl key while retaining Microsoft’s certificates in `KEK` and `db` - More on what that is later.

But that means this command is therefore mandatory for a Windows dual-boot system:

```zsh
sudo sbctl enroll-keys --microsoft
```

Do **NOT** use:

```zsh
sudo sbctl enroll-keys
```

The first command is already used by default in the tutorial so its not something you need to remember necessarily, but if you are on your own in the future you must ensure you never enroll keys without the `--microsoft` flag. A custom-only enrollment can cause firmware to reject Windows Boot Manager when Secure Boot is enabled.

#### Before clearing any Secure Boot keys

Before starting the tutorial, re-enable SecureBoot in firmware and boot into your Windows partition.

Open **Command Prompt as Administrator** and check whether BitLocker or Windows Device Encryption protects the Windows system drive:

```bat
manage-bde -status C:
```

If protection is enabled, make sure you possess the 48-digit BitLocker recovery password:

```bat
manage-bde -protectors -get C:
```

Store the recovery password somewhere that is **not located only on this computer**.

Do not continue until the recovery key has been saved somewhere accessible.

#### Suspend BitLocker before changing Secure Boot keys

From an Administrator Command Prompt:

```bat
manage-bde -protectors -disable C: -rebootcount 0
```

`-rebootcount 0` keeps protection suspended until you manually enable it again. This is useful because setting up custom Secure Boot keys may require several reboots between Windows, Arch, and the firmware settings.

This does **not** decrypt the Windows partition and does not remove its BitLocker protectors. All it does is temporarily stop the TPM from blocking access because the Secure Boot measurements changed. You may now reboot back into the firmware, turn off SecureBoot again and boot into Arch to begin the process. 

---

### IMPORTANT WARNING BEFORE STARTING

Now that you are back in Arch, do some housekeeping before starting. First ensure you have these ready:

* A recent backup of important files
* Your Arch installation USB or another Linux recovery USB
* Access to your firmware/BIOS setup
* The laptop (if used) connected to AC power

**NEVER** use any option/flag called:

* `--yolo`
* `--yes-this-might-brick-my-machine`
* Ignore Option ROM errors
* Clear keys after finishing
* Restore factory keys after finishing

If Arch fails to boot after enabling Secure Boot, always go back into the firmware and **only disable Secure Boot**. Do not clear the keys.

---

### 1) Install the Secure Boot tools

Let's begin the tutorial then, first install the necessary tools:

```zsh
sudo pacman -S --needed sbctl efitools mokutil
```

What each package does:

* `sbctl` creates keys, enrolls them, signs EFI files, and verifies the boot chain
* `efitools` provides `efi-readvar` for viewing the firmware key databases
* `mokutil` provides an additional way to check the Secure Boot state

The Arch `sbctl` package also installs integration for `kernel-install`, mkinitcpio, and pacman transactions.

---

### 2) Confirm that this is the correct boot setup

```zsh
printf 'Firmware boot mode: '

if [[ -d /sys/firmware/efi ]]; then
    echo 'UEFI'
else
    echo 'Legacy BIOS'
fi

echo
echo 'Secure Boot state:'
mokutil --sb-state

echo
echo 'ESP mount:'
findmnt /efi

echo
echo 'Disk layout:'
lsblk -o NAME,SIZE,PTTYPE,FSTYPE,PARTTYPENAME,MOUNTPOINTS

echo
echo 'kernel-install configuration:'
kernel-install inspect
```

You want to see:

```text
Firmware boot mode: UEFI
```

Your main system disk should use GPT, and `/efi` should be a VFAT EFI System Partition.

`kernel-install inspect` should include something similar to:

```text
Layout: uki
Boot Root: /efi
```

Stop here if:

* It says `Legacy BIOS`
* `/efi` is not your EFI System Partition
* Your disk uses MBR instead of GPT
* `kernel-install` is not configured with the `uki` layout
* You did not install using this tutorial

---

### 3) Check whether the firmware is in Setup Mode

```zsh
sudo sbctl status
```

The ideal state before creating and enrolling custom keys is:

```text
Setup Mode: Enabled
Secure Boot: Disabled
```

You may also see:

```text
Installed: ✗ sbctl is not installed
```

This does **NOT** mean the Arch package is missing.

In this context, it means sbctl has not yet created its key hierarchy and owner GUID.

#### If Setup Mode is already enabled

Continue to the next step.

#### If Setup Mode is disabled

Your firmware probably still has its factory Platform Key enrolled. Custom Secure Boot keys cannot normally be enrolled until the firmware is placed into Setup Mode.

Reboot into the firmware:

```zsh
systemctl reboot --firmware-setup
```

If that command is ignored, reboot normally and press the firmware setup key. Common keys are `Esc`, `F2`, `F10`, `F12`, and `Delete`.

Inside the firmware, locate the Secure Boot key-management settings.

Depending on the manufacturer, the required option may be called:

* Delete Platform Key
* Clear Secure Boot Keys
* Reset to Setup Mode
* Key Management
* Custom Secure Boot Keys

The goal is to remove the existing **Platform Key**, which places the firmware into Setup Mode.

Boot back into Arch with Secure Boot still disabled and run:

```zsh
sudo sbctl status
```

Do not continue until it reports that Setup Mode is enabled.

The sbctl documentation requires Setup Mode for live key enrollment and recommends retaining Microsoft trust certificates because some firmware and Option ROM components depend on them.

---

### 4) Inspect the current firmware key databases

This step is read-only:

```zsh
for sb_variable in PK KEK db dbx; do
    printf '\n===== %s =====\n' "$sb_variable"
    sudo efi-readvar -v "$sb_variable" 2>&1
done
```

The variables mean:

* `PK` is the Platform Key that establishes ownership
* `KEK` contains keys allowed to update the trusted and forbidden databases
* `db` contains trusted certificates and hashes
* `dbx` contains revoked certificates and hashes

When the firmware is in Setup Mode, `PK` should have no entries.

`dbx` may contain a massive list of hashes. That is normal. It is the Secure Boot revocation database.

---

### 5) Create your Secure Boot keys

```zsh
sudo sbctl create-keys
```

Check the result:

```zsh
sudo sbctl status

sudo find /var/lib/sbctl/keys \
    -maxdepth 2 \
    -type f \
    -printf '%M %p\n'
```

sbctl should create:

* A Platform Key
* A Key Exchange Key
* A Signature Database key
* An owner GUID

The private keys are stored below:

```text
/var/lib/sbctl
```

Do not upload that directory or put it in a public repository.

After everything is working, make an encrypted offline backup of `/var/lib/sbctl`. Someone who obtains your private database key can sign a modified UKI that your computer will trust.

---

### 6) Create a signed systemd-boot source file

systemd’s `bootctl install` and `bootctl update` prefer a file ending in `.efi.signed` when one is available.

Create and register the signed source:

```zsh
sudo sbctl sign --save \
    --output /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```

Now update the copies installed on the EFI System Partition:

```zsh
sudo bootctl update
```

This should install or update the signed systemd-boot binaries under `/efi/EFI/`.

---

### 7) Sign every currently installed UKI

The UKIs created by this tutorial are stored in:

```text
/efi/EFI/Linux
```

Sign and register all current UKIs:

```zsh
sudo find /efi/EFI/Linux \
    -maxdepth 1 \
    -type f \
    -name '*.efi' \
    -exec sbctl sign --save {} +
```

This does not depend on zsh glob expansion. `find` passes the exact filenames directly to sbctl.

---

### 8) Verify the complete boot chain

```zsh
sudo sbctl verify
```

You want every EFI executable used by this installation to show a checkmark, for example:

```text
✓ /efi/EFI/BOOT/BOOTX64.EFI is signed
✓ /efi/EFI/systemd/systemd-bootx64.efi is signed
✓ /efi/EFI/systemd/systemd-boot-fallbackx64.efi is signed
✓ /efi/EFI/Linux/YOUR-UKI.efi is signed
✓ /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed is signed
```

**DO NOT reboot with Secure Boot enabled if a required boot file is unsigned.**

If sbctl reports an unsigned UKI or systemd-boot file, sign the exact path it prints:

```zsh
sudo sbctl sign --save '/exact/path/reported/by/sbctl.efi'
sudo sbctl verify
```

Repeat until every boot file belonging to this installation is signed.

---

### 9) Enroll your keys and Microsoft’s certificates

```zsh
sudo sbctl enroll-keys --microsoft
```

Using `--microsoft` retains compatibility with firmware components, hardware Option ROMs, Windows boot files, and other EFI programs signed by Microsoft.

If sbctl prints an Option ROM or firmware warning, **STOP and read the message**.

Do not bypass the warning with `--yolo` or `--yes-this-might-brick-my-machine`.

After enrollment, check the status:

```zsh
sudo sbctl status
```

The expected state is:

```text
Installed:    ✓ sbctl is installed
Setup Mode:   ✓ Disabled
Secure Boot:  ✗ Disabled
Vendor Keys:  microsoft
```

Setup Mode should now be disabled because your new Platform Key has been enrolled.

Secure Boot will remain disabled until you enable it in the firmware.


### 10) Confirm that the keys were actually enrolled

```zsh
for sb_variable in PK KEK db; do
    printf '\n===== %s =====\n' "$sb_variable"
    sudo efi-readvar -v "$sb_variable" 2>&1
done
```

You should see:

* Your custom Platform Key in `PK`
* Your custom key plus Microsoft certificates in `KEK`
* Your custom database certificate plus Microsoft certificates in `db`

Current sbctl versions include Microsoft’s newer Secure Boot certificate generation when using `--microsoft`. When this is present and confirmed your Windows partition should boot with SecureBoot enabled.

---

### 11) Reboot into the firmware and enable Secure Boot

```zsh
sync
systemctl reboot --firmware-setup
```

Inside the firmware:

1. Ensure Legacy Boot or CSM is disabled.
2. Enable Secure Boot.
3. Save the settings.
4. Boot Arch.

On some computers, you must disable **Legacy Support** before the Secure Boot option becomes selectable.

Do **NOT** choose any of these after enrolling with sbctl:

* Clear Secure Boot Keys
* Delete All Keys
* Restore Factory Keys
* Load Factory Default Keys

Those options may replace or remove the custom key that signs your Arch UKIs.

---

### 12) Verify Secure Boot after Arch starts

```zsh
sudo sbctl status
mokutil --sb-state
sudo sbctl verify
bootctl status
```

You want:

```text
Setup Mode:   Disabled
Secure Boot:  Enabled
SecureBoot enabled
```

Every file from `sbctl verify` should still show a checkmark.

Congrats. You are now using Secure Boot with your own Arch signing key.

Your boot chain is approximately:

```text
UEFI firmware
    ↓ verifies
systemd-boot
    ↓ loads and verifies
Signed UKI
    ├─ Linux kernel
    ├─ initramfs
    ├─ CPU microcode
    └─ embedded kernel command line
```

---

### 13) Confirm that future kernel updates will be signed

The Arch sbctl package installs a `kernel-install` plugin named:

```text
91-sbctl.install
```

Check the complete local plugin chain:

```zsh
sudo find /usr/lib/kernel/install.d /etc/kernel/install.d \
    -maxdepth 1 \
    -type f \
    -name '*.install' \
    -printf '%f -> %p\n' 2>/dev/null |
    sort

kernel-install inspect
```

For this tutorial, you should see this general order:

```text
50-mkinitcpio.install
60-ukify.install
90-uki-copy.install
91-sbctl.install
```

The update chain is:

```text
Kernel package update
        ↓
mkinitcpio builds the initramfs
        ↓
systemd-ukify assembles the UKI
        ↓
90-uki-copy installs it in /efi/EFI/Linux
        ↓
91-sbctl signs the installed UKI
```

The final UKI filename contains the kernel version, so every kernel update creates a new filename. The sbctl `kernel-install` plugin signs that new file automatically.

However, you should still verify after every update before rebooting:

```zsh
sudo sbctl verify
```

**Never blindly assume that an automatic hook succeeded.**

---

### 14) Add a Secure Boot check to Topgrade

Open your Topgrade configuration:

```zsh
topgrade --edit-config
```

Locate the existing `[post_commands]` section.

Do not create a second `[post_commands]` header if one already exists.

Add:

```toml
[post_commands]
"Verify Secure Boot chain" = "sudo sbctl status && mokutil --sb-state && sudo sbctl verify || { printf '%s\n' 'SECURE BOOT VERIFICATION FAILED. DO NOT REBOOT.' >&2; exit 1; }"
```

Now every Topgrade run will finish by checking:

* Whether Secure Boot is enabled
* Whether Setup Mode remains disabled
* Whether every EFI boot file and UKI is signed

If verification fails, do not reboot until you fix the unsigned file.

---

### 15) What to do if a future UKI is unsigned

Run:

```zsh
sudo sbctl verify
```

Find the exact unsigned path in the output, then sign it:

```zsh
sudo sbctl sign --save '/efi/EFI/Linux/EXACT-UNSIGNED-FILENAME.efi'
sudo sbctl verify
```

Only reboot after it reports that every required EFI file is signed.

---

#### 16a) Resume BitLocker after Windows boots successfully

This step is only if you have another partition with Windows on it, if not skip to 16b. You may now reboot back into the Windows partition with SecureBoot on to confirm that it works. If you use BitLocker and turned it off at the beginning you must launch `cmd` as an Administrator and re-enable it, but again, **ONLY** if you had BitLocker on and disabled it:

```bat
manage-bde -protectors -enable C:
```

Then confirm:

```bat
manage-bde -status C:
```

You want the Windows drive to report:

```text
Protection Status: Protection On
```

**When protection is resumed, BitLocker seals its key against the new valid boot measurements.**

#### TROUBLESHOOT: If Windows asks for the recovery key

This does not necessarily mean Windows or the encryption is broken.

Changing the Secure Boot configuration can change the TPM measurements that BitLocker uses to validate the boot environment. Enter the previously saved 48-digit recovery password.

Once Windows starts, resume or reset BitLocker protection so that it accepts the new Secure Boot measurements:

```bat
manage-bde -protectors -enable C:
```

#### TROUBLESHOOT: If Windows is rejected by the firmware

Enter the firmware and temporarily **disable Secure Boot only**.

Do not clear the keys again.

Boot Arch and inspect the trusted database:

```zsh
sudo efi-readvar -v db
```

If Microsoft certificates are absent, return the firmware to Setup Mode and enroll again using:

```zsh
sudo sbctl enroll-keys --microsoft
```

**DO NOT** manually modify or privately re-sign `bootmgfw.efi`. Windows Boot Manager should remain signed, maintained and serviced by Microsoft.

---

### 16b) OPTIONAL: Update the Secure Boot dbx revocation database

The `dbx` database prevents known vulnerable EFI programs and bootloaders from starting. After you enable SecureBoot on Linux you may see a new firmware update available when running fwupd for SecureBoot.

This is because your firmware may have an old dbx even if your BIOS itself has no available update.

To check, install and start fwupd if you have not already:

```zsh
sudo pacman -S --needed fwupd
sudo systemctl enable --now fwupd.service
```

Refresh its metadata:

```zsh
sudo fwupdmgr refresh
fwupdmgr get-updates
```

If it offers a **UEFI dbx** update, first verify your current boot chain:

```zsh
sudo sbctl verify
```

#### Check the battery and charger state

If you are on a laptop the firmware update might refuse to continue if the battery is under a certain treshold, regardless of if you are charging or not.

```zsh
sudo fwupdtool get-report-metadata 2>/dev/null |
    grep -E '^(BatteryLevel|BatteryThreshold|PowerState):'
```

You want:

* `PowerState: ac`
* `BatteryLevel` equal to or higher than `BatteryThreshold`

When that is met you can proceed to install, just keep the charging cable connected during the update. Power failures during firmware updates is a good way to brick your computer.

Now you can evaluate if you want this update or not. If you choose to install this firmware update, then install and apply it like this:

```zsh
sudo fwupdmgr update
```

Read the update description CAREFULLY before accepting it. Ensure it is the UEFI dbx update you expected.

Reboot when requested:

```zsh
systemctl reboot
```

After booting:

```zsh
sudo sbctl status
mokutil --sb-state
sudo sbctl verify

fwupdmgr get-history
fwupdmgr check-reboot-needed

fwupdmgr get-devices |
    grep -A12 -F 'UEFI dbx'
```

You want the history to report:

```text
Update State: Success
```

and:

```text
No reboot is necessary
```

fwupd uses date-formatted dbx versions, so a large-looking jump such as `20220801` to a much newer date is not automatically suspicious. dbx releases are cumulative enough for fwupd to support direct upgrades.

The dbx payload is written while Linux is running but becomes active after restarting.

---

### 17) TROUBLESHOOT: Older computers and limited EFI NVRAM

Sometimes after a `dbx` update if your computer is very old it may say it "failed" due to hitting a limit on the size requirements of your EFI variable storage. This storage is **NOT** your EFI System Partition, as confusing as that may be. The EFI System Partition and EFI variable storage are two completely different things:

```text
/efi
```

is a normal partition on your SSD.

```text
/sys/firmware/efi/efivars
```

while this is a small amount of nonvolatile storage built into your motherboard firmware.

**Making your `/efi` larger will not increase the firmware’s variable storage.**

Check the firmware-reported usage with:

```zsh
sudo fwupdtool get-report-metadata 2>/dev/null |
    grep -E 'EfivarsNvram(Free|Used)'
```

If fwupd reports that there is not enough efivarfs space:

* **Do not delete random files from `/sys/firmware/efi/efivars`**
* **Do not delete `dbx`**
* **Do not clear your Secure Boot keys**
* **Do not force the update**
* **Do not resize the ESP expecting it to help**

A complete shutdown and cold power cycle may allow old firmware to garbage-collect replaced EFI variables. Shut your laptop down with:

```zsh
systemctl poweroff
```

Then wait until the machine is fully powered off, and finally start it again and recheck the free space. This is not a guarantee however, and it is probable that it will still report size issues and an "update failure"

But this "failure" report should not be taken as gospel, since if a dbx update still reports success and the new version is shown after reboot, the update worked even if fwupd warns that there is not enough space for another future write. Yes its very annoying, however in the future `dbx` updates will most likely fail due to space requirements. The sad report to give here is that there is really nothing you can do about this. The last `dbx` should be treated as the ceiling for the security of w/e hardware you are using. Take whatever precautions necessary in response, which includes getting a new laptop.



### Troubleshooting For Secure Boot In General

#### Secure Boot is gray in the BIOS

Disable Legacy Boot or CSM first.

On some systems, the option is commonly called **Legacy Support**.

#### `sbctl` says it is not installed after installing the package

This normally means its key hierarchy has not been created yet:

```zsh
sudo sbctl create-keys
```

#### `sbctl verify` says `db.key` does not exist

The keys have not been created yet:

```zsh
sudo sbctl create-keys
```

#### The machine will not boot after enabling Secure Boot

Enter the firmware and disable Secure Boot.

Do not clear the enrolled keys.

Boot Arch, run:

```zsh
sudo sbctl verify
```

and sign whatever required file was missed.

#### A kernel update finishes with an unsigned UKI

Do not reboot.

Sign the exact new UKI:

```zsh
sudo sbctl sign --save '/efi/EFI/Linux/EXACT-FILENAME.efi'
sudo sbctl verify
```

#### Secure Boot works, but the root filesystem is still readable from another computer

That is expected.

Secure Boot verifies the boot chain. It does not encrypt the SSD.

Use LUKS encryption for protection against offline access to your files.


_____

## EXTRA TUTORIAL: How to add a new Drive/SSD to GPT-Auto Setups with systemd-repart

Name of drive will be `data`.
Replace ALL instances of `data` in this guide if you don't want that name for your drive.
And by all I mean ALL instances, even in the `.mount` and `.automount` files.

#### 0) Identify the new disk, double check before you write to it

```zsh
lsblk -e7 -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL
DEV=/dev/nvme1n1    # <-- set this to your new disk
```

#### 1) Create one GPT Linux data partition with systemd-repart

```zsh
# WARNING: --empty=force is destructive.
# It creates a fresh partition table and existing partitions do not survive.
# Save data on disk first.

sudo rm -rf /tmp/repart-data.d
sudo mkdir -p /tmp/repart-data.d

sudo tee /tmp/repart-data.d/10-data.conf >/dev/null <<'EOF_REPART'
[Partition]
Type=linux-generic
Label=data
Format=ext4
SizeMinBytes=1G
EOF_REPART

# Preview the plan first. Without --dry-run=no, systemd-repart only shows what it would do.
sudo systemd-repart --definitions=/tmp/repart-data.d --empty=force "$DEV"

# Apply it for real.
sudo systemd-repart --definitions=/tmp/repart-data.d --dry-run=no --empty=force "$DEV"

# Let udev create /dev/disk/by-* symlinks.
sudo udevadm settle
```

#### 2) Verify the partition and filesystem labels

```zsh
lsblk -f "$DEV"
ls -l /dev/disk/by-partlabel/ | grep ' data$' || true
ls -l /dev/disk/by-label/ | grep ' data$' || true
```

`systemd-repart` already made the ext4 filesystem because the repart file used `Format=ext4`, so do **not** run `mkfs.ext4` separately here.

#### 3) Create the mount point

```zsh
sudo mkdir -p /mnt/data
```

#### 4) Create a native systemd mount unit

```zsh
sudo nano /etc/systemd/system/mnt-data.mount
```

Add:

```ini
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

#### 5) Create an automount for on-demand mounting

```zsh
sudo nano /etc/systemd/system/mnt-data.automount
```

Add:

```ini
[Unit]
Description=Auto-mount /mnt/data

[Automount]
Where=/mnt/data

[Install]
WantedBy=multi-user.target
```

#### 6) Enable it

```zsh
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-data.automount
```

#### 7) Test

```zsh
systemctl status mnt-data.automount
df -h /mnt/data
touch /mnt/data/it-works
```

