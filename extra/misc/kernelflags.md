# Kernel cmdline Options

This document explains my options in the tutorial.

```zsh
## /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=30
```

With systemd-gpt-auto-generator you need to use `rootflags=` in cmdline to add options to the root filesystem, for this I only have one which is:
* `noatime` which is a typical optimization for EXT4 systems. To add more in the future you seperate them with commas **without space**, like: `foo,bar` if foo and bar were two settings.


`nowatchdog` is also optimization, but its a system tweak. Both `noatime` and `nowatchdog` serve similar purposes though, they remove hardening defaults that are unneeded for single use desktops.

Basically, they are on by default for kernel default reasons only.
Many distros ship with nowatchdog and noatime as a general rule, EndeavorOS for example.

If you really are worried about if you need them (you probably dont) then you can
research them independently

`loglevel=3` just increases verbosity in logging. Good for troubleshooting.

`zswap.compressor=lz4` switches compressor to lz4 from zstd, lz4 is considered faster. All you need to know is that it helps your swapping.
All the other zswap settings other than `zswap.compressor=lz4` are default on Arch native kernels so they are technically redundant.
However, I included them to ensure they are loaded regardless, like say you ever use a kernel that's not from Arch or a fork of Arch's kernels like CachyOS's kernels and forget that it won't enable your zswap.
