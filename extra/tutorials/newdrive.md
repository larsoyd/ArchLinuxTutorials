## EXTRA TUTORIAL: How to add a new Drive/SSD to GPT-Auto Setups with systemd-repart

This is how you add a new SSD to an install with systemd-gpt-auto-mount without fstab. It is a bit different than the usual way to do it on Linux but its way more simple IMO. The example name of the drive in the tutorial is `REPLACE_THIS` but it can obv be anything you like.

Replace ALL instances of `REPLACE_THIS` in this guide with your own name, that is if you don't want that stupid name for your drive which I hope you don't.
And by all I mean in ALL instances, even in the `.mount` and `.automount` files.

#### 0) First identify your new drive & double check before you write to it

```zsh
# First identify the drive you want to format & mount like in the original tutorial
lsblk -e7 -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL

# Then write out the DEV=/dev/ command with the correct identifier afterwards.
# ensure you have the right one and write the identifier for it.
# for example: sdb for SATA, hdb for HDD, or nvme1n1 for NVME.
DEV=/dev/drive_identifier_here
```

#### 1) Create one GPT Linux data partition with systemd-repart

```zsh
# WARNING: --empty=force is destructive.
# It creates a fresh partition table and existing partitions do not survive.
# Save data on disk first.

sudo rm -rf /tmp/repart-data.d
sudo mkdir -p /tmp/repart-data.d

sudo tee /tmp/repart-data.d/10-REPLACE_THIS.conf >/dev/null <<'EOF_REPART'
[Partition]
Type=linux-generic
Label=REPLACE_THIS
Format=ext4
SizeMinBytes=1G
EOF_REPART

# Preview the plan first. Without --dry-run=no, systemd-repart only shows what it would do.
sudo systemd-repart --definitions=/tmp/repart-data.d --empty=force "$DEV"

# Apply it for real.
sudo systemd-repart --definitions=/tmp/repart-data.d --dry-run=no --empty=force "$DEV"

# Let udev create /dev/disk/by-* symlinks.
sudo udevadm settle
```

#### 2) Verify the partition and filesystem labels

```zsh
lsblk -f "$DEV"
ls -l /dev/disk/by-partlabel/ | grep ' REPLACE_THIS$' || true
ls -l /dev/disk/by-label/ | grep ' REPLACE_THIS$' || true
```

`systemd-repart` already made the ext4 filesystem because the repart file used `Format=ext4`, so do **not** run `mkfs.ext4` separately here.

#### 3) Create the mount point

```zsh
sudo mkdir -p /mnt/REPLACE_THIS
```

#### 4) Create a native systemd mount unit

```zsh
sudo nano /etc/systemd/system/mnt-REPLACE_THIS.mount
```

Add:

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

#### 5) Create an automount for on-demand mounting

```zsh
sudo nano /etc/systemd/system/mnt-REPLACE_THIS.automount
```

Add:

```ini
[Unit]
Description=Auto-mount /mnt/REPLACE_THIS

[Automount]
Where=/mnt/REPLACE_THIS

[Install]
WantedBy=multi-user.target
```

#### 6) Enable it

```zsh
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-data.automount
```

#### 7) Test

```zsh
systemctl status mnt-REPLACE_THIS.automount
df -h /mnt/REPLACE_THIS
touch /mnt/REPLACE_THIS/it-works
```
