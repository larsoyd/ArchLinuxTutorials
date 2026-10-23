# Optional udev rules

[Return to the installation guide](../../arch_kde_tutorial.md#udev-rules).

Udev applies rules when devices are added, removed, or changed. Files are processed in filename order. These examples are hardware-specific; install only the ones you want.

Run installation commands as root, as in the main guide’s chroot. Each section offers a copy method and a manual method. Choose one.

## 20-audio-pm.rules

This rule is for systems using `snd_hda_intel`, which is not limited to Intel CPUs. Audio power saving can cause pops, clicks, or delayed playback when an idle codec wakes.

The rule disables audio power saving on external power and restores the saved timeout on battery. This may improve responsiveness while plugged in, at the cost of higher idle power use. Battery power saving remains enabled only if the saved timeout was nonzero.

Check whether the running kernel exposes the parameter. If the command prints `Not relevant`, skip this rule.

```zsh
cat /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || echo "Not relevant"
```

Create the directory:

```zsh
mkdir -p /etc/udev/rules.d
```

**Copy the supplied file**, if the repository is cloned at `/tmp/ArchLinuxTutorials`:

```zsh
cp /tmp/ArchLinuxTutorials/rules.d/20-audio-pm.rules /etc/udev/rules.d/20-audio-pm.rules
```

**Or create it manually:**

```zsh
nano /etc/udev/rules.d/20-audio-pm.rules
```

For the manual option, use these contents:

```udev
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

## 71-nvidia.rules

This enables PCI runtime power management when the NVIDIA driver binds to a graphics device and disables it when the driver unbinds.

It is mainly useful for supported hybrid or on-demand GPU setups where NVIDIA can sit idle. Expect little benefit if the GPU drives your monitors or is busy with rendering or CUDA work. Support depends on the GPU, firmware, kernel, and PCI runtime power management. The original setup targets Turing or newer GPUs and kernel 4.18 or newer.

Create the directory:

```zsh
mkdir -p /etc/udev/rules.d
```

**Copy the supplied file**, if the repository is cloned at `/tmp/ArchLinuxTutorials`:

```zsh
cp /tmp/ArchLinuxTutorials/rules.d/71-nvidia.rules /etc/udev/rules.d/71-nvidia.rules
```

**Or create it manually:**

```zsh
nano /etc/udev/rules.d/71-nvidia.rules
```

For the manual option, use these contents:

```udev
# Enable runtime PM for NVIDIA graphics devices on driver bind
ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
    ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
    TEST=="power/control", ATTR{power/control}="auto"

# Disable runtime PM for NVIDIA graphics devices on driver unbind
ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", \
    ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", \
    TEST=="power/control", ATTR{power/control}="on"
```

## 69-hdparm.rules

This applies only to rotational ATA hard drives. `-B 254` favours performance within the drive's Advanced Power Management feature, and `-S 0` disables automatic standby.

I use it to avoid wake-up delays and repeated spin-downs. The tradeoffs are higher power consumption, heat, and possibly noise. It does not target SSDs or NVMe drives.

Create the directory:

```zsh
mkdir -p /etc/udev/rules.d
```

**Copy the supplied file**, if the repository is cloned at `/tmp/ArchLinuxTutorials`:

```zsh
cp /tmp/ArchLinuxTutorials/rules.d/69-hdparm.rules /etc/udev/rules.d/69-hdparm.rules
```

**Or create it manually:**

```zsh
nano /etc/udev/rules.d/69-hdparm.rules
```

For the manual option, use these contents:

```udev
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
    ATTRS{id/bus}=="ata", RUN+="/usr/bin/hdparm -B 254 -S 0 /dev/%k"
```

## 50-sata.rules

This sets supported SATA host controllers to `max_performance`, disabling SATA link power saving.

It may help with wake-up delays, latency spikes, or compatibility problems. I prefer it on desktops where responsiveness matters more than power savings. Avoid it on a laptop if battery life is your priority.

Create the directory:

```zsh
mkdir -p /etc/udev/rules.d
```

**Copy the supplied file**, if the repository is cloned at `/tmp/ArchLinuxTutorials`:

```zsh
cp /tmp/ArchLinuxTutorials/rules.d/50-sata.rules /etc/udev/rules.d/50-sata.rules
```

**Or create it manually:**

```zsh
nano /etc/udev/rules.d/50-sata.rules
```

For the manual option, use these contents:

```udev
# SATA Active Link Power Management
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
    ATTR{link_power_management_supported}=="1", \
    ATTR{link_power_management_policy}=="*", \
    ATTR{link_power_management_policy}="max_performance"
```
