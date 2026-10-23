# Kernel command-line options

[Return to the installation guide](../../arch_kde_tutorial.md#49-install-ukis-and-configure-the-boot-loader).

These options are embedded in the UKIs from `/etc/kernel/cmdline`. This supporting example uses `lz4`; the main installation guide uses `zstd`. Choose the compressor deliberately when reviewing your settings.

```text
rw rootflags=noatime nowatchdog loglevel=3 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=30
```

| Option | Purpose |
|---|---|
| `rw` | Request a writable root filesystem. |
| `rootflags=noatime` | Pass the root mount option through the kernel command line in this GPT-discovery setup. Separate additional root options with commas and no spaces. |
| `nowatchdog` | Disable watchdogs as a performance-oriented choice. Review the diagnostic tradeoff for your system. |
| `loglevel=3` | Set the console logging threshold. |
| `zswap.enabled=1` | Explicitly enable Zswap. |
| `zswap.shrinker_enabled=1` | Enable the Zswap shrinker. |
| `zswap.compressor=lz4` | Select LZ4 compression for this example. |
| `zswap.max_pool_percent=30` | Set the Zswap pool limit as a percentage of RAM. |

I keep the Zswap settings explicit so the intended setup remains visible when changing kernels. If you switch to a Zram setup, review whether to disable Zswap with `zswap.enabled=0` rather than keeping both configurations by accident.
