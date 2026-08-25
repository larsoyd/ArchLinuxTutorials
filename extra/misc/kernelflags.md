> Click [HERE](https://github.com/larsoyd/ArchLinuxTutorials/blob/main/arch_kde_tutorial.md#48-install-ukis-and-configure-bootloader) to go back to the tutorial.

# Kernel cmdline Options

This document explains my options in the tutorial. `rw` is necessary as said, but the other flags are ones I use as defaults on any system. With `systemd-gpt-auto-generator` you need to use `rootflags=` in cmdline to add options to the root filesystem which you would otherwise use `fstab` for.


```zsh
## /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=30
```
  
* `noatime` is the only root flag here, its a typical optimization for Linux systems that removes a security default which general users are not going to benefit from. To add more in the future you seperate them with commas **without space**, like: `foo,bar` if foo and bar were two settings.

* `nowatchdog` is also an optimization, but its a system tweak. Both `noatime` and `nowatchdog` serve similar purposes though, they remove hardening defaults that are unneeded for single use desktops. - Basically, they are on by default for kernel default reasons only. Many distros ship with nowatchdog and noatime as a general rule, EndeavorOS for example. - If you really are worried about if you need them (you probably dont) then you can research them independently

* `loglevel=3` just increases verbosity in logging. Good for troubleshooting.

* `zswap.compressor=lz4` switches compressor to lz4 from zstd, lz4 is considered faster. All you need to know is that it helps your swapping.
All the other zswap settings other than `zswap.compressor=lz4` are default on Arch native kernels so they are technically redundant. This includes `zswap.enabled=1` btw meaning every Arch kernel enables `zswap` by default unless told otherwise. This is something a lot of people do not know, so if you ever want to switch to `zram` in the future you need to explicitly add `zswap.enabled=0` to your `cmdline`, otherwise they will both fight over swapping which can cause issues. - However, I included all of them regardless if they were on or not in the Arch kernels to ensure they are loaded regardless, this is good for situations in the future where you may use a kernel that's not from Arch or a fork of Arch's kernels like CachyOS's kernels for w/e reason, if you do you will most definately forget that you need to enable zswap in the kernel cmdline, and thus be without a swap device which is a bad idea.
