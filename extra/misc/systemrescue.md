### OPTIONAL: Using SystemRescue To Install

While in this tutorial I will be assuming you are using the official ArchISO Installation Medium, I must concede that after installing Arch via the official medium for years I now instead opt for a live environment for my own convenience. Basically what this means is that I install Arch from another distro, and I choose the LiveISO maintenance distro [SystemRescue](https://www.system-rescue.org/) which is based on Arch and comes with the installation scripts and reflector pre-installed for maximum convenience. 

The **PROS** behind this is that you can open up a browser and copy + paste whatever config you want to push to your live environment before installation (e.g. someone else's intricate dots) from the internet without having to use hacky terminal commands that you may either not know or just not like (me). 
Every step except for one is the same, but if this is your first time **I strongly recommend not doing this**. 

This is **only** if you already have a gist on how to install Arch and you don't want to use the TUI.
The way to do this is to flash SystemRescue on a USB and then start the XFCE desktop of SystemRescue with startx. From there a Windows-like riced XFCE will pop up, allowing you to modify your keyboard settings if you need to for different locals and connect to the internet which allows you to skip all the connecting to internet steps from the tutorial proper.
Then you open up a terminal in SystemRescue and write: `pacman --config=/etc/pacman-rolling.conf -Sy` to install the current pacman.conf instead of the snapshot version SystemRescue ships with. 

From there you simply follow the tutorial exactly as written until you get to the  `pacstrap` step. On that step you should instead write: `pacstrap -C /etc/pacman-rolling.conf -K /mnt base nano sudo` in order to pacstrap with the new config. 
If the step to partition with systemd-repart fails due to a device being "in use", you can write `partprobe` on the disk from `lsblk -l` that you are partitioning. E.g: `partprobe /dev/nvme0n1` or simply run the command again and it should work.

- **If you do choose SystemRescue, again, remember to write `pacman --config=/etc/pacman-rolling.conf -Sy` in the XFCE terminal before starting the tutorial.**
