# EFI mount options

[Return to the installation guide](../../arch_kde_tutorial.md#step-2-mount-filesystems).

I mount the EFI System Partition with these options:

```zsh
mkdir -p /mnt/efi
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

VFAT does not store Unix permissions. The masks supply them when the filesystem is mounted:

| Option | Effect |
|---|---|
| `fmask=0177` | Files appear with mode `600`: root can read and write them. |
| `dmask=0077` | Directories appear with mode `700`: root can access them. |
| `noexec` | Prevent execution of programs from this mount. |
| `nodev` | Do not interpret files on this mount as device nodes. |
| `nosuid` | Ignore setuid and setgid bits. |

These restrictions apply to access through the mounted filesystem.
