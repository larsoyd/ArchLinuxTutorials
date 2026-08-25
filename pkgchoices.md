
> Click [HERE](https://github.com/larsoyd/ArchLinuxTutorials/blob/main/arch_kde_tutorial.md#46-install-the-system) to go back to the tutorial.

### pkgstats 
**This** is the most "controversial" one, but here is why it shouldn't be: pkgstats is a super harmless way to help out the Arch developers that work hard and mostly for free to make our wonderful distro.
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

### audiocd-kio
This adds the audiocd:/ KIO worker so Dolphin and other KDE apps can read and rip audio CDs. Not needed on non-KDE Plasma systems, but KDE has their own thing for this. If you are on a laptop with a CD player and/or ever need to play audio CDs on your PC then you are going to want this.

### libdvdread, libdvdnav, and libdvdcss
This is the same as above but for DVD playback. 

### libbluray and libaacs
Same for Blu-Rays. After you have installed the system and configured an AUR helper you may also wish to install **libbdplus** from the AUR if you want for BD+ playback. From there you will have to set it up with KEYS which is shown on the Arch Wiki about Blu-Ray.

### bluez and bluez-utils
For Bluetooth support if you use Bluetooth. You will also need to enable `bluetooth.service` then at the end of the tutorial.

### cups & cups-pdf (Optional: bluez-cups for Bluetooth printers)
If you need printer support. You will also need to enable `cups.service` at the end of the tutorial. For GUI support you need to also install `system-config-printer` & `cups-pk-helper`. For SMB browser support you need `python-pysmbc` and to be able to browse the network for remote CUPS queues and IPP network printers you also probably need `cups-browsed`
