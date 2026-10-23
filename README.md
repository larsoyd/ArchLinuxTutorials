# Arch Linux with KDE Plasma Tutorial (v2.0.0)

A rewritten and improved guide to installing Arch Linux with KDE Plasma, Wayland, and automatic GPT partition discovery. Still opinionated, but way easier to both read and follow now. I use this setup for my own gaming, dev and daily desktop work.

## Start here

1. [Installation tutorial](arch_kde_tutorial.md): partition the disk, install Arch, and configure the system from the live environment and chroot.
2. [Post-install tutorial](arch_kde_post_tutorial.md): configure the desktop, install applications, and set up maintenance after the first boot. Optional, but recommended.

You need a bootable Arch Linux USB, an internet connection, and a UEFI system. The examples lean towards an AMD CPU, a NVIDIA GPU (Turing architecture or later only), and an NVMe SSD. Any major deviation from this is not officially supported and puts you in "here be dragons" territory. Read the installation guide's hardware notes and replace its example disk, username, hostname, and regional settings before running commands.

## Supporting guides

| Topic | Guides |
|---|---|
| Installation choices | [Packages](extra/misc/pkgchoices.md), [EFI mount options](extra/misc/why-EFI-options.md), [SystemRescue](extra/misc/systemrescue.md) |
| Kernel and hardware settings | [Kernel command line](extra/misc/kernelflags.md), [Sysctl and module settings](extra/misc/kernel-settings.md), [udev rules](extra/tutorials/udev-rules.md) |
| AUR packages | [How to read a PKGBUILD](extra/tutorials/pkgbuild.md) |
| Desktop and recovery | [KDE preferences](extra/misc/misc.md), [REISUB](extra/misc/REISUB.md), [mkinitcpio warnings](extra/tutorials/mkinitcpio-fix.md) |
| Storage and boot security | [New drives](extra/tutorials/newdrive.md), [Secure Boot](extra/tutorials/secureboot.md), [LUKS encryption](extra/tutorials/luks.md) |
| Hardware workarounds | [Apple fast charging](extra/tutorials/applefastcharge.md), [NVIDIA GSP patch](patches/nvidia-gsp.md) |

The guides link to reusable files in [configs](configs/), [scripts](scripts/), and [rules.d](rules.d/). Review the relevant guide before installing them.

## Licenses

Code is licensed under the [MIT License](LICENSE). Markdown text is licensed under [Creative Commons Attribution-ShareAlike 4.0 International](CREATIVE-LICENSE).
