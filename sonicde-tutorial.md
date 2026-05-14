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
