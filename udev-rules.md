
### Optional Udev rules

udev is Linux’s device manager.  It reacts to hardware events, such as a disk being added or changed, and applies matching rules from .rules files. This can help tweak the system behavior to your liking. Rule files are processed in lexical order, so the numeric prefix in `60-ioschedulers.rules` for example controls when this rule is evaluated relative to other udev rules. 

These are optional/hardware specific. You can pick the ones you want or none of them.

#### OPTIONAL: 71-nvidia.rules

This rule enables PCI runtime power management for NVIDIA VGA/3D controller devices when the NVIDIA driver binds to the GPU, then switches it back to on when the driver unbinds. In practice, it allows a supported idle NVIDIA GPU to enter lower power states instead of staying fully awake all the time. This is most useful on hybrid/on-demand GPU setups, laptops, or desktops where the NVIDIA GPU is not constantly driving displays.

What to expect: lower idle power and heat when the GPU is unused, but little or no benefit if your monitors are connected to the NVIDIA GPU, if a CUDA workload is running, or if desktop rendering keeps the GPU active. NVIDIA’s runtime D3 power management also depends on hardware, ACPI, kernel, and GPU support. NVIDIA documents support for Turing or newer GPUs, kernel 4.18 or newer, and working PCI runtime power management support.

Optional: Only for NVIDIA users / Users with compatible NVIDIA cards

```zsh
# Create folder
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/71-nvidia.rules /etc/udev/rules.d/71-nvidia.rules

# Manually:
# Add conf
nano /etc/udev/rules.d/71-nvidia.rules
```

```conf
# /etc/udev/rules.d/71-nvidia.rules
# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
    ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
    TEST=="power/control", ATTR{power/control}="auto"

# Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
    ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
    TEST=="power/control", ATTR{power/control}="on"
```

#### OPTIONAL: 40-hpet-permissions.rules

This rule gives the audio group access to the system timer devices /dev/rtc0 and /dev/hpet. RTC means real-time clock, and HPET means High Precision Event Timer. Some older or specialized audio, MIDI, FireWire, and timing-sensitive tools may try to access these devices directly for precise timing.

Why do it: on systems or tools that still need these timer devices, group access avoids running audio tools as root just to open a timing device. The Linux kernel documents RTC devices as hardware clocks that can provide alarms and interrupts, and HPET as a high precision timer interface with a userspace API similar to RTC.

What to expect: usually nothing obvious on modern PipeWire/JACK systems unless a tool specifically needs RTC or HPET access. It is a compatibility/permissions rule.

OPTIONAL: Only if you added yourself to the audio group and have enabled other low latency audio work.

```zsh
# Create folder if not already
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/40-hpet-permissions.rules /etc/udev/rules.d/40-hpet-permissions.rules

# Manually:
# Add conf
nano /etc/udev/rules.d/40-hpet-permissions.rules
```

```conf
# /etc/udev/rules.d/40-hpet-permissions.rules
KERNEL=="rtc0", GROUP="audio"
KERNEL=="hpet", GROUP="audio"
```

#### OPTIONAL: 69-hdparm.rules

This rule applies hdparm settings to rotational ATA hard drives when they are added or changed. The -B 254 option sets Advanced Power Management to its highest performance-oriented value while still using the drive’s APM feature, and -S 0 disables the automatic standby/spindown timeout. In plain terms, it tells matching HDDs: prioritize responsiveness, do not aggressively park or spin down.

Why do it: this can reduce annoying drive wake-up delays, avoid repeated spin-up/spin-down behavior, and help keep desktop or media workloads responsive on HDDs. It may also reduce excessive load/unload cycles on drives that park too aggressively. The tradeoff is higher power use, more heat, and possibly more noise, because the disk is less likely to enter low-power states. hdparm documents -B as controlling Advanced Power Management, where higher values favor performance, and -S 0 as disabling the automatic standby timeout.

What to expect: HDDs should feel more immediately available after idle periods. **This does not apply to SSDs or NVMe drives because the rule only targets rotational ATA disks.**

**WARNING/OPTIONAL: Only for HDD users**


```zsh
# Create folder if not already
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/69-hdparm.rules /etc/udev/rules.d/69-hdparm.rules

# Manually:
# Add conf
nano /etc/udev/rules.d/69-hdparm.rules
```

```conf
# /etc/udev/rules.d/69-hdparm.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
    ATTRS{id/bus}=="ata", RUN+="/usr/bin/hdparm -B 254 -S 0 /dev/%k"
```

#### OPTIONAL: 50-sata.rules

This rule sets SATA Active Link Power Management to max_performance for supported SATA host controllers. ALPM saves power by putting the SATA link into lower power states during idle periods, then waking it when I/O returns. Setting `max_performance` disables that link power saving and prioritizes latency and stability instead.

Why do it: this can help avoid SATA latency spikes, drive wake delays, or rare compatibility issues caused by aggressive link power saving. It is most useful on desktops, workstations, audio systems, gaming systems, and always-plugged-in machines where responsiveness matters more than saving a small amount of power.

What to expect: SATA disks and SSDs may respond more consistently after idle time. The downside is slightly higher power consumption, especially on laptops.

OPTIONAL: Only for SATA SSDs and desktops, **not laptops if you care about battery life.**

```zsh
# Create folder if not already
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/50-sata.rules /etc/udev/rules.d/50-sata.rules

# Manually:
# Add conf
nano /etc/udev/rules.d/50-sata.rules
```

```conf
# /etc/udev/rules.d/50-sata.rules
# SATA Active Link Power Management
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
    ATTR{link_power_management_supported}=="1", \
    ATTR{link_power_management_policy}=="*", \
    ATTR{link_power_management_policy}="max_performance"
```

---
