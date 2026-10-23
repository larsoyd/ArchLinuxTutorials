# Add a drive with systemd mount and automount units

This guide adds an Ext4 data drive to the [GPT-discovery installation](../../arch_kde_tutorial.md) without an `fstab` entry. It uses systemd-repart to create the filesystem, then native mount and automount units to make it available on demand.

Replace **every** `REPLACE_THIS` with your chosen name, including filenames and unit contents. Replace the device placeholder with the actual new disk.

## 1. Identify the disk

Check the model, serial number, and existing mount points before choosing a device:

```zsh
lsblk -e7 -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL
```

Assign the correct device, for example the appropriate SATA or NVMe disk:

```zsh
DEV=/dev/drive_identifier_here
```

## 2. Define the partition

**The apply command below destroys the selected disk's existing partition table. Back up its data and confirm `DEV` before continuing.**

Create a fresh definition directory and an Ext4 partition definition:

```zsh
sudo rm -rf /tmp/repart-data.d
sudo mkdir -p /tmp/repart-data.d

sudo tee /tmp/repart-data.d/10-REPLACE_THIS.conf >/dev/null <<'EOF_REPART'
[Partition]
Type=linux-generic
Label=REPLACE_THIS
Format=ext4
SizeMinBytes=1G
EOF_REPART
```

Preview the layout:

```zsh
sudo systemd-repart --definitions=/tmp/repart-data.d --empty=force "$DEV"
```

After checking the preview, apply it and wait for udev's device links:

```zsh
sudo systemd-repart --definitions=/tmp/repart-data.d --dry-run=no --empty=force "$DEV"
sudo udevadm settle
```

## 3. Verify the labels

```zsh
lsblk -f "$DEV"
ls -l /dev/disk/by-partlabel/ | grep ' REPLACE_THIS$' || true
ls -l /dev/disk/by-label/ | grep ' REPLACE_THIS$' || true
```

`Format=ext4` already created the filesystem. Do not run `mkfs.ext4` again.

## 4. Create the mount point and unit

```zsh
sudo mkdir -p /mnt/REPLACE_THIS
```

```zsh
sudo nano /etc/systemd/system/mnt-REPLACE_THIS.mount
```

Contents of `/etc/systemd/system/mnt-REPLACE_THIS.mount`:

```ini
[Unit]
Description=Insert your drive description here

[Mount]
What=/dev/disk/by-partlabel/REPLACE_THIS
Where=/mnt/REPLACE_THIS
Type=ext4
Options=noatime

[Install]
WantedBy=multi-user.target
```

## 5. Create the automount unit

```zsh
sudo nano /etc/systemd/system/mnt-REPLACE_THIS.automount
```

Contents of `/etc/systemd/system/mnt-REPLACE_THIS.automount`:

```ini
[Unit]
Description=Auto-mount /mnt/REPLACE_THIS

[Automount]
Where=/mnt/REPLACE_THIS

[Install]
WantedBy=multi-user.target
```

## 6. Enable the automount

The enable command below uses the example unit name `mnt-data.automount`. Substitute the unit name you created above.

```zsh
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-data.automount
```

## 7. Test access

```zsh
systemctl status mnt-REPLACE_THIS.automount
df -h /mnt/REPLACE_THIS
touch /mnt/REPLACE_THIS/it-works
```
