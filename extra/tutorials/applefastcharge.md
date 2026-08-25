## OPTIONAL: Enable iPhone Fast Charging on Linux with a udev Rule

What many do not know is that Linux is capable of fast charging iOS devices. This is set off by default, so here is how you can set up Linux to request fast charging for an iPhone or another supported Apple iOS device using the kernel's `apple-mfi-fastcharge` driver automatically with an udev rule.

### What this checks

The `charge_type` file usually reports one of these values:

```text
Trickle
Fast
```

- `Trickle` means Linux has not requested fast charging.
- `Fast` means Linux has requested fast charging.
- This does not measure real watts or amps. Use an inline USB power meter if you want to verify actual electrical draw.


The fix works by writing `Fast` to the kernel power-supply attribute:

```text
/sys/class/power_supply/apple_mfi_fastcharge*/charge_type
```

### 1. Plug in the iPhone

First plug the iPhone into a USB data-capable port. Open your phone and trust the computer.

Wait a few seconds.

### 2. Load the kernel module

Run:

```zsh
sudo modprobe apple-mfi-fastcharge
```

This should be harmless if the module is already loaded.

### 3. Check the current charge mode

Run:

```zsh
typeset -a charge_files
charge_files=(/sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N))

if (( ${#charge_files} == 0 )); then
  print -r -- "No apple_mfi_fastcharge charge_type file found."
  print -r -- ""
  print -r -- "Try these checks:"
  print -r -- "  sudo modprobe apple-mfi-fastcharge"
  print -r -- "  unplug and replug the iPhone"
  print -r -- "  sudo dmesg | grep -iE 'apple.*mfi|fastcharge|iphone'"
  exit 1
fi

for charge_file in "${charge_files[@]}"; do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Before the fix, you may see something like:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Trickle
```

Older kernels may use a path without the bus/device suffix:

```text
/sys/class/power_supply/apple_mfi_fastcharge/charge_type: Trickle
```

Both path styles are fine.

### 4. Manually enable fast charging once

Before adding the udev rule, test that the kernel attribute works manually:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "Setting $charge_file to Fast"
  print Fast | sudo tee "$charge_file" >/dev/null
done
```

### 5. Check whether the manual change worked

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Expected result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

If this does not change to `Fast`, the udev rule will not fix it either. Check the troubleshooting section first.

### 6. Create the udev rule

Create this file:

```zsh
sudo tee /etc/udev/rules.d/99-apple-mfi-fastcharge.rules >/dev/null <<'EOF'
# Enable fast charging for Apple iPhone/iPad devices handled by apple-mfi-fastcharge.
# Match the power_supply device because the sysfs charge_type file may not exist yet on the first USB add event.
SUBSYSTEM=="power_supply", KERNEL=="apple_mfi_fastcharge*", ACTION=="add|change", RUN+="/bin/sh -c 'echo Fast > /sys%p/charge_type || :'"
EOF
```

Important detail:

```text
/sys%p/charge_type
```

`%p` expands to the sysfs device path relative to `/sys`.

So this becomes something like:

```text
/sys/devices/pci0000:00/.../power_supply/apple_mfi_fastcharge_1-12/charge_type
```

### 7. Reload udev rules

Run:

```zsh
sudo udevadm control --reload-rules
```

### 8. Trigger the rule without rebooting

Run:

```zsh
sudo udevadm trigger --subsystem-match=power_supply --action=change
```

Wait briefly:

```zsh
sleep 1
```

### 9. Check the charge mode after the udev rule

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Correct result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

If it says `Fast`, the rule is working.

### 10. Test by unplugging and replugging

Unplug the iPhone.

Wait a few seconds.

Plug it back in.

Then run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

Expected result:

```text
/sys/class/power_supply/apple_mfi_fastcharge_1-12/charge_type: Fast
```

### General Troubleshooting

#### No `apple_mfi_fastcharge` path exists

Run:

```zsh
sudo modprobe apple-mfi-fastcharge
```

Then unplug and replug the iPhone.

Check kernel logs:

```zsh
sudo dmesg | grep -iE 'apple.*mfi|fastcharge|iphone'
```

#### Check whether udev sees the power_supply event

Run this in one terminal:

```zsh
sudo udevadm monitor --kernel --udev --property --subsystem-match=power_supply
```

Then unplug and replug the iPhone.

You should see an event for a device whose name starts with:

```text
apple_mfi_fastcharge
```

#### Check the udev properties for the device

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  device_dir=${charge_file:h}
  print -r -- "Device directory: $device_dir"
  udevadm info --query=property --path="${device_dir#/sys}"
done
```

#### Manually test the exact path style used by the udev rule

Run:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  device_dir=${charge_file:h}
  sys_rel_path=${device_dir#/sys}
  print -r -- "Testing /sys${sys_rel_path}/charge_type"
  print Fast | sudo tee "/sys${sys_rel_path}/charge_type" >/dev/null
done
```

Then check again:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```

#### Alternative rule if `/sys%p` does not work on your system

Try this version instead:

```zsh
sudo tee /etc/udev/rules.d/99-apple-mfi-fastcharge.rules >/dev/null <<'EOF'
# Enable fast charging for Apple iPhone/iPad devices handled by apple-mfi-fastcharge.
SUBSYSTEM=="power_supply", KERNEL=="apple_mfi_fastcharge*", ACTION=="add|change", RUN+="/bin/sh -c 'echo Fast > /sys/class/power_supply/%k/charge_type || :'"
EOF
```

Reload and trigger again:

```zsh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply --action=change
sleep 1
```

Check:

```zsh
for charge_file in /sys/class/power_supply/apple_mfi_fastcharge*/charge_type(N); do
  print -r -- "$charge_file: $(<"$charge_file")"
done
```
---
