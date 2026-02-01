
Assumptions:

* You already have Arch installed
* You installed `gnome` group and `gdm`
* You have just booted into a stock GNOME Wayland session

Problem: If you use GNOME you probably prefer it's style, the issue however is many apps don't respect Libadwaita's themeing. This is not a problem 
for modern GTK4/GNOME first applications, but it is a problem for the odd GTK3 app or Qt applications. You can't get them to completely respect your
desktop appearance and any modification can always come with their own regressions, naturally, but if you are fine with those trade offs which you
probably will be FYI then you should do something about this. 

Goal: we want to make **GTK4, GTK3 and Qt apps** all look like they belong on the same desktop. For that we will use:

* **QAdwaitaDecorations** for Qt window decorations 
* **Darkly** as the Qt widget style (via `QT_STYLE_OVERRIDE=Darkly`) 
* **adw-gtk3** via `adw-gtk-theme` for GTK3 
* **MoreWaita** for icons 
* **Rounded Window Corners Reborn** to round everything
* Optional app specific themes for GIMP, Firefox, Steam, etc

**NB:** We explicitly do *not* use `adwaita-qt` since the ArchWiki now marks it as unmaintained and no longer actively developed.

---

## 1. Basic setup and tools

First thing on a fresh system: update and install basic tools.

```sh
sudo pacman -Syu
```

Install tools you will need:

```sh
sudo pacman -S --needed git base-devel gnome-tweaks extension-manager
```

Install an AUR helper (yay in this example):

```sh
mkdir -p ~/git
cd ~/git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd
```

Install some AUR helpers for rebuilds:

```sh
yay -S aurutils rebuild-detector
```

---

## 2. Qt: Adwaita style window decorations + Darkly widgets

### 2.1 Install QAdwaitaDecorations (Qt5 and Qt6)

QAdwaitaDecorations is a Qt decoration plugin that provides Adwaita like client side decorations for Qt apps on Wayland. 

```sh
yay -S qadwaitadecorations-qt5 qadwaitadecorations-qt6
```

This installs the Qt5 and Qt6 variants from AUR.

### 2.2 Install Darkly Qt style

Darkly is a modern Qt application style, a fork of Lightly that aims to be minimalistic and up to date. 

```sh
yay -S darkly-bin
```

### 2.3 Set Qt environment variables via systemd user environment

GNOME on Arch (with GDM) reads environment variables from `~/.config/environment.d/*.conf` for the user session. 

Create the directory if it does not exist:

```sh
mkdir -p ~/.config/environment.d
```

Create a Qt config file:

```sh
nano ~/.config/environment.d/10-qt-gnome.conf
```

Put only these lines inside (no `export` keyword):

```ini
QT_WAYLAND_DECORATION=adwaita
QT_STYLE_OVERRIDE=Darkly
```

Save and log out of GNOME then log back in.

Check in a terminal:

```sh
echo "$QT_WAYLAND_DECORATION"
echo "$QT_STYLE_OVERRIDE"
```

You should see:

```text
adwaita
Darkly
```

Result now:

* Qt Wayland apps use **QAdwaitaDecorations** for Adwaita like window decorations. 
* All Qt apps use **Darkly** as the widget style via `QT_STYLE_OVERRIDE=Darkly`. 

Note: QAdwaitaDecorations uses private Qt headers and normally needs to be rebuilt for major Qt updates, the AUR package description mentions this. 
You can manually run `checkrebuild` from `aurutils` after any update to check for rebuilds and if it lists any package, 
like say `foobar`, you need to write: `yay -S --rebuild foobar`

---

## 3. GTK3: adw-gtk-theme for “libadwaita in GTK3”

Install the GTK3 port of libadwaita:

```sh
sudo pacman -S adw-gtk-theme
```

The package description calls this an unofficial GTK3 port of the libadwaita theme. 

Set it for legacy apps via GNOME Tweaks:

1. Open **GNOME Tweaks**
2. Go to **Appearance → Legacy Applications**
3. Choose `adw-gtk3-dark`

Make sure in main GNOME Settings you also use **Adwaita-dark** as the global color scheme so everything lines up.

Now GTK3 apps will visually match your GTK4 libadwaita apps quite closely.


## 4. Icon theme: MoreWaita

MoreWaita is an expanded Adwaita style companion icon theme with extra icons for popular apps and MIME types, designed to complement GNOME Shells original Adwaita icons. 

Install from AUR (maintained by the upstream author):

```sh
yay -S morewaita-icon-theme
```

Enable it:

Open GNOME Tweaks:

* **Appearance → Icons → MoreWaita**

or via gsettings:

```sh
gsettings set org.gnome.desktop.interface icon-theme 'MoreWaita'
```

Result:

* Core GNOME apps still use Adwaita icons
* Third party apps like Firefox, Steam, VS Code etc get matching Adwaita style icons where provided 

---

## 8. Shell polish: Rounded Window Corners Reborn

Install the GNOME Shell extension from AUR:

```sh
yay -S gnome-shell-extension-rounded-window-corners-reborn
```

This is a maintained fork of the older Rounded Window Corners extension, described as adding rounded corners to all windows.

Enable it:

* Open the **Extensions** app
* Enable **Rounded Window Corners Reborn**

This will round corners even on apps that do not use GNOME client side decorations, which helps unify Qt, Electron and older apps with your libadwaita look. 

# 9. Fonts

First check the result of each command:

```sh
fc-match sans-serif
fc-match sans
fc-match monospace
```

If those already return “Adwaita Sans” and “Adwaita Mono”, then this is redundant. 
If not, make a directory for fontconfig customization in user folder and then add defaults:


```sh
mkdir -p  ~/.config/fontconfig/conf.d/
nano ~/.config/fontconfig/conf.d/99-adwaita-defaults.conf
```

Add:

```sh
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Adwaita Sans</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any"><string>sans</string></test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Adwaita Sans</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Adwaita Mono</string>
    </edit>
  </match>
</fontconfig>
```


Result:

* Any app that asks for generic sans, sans-serif and monospace fonts will now be styled correctly with Adwaita.
---

# Optional Apps:

## GIMP 3: adw-gimp3

`adw-gimp3` is an external theme that makes GIMP 3 look like a GNOME Adwaita style app. There are previews of it in the GNOME community that show a much more native looking GIMP UI. 

Install it:

```sh
yay -S --needed gimp
mkdir -p ~/git
cd ~/git
git clone https://github.com/dp0sk/adw-gimp3
cd adw-gimp3

mkdir -p ~/.config/GIMP/3.0/themes
cp -r adw-gimp3 ~/.config/GIMP/3.0/themes
cd ~
```

Configure inside GIMP:

1. Launch GIMP
2. Go to **Edit → Preferences → Theme** and select **adw-gimp3**
3. Go to **Edit → Preferences → Image Windows**

   * Enable **Merge menu and title bar**

Now GIMP looks much closer to a modern GNOME app instead of an old cross platform UI.

---

## Firefox: firefox-gnome-theme

`firefox-gnome-theme` is a GNOME theme for Firefox that follows the latest Adwaita style. 

Grab it:

```sh
yay -S --needed firefox
mkdir -p ~/git
cd ~/git
git clone https://github.com/rafaelmardojai/firefox-gnome-theme
cd firefox-gnome-theme
./scripts/auto-install.sh
cd
```

The GitHub page warns that this theme tweaks unsupported parts of the UI, so bugs should be reported to the theme first, not Firefox.

Result: Firefox chrome (tabs, headerbar, menus) looks like a native libadwaita window.

---

## Steam: Adwaita for Steam

`Adwaita-for-Steam` is advertised as a skin to make Steam look more like a native GNOME app. 

Install:

```sh
yay -S --needed steam
mkdir -p ~/git
cd ~/git
git clone https://github.com/tkashkin/Adwaita-for-Steam
cd Adwaita-for-Steam
./install.py
cd
```

The author notes that Steam updates can reset patched files so you may sometimes need to reinstall the skin.
Simply go back into `cd ~/git` and `cd Adwaita-for-Steam` then run `./install.py` again.

Together with QAdwaitaDecorations and rounded corners, Steam will look far less out of place.

---

At the end of this, on a fresh Arch GNOME:

* GTK4 apps use libadwaita
* GTK3 apps use adw-gtk3, so look consisten with libadwaita
* Qt apps use Adwaita like Window decorations and theme (Darkly)
* Any Optional App have a GNOME consistent style
* Icons are Adwaita plus MoreWaita extras
* All windows have rounded corners
