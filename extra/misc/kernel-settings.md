# Sysctl and module settings

[Return to the installation guide](../../arch_kde_tutorial.md#kernel-and-desktop-settings).

These are the settings shipped with this guide, including choices adapted from CachyOS. Review them for your hardware and workload before copying the files.

## Sysctl settings

[70-settings.conf](../../configs/70-settings.conf) is installed in `/etc/sysctl.d/`. Its values are applied at boot and can be loaded with `sysctl --system`.

| Setting | Purpose of this configuration |
|---|---|
| `vm.vfs_cache_pressure = 50` | Retain directory and inode caches more readily. Avoid setting this to zero, which can contribute to memory exhaustion. |
| `vm.dirty_bytes = 268435456` | Set the dirty-data threshold at which writing processes participate in writeback. |
| `vm.dirty_background_bytes = 67108864` | Set the threshold for background writeback. |
| `vm.dirty_writeback_centisecs = 1500` | Set the interval between periodic writeback checks, in hundredths of a second. |
| `vm.page-cluster = 1` | Control swap readahead. The original configuration suggests `1` for SSD-backed swap and `2` for a hard disk. |
| `kernel.nmi_watchdog = 0` | Disable the NMI watchdog. |
| `kernel.unprivileged_userns_clone = 1` | Allow unprivileged user namespaces. |
| `kernel.printk = 3 3 3 3` | Limit messages printed to the console. |
| `kernel.kptr_restrict = 2` | Restrict exposure of kernel pointers. |
| `kernel.kexec_load_disabled = 1` | Disable loading kernels through kexec. |
| `kernel.split_lock_mitigate = 0` | Disable split-lock mitigation for workloads such as games affected by it. |
| `net.core.netdev_max_backlog = 4096` | Increase the network receive backlog. |
| `fs.file-max = 2097152` | Raise the system-wide file handle limit. |
| `net.ipv4.tcp_congestion_control = bbr` and `net.core.default_qdisc = fq` | Pair BBR congestion control with the fair queue scheduler for pacing. |
| `vm.swappiness = 170` | Favour swapping anonymous memory relative to reclaiming file-backed pages. |
| `fs.inotify.max_user_instances = 8192` and `fs.inotify.max_user_watches = 524288` | Raise notification limits for applications that watch many files. |
| `vm.max_map_count = 2147483642` | Raise the mapping limit for applications and games that use many memory mappings. |

## Module settings

### NVIDIA

[nvidia.conf](../../configs/nvidia.conf) contains these options:

- `NVreg_UsePageAttributeTable=1`: enable the page attribute table memory attribute mechanism.
- `NVreg_InitializeSystemMemoryAllocations=0`: disable clearing system memory allocations before GPU use. This trades a possible performance benefit for increased security risk. Set it back to `1` to restore clearing.
- `NVreg_RegistryDwords=RmEnableAggressiveVblank=1`: defer work from low-latency display interrupts.
- `NVreg_DynamicPowerManagement=0x02`: enable dynamic power management, including idle power-down on supported mobile GPUs.
- `NVreg_EnableS0ixPowerManagement=1`: enable S0ix power management on supported hardware during suspend-to-idle.

Hardware and driver support matter for these options. The installation guide copies the file to `/etc/modprobe.d/20-nvidia.conf`.

### AMDGPU

[amdgpu.conf](../../configs/amdgpu.conf) selects AMDGPU instead of Radeon for Southern Islands and Sea Islands hardware. It is installed as `/etc/modprobe.d/21-amdgpu.conf`.

### Watchdog blacklist

[blacklist.conf](../../configs/blacklist.conf) blocks the Intel TCO and AMD SP5100 watchdog modules. It is installed as `/etc/modprobe.d/22-blacklist.conf`.
