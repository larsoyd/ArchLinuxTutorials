
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

#### OPTIONAL: 20-audio-pm.rules

This rule changes the `snd_hda_intel` audio power-saving timeout depending on whether the system is connected to external power. FYI: Even though it says "intel" in it's name it is unrelated to if you use an AMD or Intel CPU/GPU or not. You can check if your computer uses this timeout mechanism with: `cat /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || echo "Not relevant"`. If it returns `Not Relevant` you may skip this rule. 

When the HDA audio device is first detected while the system is not discharging, the rule saves the current `power_save` value under `/run/udev/` and sets it to `0`. A value of `0` disables automatic audio codec power-down. When external power is disconnected, the rule restores the previously saved timeout, or uses a fallback of 10 seconds if no value was saved. When external power returns, it saves any active non-zero timeout and disables power saving again.

Why do it: `snd_hda_intel` can power down an idle audio codec to reduce energy use. However, waking the codec again may introduce a short delay or audible clicking and popping on some hardware. If you have this classic type of issue on Linux which is an audio issue it drives you nuts trying to fix it. This can be an issue on both desktops and laptops, but the issue is on laptops if this is turned off by default it affects battery life, so this rule provides a good compromise: keep the audio device awake for consistent responsiveness while plugged in, while retaining the system's previous power-saving timeout on battery.

What to expect: audio may respond more consistently after idle periods while connected to external power, especially on systems that experience pops, clicks, missing initial audio, or wake-up delays. The tradeoff is slightly higher idle power consumption while plugged in. On battery, power saving only remains enabled if the saved timeout was non-zero. The kernel notes that entering or leaving the audio power-saving state can itself produce click or pop noises and may take some time.

**OPTIONAL: Only for systems using `snd_hda_intel` and it's power save feature. But if you have it, it's a pretty good rule to enable by default TBH. Mind the caveats though.**

```zsh
# Check whether this rule is relevant
# Not relevant means the active kernel does not expose the required snd_hda_intel parameter.
cat /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || echo "Not relevant"

# Create folder if not already
mkdir -p /etc/udev/rules.d

# Auto (if repo cloned)
cp /tmp/ArchLinuxTutorials/20-audio-pm.rules /etc/udev/rules.d/20-audio-pm.rules

# Manually:
# Add conf
nano /etc/udev/rules.d/20-audio-pm.rules
```

```conf
# /etc/udev/rules.d/20-audio-pm.rules
# Disable HDA audio power saving on external power and restore it on battery

ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", \
    RUN+="/usr/bin/bash -c 'touch /run/udev/snd-hda-intel-powersave; \
        [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && \
        echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave && \
        echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"

SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", \
    RUN+="/usr/bin/bash -c 'echo $$(cat /run/udev/snd-hda-intel-powersave 2>/dev/null || \
        echo 10) > /sys/module/snd_hda_intel/parameters/power_save'"

SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", \
    RUN+="/usr/bin/bash -c '[[ $$(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]] && \
        echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave; \
        echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
```

---
