# Installing from SystemRescue

[Return to the installation guide](../../arch_kde_tutorial.md#optional-using-systemrescue-to-install).

The main guide assumes the official Arch ISO. I sometimes use [SystemRescue](https://www.system-rescue.org/) instead because its XFCE desktop lets me browse documentation and copy configuration examples during installation.

I recommend the official ISO for a first installation. Use this alternative once you are comfortable with the process.

## Start the live environment

Write SystemRescue to a USB drive and boot it. Start XFCE with `startx`, then configure the keyboard and network through the desktop.

Open a terminal and sync the package databases using SystemRescue's rolling repository configuration:

```sh
pacman --config=/etc/pacman-rolling.conf -Sy
```

Follow the main guide, using its SystemRescue-specific Reflector and pacstrap commands.

## Install the base system

Use the rolling configuration for pacstrap:

```sh
pacstrap -C /etc/pacman-rolling.conf -K /mnt base nano sudo
```

## Partition device reported as busy

The original workaround is to ask the kernel to reread the selected disk's partition table, then retry the partitioning step. Confirm the disk name with `lsblk -l` first. For the NVMe example:

```sh
partprobe /dev/nvme0n1
```
