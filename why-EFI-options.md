I mount the EFI like this:

```zsh
mkdir -p /mnt/efi
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

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
