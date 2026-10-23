# Encrypt an installed root filesystem with LUKS

This guide converts an existing Ext4 root filesystem to LUKS2 in place, preserving the GPT partition layout and signed UKI boot setup. You first add encryption support to the initramfs and test a normal reboot. Then, from a live USB, you shrink the filesystem, encrypt it, and expand it inside the LUKS mapping. TPM2 unlock is an optional final step.

Start from a working installation configured through the [Secure Boot guide](secureboot.md): GPT, systemd-boot, signed UKIs, Ext4 root, and Secure Boot enabled. **Back up important data before proceeding.** This guide does not provide an undo procedure for the conversion.

## Prerequisites

- Complete the [installation](../../arch_kde_tutorial.md), [post-install](../../arch_kde_post_tutorial.md), and [Secure Boot](secureboot.md) guides first.
- Boot the installed system in UEFI mode with Secure Boot enabled and Setup Mode disabled. Mount the ESP at `/efi`.
- Use a GPT disk with a roughly 2 GiB FAT ESP and one Ext4 root partition of type `4f68bce3-e8cd-4db1-96e7-fbcaf984b709`. This procedure assumes that exact layout.
- Have `linux-lts` or `linux-zen` installed as a UKI, with systemd in the initramfs.
- Keep a verified data backup, an offline copy of `/var/lib/sbctl/`, a recovery USB, and any Windows BitLocker recovery information.
- Choose a strong, unique LUKS passphrase and keep recovery credentials safely off the machine. TPM2 unlock can reduce how often you type a passphrase, but you must retain a working fallback.

**Warning:** Removing encryption later requires a separate procedure. Do not proceed without a backup or if you are unsure about keeping the root filesystem encrypted.

## 1. Check the installed system

Run these checks on the installed Arch system before booting the live USB. Stop if the results do not match the expected setup.

- **UEFI & Secure Boot:**
  ```zsh
  mokutil --sb-state
  sbctl status
  ```
  *Expected:* Secure Boot enabled, Setup Mode disabled. `sbctl status` should show keys are enrolled and UKIs signed.

- **EFI mount:**
  ```zsh
  mount | grep '/efi'
  ```
  *Expected:* Your ESP is mounted at `/efi`. It should be FAT and about 2 GiB (as per your original install).

- **Partition layout:**
  ```zsh
  lsblk -o NAME,TYPE,SIZE,PARTTYPE,MOUNTPOINT | grep -E 'part.*efi|part.*root'
  blkid
  ```
  *Expected:* Two partitions: one with PARTTYPE `c12a7328-f81f-11d2-ba4b-00a0c93ec93b` (EFI System) mounted at `/efi`, and one with PARTTYPE `4f68bce3-e8cd-4db1-96e7-fbcaf984b709` (x86-64 root). The root partition (`/dev/sdXn`) should show TYPE `ext4`. No other root filesystems or swap partitions should exist (your swap is a file in `/`).

- **systemd-boot & UKIs:**
  ```zsh
  bootctl status
  ls /efi/EFI/Linux
  kernel-install inspect
  ```
  *Expected:* `bootctl status` shows the current loader entry pointing to a signed UKI (e.g. linux-zen). The directory `/efi/EFI/Linux` should contain your kernel (vmlinuz), initramfs (initramfs-linux.img), microcode, and embedded `cmdline` for each kernel. `kernel-install inspect` should confirm that your installed kernels are handled by systemd and that `50-mkinitcpio`, `60-ukify`, `90-uki-copy`, `91-sbctl` hooks will run.

- **Initramfs hooks:**
  ```zsh
  grep -E '^HOOKS=' /etc/mkinitcpio.conf
  ```
  *Expected:* The existing HOOKS line should include at least `base`, `systemd`, `autodetect`, `block`, `filesystems`, etc. It **should not** include any `encrypt`, `sd-encrypt`, or `lvm2` hooks yet. (We will add `sd-encrypt`.)

- **Filesystem health:**
  ```zsh
  sudo e2fsck -fn /dev/YOUR-ROOT-PARTITION
  ```
  *Expected:* No errors or prompts (the `-n` option means "don't actually fix"). If errors are found, shut down the computer, chroot in with your Installation Medium or SystemRescue (recommended for this), and fix it with `e2fsck -fy /dev/YOUR-ROOT-PARTITION` before proceeding.

If any check is unexpected, stop and fix it **before** continuing. This tutorial must start from a correct Secure Boot + signed-UKI Arch system.

## Performance considerations

Encryption adds CPU work to disk I/O. Use cryptsetup’s benchmark to compare the CPU’s encryption throughput with your storage performance:

Install `cryptsetup` if needed:

```zsh
sudo pacman -Syu cryptsetup
```

Run the benchmark before or after enabling encryption:
```zsh
cryptsetup benchmark
```

Compare the AES-XTS results with your SSD throughput. The benchmark is an indication of encryption speed, not a measurement of your complete storage workload.

This guide keeps cryptsetup’s default cipher and key-derivation settings. Cipher and sector-size tuning are outside its scope.

If performance is a problem later, investigate dm-crypt workqueue options such as `no_read_workqueue` and `no_write_workqueue`. They are advanced choices and are not enabled here.

## 2. Add the `sd-encrypt` Hook (Prepare LUKS support)

Add encrypted-root support before changing the disk. Continue on the installed system.


1. **Update `mkinitcpio.conf`:** Add `sd-encrypt` (systemd’s encrypt hook) *after* `block` and *before* `filesystems`. For example, find the line:
   ```ini
   HOOKS="base systemd autodetect block filesystems fsck"
   ```
   and change it to:
   ```ini
   HOOKS="base systemd autodetect block sd-encrypt filesystems fsck"
   ```
   (Your list may include other hooks like `keyboard`, `sd-vconsole`, etc. Just insert `sd-encrypt` between `block` and `filesystems`.)

   > **Do not** add `encrypt` or `luks` (those use legacy scripts), and **do not** create `/etc/crypttab` or use `cryptdevice=`. We rely solely on systemd’s GPT discovery and `sd-encrypt`.

2. **(Optional Check)** Ensure no stray `rd.luks.*` or `cryptdevice=` in `/etc/kernel/cmdline` (embedded in UKI). There should be none, because we rely on GPT auto-detect.

3. **Rebuild and copy the initramfs:** Now regenerate the initramfs and UKIs with your existing pipeline:
   ```zsh
   sudo kernel-install add-all
   ```
   This will run `mkinitcpio` (with `sd-encrypt` included), then `ukify` and `sbctl` to sign.

4. **Verify new images:**
   ```zsh
   sudo sbctl verify
   bootctl update
   ```
   Ensure `sbctl verify` reports no errors (all modules and images are signed).

The rebuilt initramfs should now support LUKS while the root filesystem remains unencrypted. Test that the system still boots before continuing.

## 3. Safety Reboot (Before Encryption)

**STOP:** Ensure you have backups and are ready. Then reboot:

```zsh
sudo reboot
```

- During reboot, leave Secure Boot enabled (do not disable it yet). The system should boot normally into Linux as it did before.
- Log in and verify: run `sbctl status` and `sbctl verify` again to ensure the system boots with the signed UKIs. Make sure `/` is still mounted and working.

This confirms that adding `sd-encrypt` did not break your current system. If reboot fails, restore your old `HOOKS=` or fix the issue before proceeding.

## 4. Prepare Live USB and Disable Secure Boot

Perform resizing and encryption from a live USB with the installed root filesystem unmounted. Disable Secure Boot temporarily without clearing the enrolled keys.

1. **Boot Settings:** Reboot into UEFI firmware settings. Disable **Secure Boot** (set to OFF or Setup Mode ON) but **do not** clear keys or modify the enrolled keys. Just turn off Secure Boot so we can boot unsigned live media.

2. **Live USB:** Boot a trusted Arch ISO or SystemRescue USB (x86_64 Arch installer **does not** support Secure Boot currently, but it will boot once SB is off). At the live prompt, drop into a shell.

3. **Set Keymap (if needed):** If you use a non-US layout, make sure to load it (`loadkeys`, etc.). This ensures when `sd-encrypt` later prompts you, the keys match.

4. **Identify Partitions:** On the live USB, repeat `lsblk -o NAME,PARTTYPE,MOUNTPOINT,SIZE` or `parted -l` to identify which `/dev/sdXn` is your GPT disk's root partition and which is the ESP. Mount the ESP to inspect if needed.

   ```zsh
   lsblk -o NAME,SIZE,PARTLABEL,PARTTYPE,TYPE,MOUNTPOINT
   ```
   *Expected:* One disk with two partitions: e.g. `/dev/sda1 EFI System`, `/dev/sda2 Root (x86-64)`.

5. **Double-check / is unmounted:**
   ```zsh
   mount | grep YOUR-ROOT-PARTITION
   ```
   *Expected:* Nothing, the root partition must not be auto-mounted by live system.

If anything looks wrong (wrong disk, multiple rootfs, etc.), fix it now. Do not proceed if you're uncertain which partition is which.

## 5. Shrink the ext4 Filesystem

Shrink the Ext4 filesystem to leave at least 32 MiB unused at the end of the partition for conversion. **Do not shrink the partition itself.** Its GPT boundaries remain unchanged.

1. **Filesystem check:**
   ```zsh
   sudo e2fsck -f /dev/sda2
   ```
   (Replace `/dev/sda2` with your root partition.) Fix any issues if prompted (use `-y` to auto-fix).

2. **Shrink ext4 to minimum:**
   ```zsh
   sudo resize2fs -M /dev/sda2
   ```
   This “maximum shrink” will move all data to the beginning of the partition, leaving free space at the end.

3. **New size check (optional):**
   ```zsh
   sudo dumpe2fs -h /dev/sda2 | grep 'Block count'
   sudo parted /dev/sda print
   ```
   The filesystem will be smaller than the partition; note the difference. There should now be ~32MiB (or more) unallocated at the end.

4. **Final fsck:**
   ```zsh
   sudo e2fsck -f /dev/sda2
   ```
   Ensure the shrunk filesystem is clean.

### Confirm before encrypting

**Stop before encryption:** the root filesystem is still unencrypted. You can stop here rather than continue with conversion. The next command encrypts the partition, and this guide does not provide an undo path. Confirm your backup and selected device first.

## 6. In-Place LUKS2 Conversion

Convert the partition using `cryptsetup reencrypt`. The following command assumes the previous shrink left at least 32 MiB unused at the end of the partition.

```zsh
sudo cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size 32M /dev/sda2
```

- **Explanation:** This command initializes in-place encryption of `/dev/sda2`. The `--reduce-device-size 32M` tells cryptsetup to leave the last 32 MiB of the partition free (these become the new header space). Make sure **NOT** to interrupt this operation (it may take many minutes or longer).

  The process will show progress (especially once bulk encryption starts). When done, you will have an encrypted device.

- **What happened:** `/dev/sda2` is now a LUKS2 container. It contains all your data encrypted, and a header in the last 32 MiB.

If this step fails or aborts, data may be at risk. In that case reboot to BIOS (do **not** try to boot Arch, root is now encrypted). Boot live again and attempt `cryptsetup reencrypt --resume-only /dev/sda2` if possible. We will cover interrupted reencrypt recovery in troubleshooting.

## 7. Verify and Open the LUKS Container

Before moving on, check that the LUKS container is valid.

1. **LUKS header info:**
   ```zsh
   sudo cryptsetup luksDump /dev/sda2
   ```
   *Expected:* It should say “LUKS header information” and list LUKS2 with keyslots=1 (the one you created with your passphrase).

2. **Open the LUKS volume:**
   ```zsh
   sudo cryptsetup open /dev/sda2 root
   ```
   It will prompt you for the passphrase you just created. Enter it; it should succeed and map `/dev/mapper/root` as an ext4 device.

3. **Check new device:**
   ```zsh
   ls /dev/mapper
   blkid /dev/mapper/root
   ```
   *Expected:* `/dev/mapper/root` exists and has TYPE=ext4.

4. **Backup the LUKS header (MANDATORY):**
   ```zsh
   sudo cryptsetup luksHeaderBackup /dev/sda2 --header-backup-file /mnt/your-usb/luks-header-bkp
   ```
   *Important:* **Store this backup file outside the disk!** (e.g. on an external USB or network storage). Without it, a header loss (e.g. disk error) means total data loss. Treat it like a key.

At this point, the partition is fully LUKS2 and the filesystem is decrypted on `/dev/mapper/root`.

## 8. Resize Filesystem to Fill LUKS

Grow Ext4 to fill the space available inside the LUKS mapping.

1. **Check filesystem inside LUKS:**
   ```zsh
   sudo e2fsck -f /dev/mapper/root
   ```
2. **Expand to full size:**
   ```zsh
   sudo resize2fs /dev/mapper/root
   ```
   This will grow ext4 back to the full size of `/dev/mapper/root` (which is slightly smaller than the partition by 32 MiB).

3. **Final fsck:**
   ```zsh
   sudo e2fsck -f /dev/mapper/root
   ```
   Ensure it reports no errors.

4. **Mount and verify data (optional):**
   ```zsh
   sudo mount /dev/mapper/root /mnt
   ls /mnt
   ls /mnt/swapfile
   ```
   Your files should appear intact under `/mnt`. The swap file should still exist within `/mnt` (it will now be encrypted as well).

5. **Close the LUKS device:**
   ```zsh
   cd ~
   sudo umount /mnt
   sudo cryptsetup close root
   ```
   Back to live environment state.

**Result:** The disk now contains:

- GPT partition `/dev/sda2` of type “Root (x86-64)”.
- Inside `/dev/sda2`: a LUKS2 container.
- Inside LUKS: one volume mapped at `/dev/mapper/root` which holds your ext4 filesystem (with all Arch data and swapfile).

## 9. Re-enable Secure Boot and Boot Encrypted System

We now return to normal boot.

1. **Power off live USB:**
   ```zsh
   sudo poweroff
   ```

2. **Firmware settings:** Re-enter UEFI setup. **Enable Secure Boot** (disable Setup Mode) again. **Do not** clear or reset the enrolled keys. Do **not** switch to Setup Mode – just turn Secure Boot ON with current keys.

3. **Boot into Arch:** Let the signed systemd-boot and UKIs load. You should see a **password prompt** early in the boot (from `sd-encrypt`) asking for your LUKS passphrase.

4. **Unlock and continue:** Enter the passphrase you used. The system should unlock `/dev/mapper/root` and continue booting into your normal Arch desktop.

   *If it fails:* You may have mistyped the passphrase, or something went wrong. Try rebooting. If persistent failure, boot the live USB again for troubleshooting.

## 10. Verify Everything

After logging into the installed system, check the root mapping, boot signatures, swap, and available space:

- **Root is encrypted:**
  ```zsh
  mount | grep ' on / '
  ```
  *Expected:* It shows `/dev/mapper/root on / type ext4`.

- **Secure Boot status:**
  ```zsh
  mokutil --sb-state
  sbctl verify
  ```
  *Expected:* Secure Boot on, all current UKIs still signed and verified by sbctl.

- **Boot loader:**
  ```zsh
  bootctl status
  kernel-install inspect
  ```
  *Expected:* The bootloader entry is correct (it should still point to the signed UKI). `kernel-install inspect` should list your kernels as before.

- **Swap:**
  ```zsh
  swapon --show
  ```
  *Expected:* Your swapfile is active and listed. It is now encrypted (since it resides on `/dev/mapper/root`).

- **Filesystem space:**
  ```zsh
  df -h /
  ```
  *Expected:* Shows full disk size for `/` (close to previous partition size minus 32 MiB, as we didn't shrink the partition).

- **Cryptsetup status:**
  ```zsh
  sudo cryptsetup status root
  ```
  *Expected:* Reports device is active, type LUKS2, and “Cipher: aes-xts” (default).

- **LUKS keyslots:**
  ```zsh
  sudo cryptsetup luksDump /dev/sda2 | grep 'Key Slot' -A1
  ```
  *Expected:* There should be one active key slot (Slot 0) “ENABLED”.

The root filesystem should now be available through `/dev/mapper/root`. This setup continues to rely on GPT discovery rather than adding a root UUID or `cryptdevice=` argument to `/etc/kernel/cmdline`.

## 11. TRIM (Discard) Options

The installation guide enables `fstrim.timer`. Dm-crypt blocks discard requests by default. Choose whether to retain that privacy behaviour or allow discards through the encrypted device.

- **Option 1 – Privacy-first (default):** Leave LUKS’s discard blocked (default). Disable the weekly trim:
  ```zsh
  sudo systemctl disable --now fstrim.timer
  systemctl is-enabled fstrim.timer  # should say 'disabled'
  systemctl is-active fstrim.timer   # should say 'inactive'
  ```
  *Pros:* The SSD does not learn which sectors of `/` are unused; better privacy. *Cons:* You lose automated TRIM for root. (If you have any other SSD partitions not on this root, those also won’t be trimmed unless trimmed manually.)

- **Option 2 – Allow discards through LUKS (SSD optimization):** Enable persistent discards so that `fstrim` works as before:
  ```zsh
  sudo cryptsetup open /dev/sda2 root
  sudo cryptsetup --allow-discards --persistent refresh root
  sudo cryptsetup close root
  sudo systemctl enable --now fstrim.timer
  ```
  Then check:
  ```zsh
  sudo cryptsetup luksDump /dev/sda2 | grep -i 'Flags'
  ```
  *Expected:* Should show `allow-discards` in the Flags. Now `fstrim -v /` will trim the SSD again.

  *Security note:* Enabling this leaks information about which parts of the encrypted device are actually in use. In practice, it only reveals allocation patterns (unused blocks), not plaintext content. For a desktop user on a personal machine, this is often an acceptable trade-off for wear-leveling and performance. Choose carefully.

Do **not** blindly overwrite any existing LUKS flags—if there are unexpected flags, investigate first. The commands above preserve other flags.

Choose the first option to keep allocation patterns private, or the second if you want TRIM for the encrypted filesystem.

## 12. Recovery & Troubleshooting

- **Wrong password:** The passphrase is case-sensitive. If you repeatedly fail, reboot into the live USB and repeat the conversion steps. Your data is still there in the LUKS container.

- **Interrupted encryption:** If `cryptsetup reencrypt` was killed, you may resume with
  ```zsh
  sudo cryptsetup reencrypt --resume-only /dev/sda2
  ```
  Or if you opened a temporary mapping, use `--active-name`. Check `man cryptsetup-reencrypt` for details. If it cannot resume, restoring from backup is the only safe option.

- **Access encrypted root from live:** To fix problems, you can always open the LUKS container on live media:
  ```zsh
  sudo cryptsetup open /dev/sda2 root
  sudo mount /dev/mapper/root /mnt
  ls /mnt
  ```
  From here you can `chroot` or copy files. If initramfs needs rebuilding (e.g. after editing mkinitcpio), ensure to bind-mount `/efi` and `/boot`, then chroot and `kernel-install add-all` and `sbctl`.

- **Regenerating UKIs:** If you reinstall kernels, always run `kernel-install add-all` and check `sbctl verify` to maintain signed UKIs.

- **LUKS header loss:** Use the saved `/luks-header-bkp`. You can restore with:
  ```zsh
  sudo cryptsetup luksHeaderRestore /dev/sda2 --header-backup-file /path/to/header-bkp
  ```
  Then reopen the volume.

- **Secure Boot keys lost:** If something happened to SB keys (e.g. you accidentally switched to Setup Mode), re-import your saved `/var/lib/sbctl` via `sbctl install` to restore them before trying to boot.

- **FSCK caution:** *Never* run `fsck` on `/dev/sda2` (the raw LUKS partition). Always open the LUKS container and run `fsck` on `/dev/mapper/root`. Raw `fsck` would corrupt the encrypted data.

- **BitLocker note:** If dual-booting Windows, remember to suspend or decrypt BitLocker before toggling Secure Boot state, as in your Secure Boot guide.

## 13. Optional: TPM2 Auto-Unlock (Convenience)

Configure TPM2 only after passphrase-based boot works. It can unlock the disk automatically when the enrolled machine state matches. Keep the passphrase and recovery key: firmware or Secure Boot changes can prevent TPM unlock.

1. **Check TPM2 support:** On your encrypted root system:
   ```zsh
   systemd-analyze has-tpm2
   systemd-cryptenroll --tpm2-device=list
   ```
   *Expected:* `has-tpm2` says `yes` (with firmware+driver libraries present). `--tpm2-device=list` should show something like `/dev/tpmrm0`. If TPM2 support is partial or missing, you cannot do this.

2. **Install TPM tools:**
   ```zsh
   sudo pacman -Syu tpm2-tss
   kernel-install add-all   # regenerate initramfs so it includes TPM2 libraries
   sbctl verify
   ```
   Re-run `sbctl verify` to ensure UKIs are still signed (the images changed by adding TPM libs).

3. **Create a recovery key:** (high-entropy backup passphrase)
   ```zsh
   sudo systemd-cryptenroll --recovery-key /dev/sda2
   ```
   Enter the current passphrase and save the generated recovery key off the machine. Automatic unlock is a convenience tradeoff; the optional PIN adds an interaction at boot.

4. **Enroll TPM2 token with PCR7 & PCR15:**

**Optional TPM PIN:** Add `--tpm2-with-pin=yes` to the enrollment command if you want a PIN at each boot. Keep it safely recorded off the machine. Repeated incorrect attempts can trigger TPM lockout.

We bind the TPM key to the current Secure Boot state (PCR7) and to PCR15 being all-zero (system-identity):
   ```zsh
   sudo systemd-cryptenroll \
     --tpm2-device=auto \
     --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000 \
     /dev/sda2
   ```
   This adds a TPM2 token keyslot. Now LUKS has three ways to unlock: your original passphrase, the recovery key, or the TPM2.

   *Explanation:* PCR7 ties it to the current Secure Boot keys/policy. PCR15 must be zero (the initial state); once the root is opened, systemd will measure the LUKS volume into PCR15, preventing reuse of this key mid-boot. This means the TPM key works only when the firmware/bootloaders match exactly.

5. **Test TPM unlock:** Reboot. If everything went well and you kept Secure Boot on, the system should unlock without asking for a passphrase (you might see a brief TPM-unseal message). If TPM fails, it will fall back to asking for the passphrase.

6. **Recovery & Re-enrollment:** If you ever update your Secure Boot keys or firmware and TPM unlock stops working (PCR7 changed), just boot with the passphrase, then re-run `systemd-cryptenroll` with the new PCR values (it can wipe the old TPM token and enroll a new one). Your recovery key ensures you can always unlock in the meantime.

**Keep both fallbacks:** do not delete the original passphrase keyslot or the recovery key.

## Final Architecture

The intended setup is:

- **UEFI firmware + Secure Boot** verify the signed bootloader (`systemd-boot`).
- **systemd-boot** loads a signed Unified Kernel Image (kernel+initramfs+cmdline) which was built by `kernel-install` and signed by `sbctl`.
- The **initramfs** contains the `sd-encrypt` hook. It sees the LUKS2 root partition (via GPT) and prompts for the passphrase. (If TPM enrolled, systemd tries TPM2 automatically first.)
- **/dev/mapper/root** is opened from LUKS2 and becomes the real `/`.
- The kernel then mounts the ext4 root on `/dev/mapper/root` via systemd-gpt-auto.
- **Swap** is a file on that ext4, so it’s encrypted too.
- The regular fstrim is either disabled (option 1) or runs through LUKS with `allow-discards` (option 2).
- The EFI System Partition remains mounted at /efi with the restrictive fmask=0177,dmask=0077,noexec,nodev,nosuid options from the original install, limiting Linux-side access and execution on the ESP while still allowing systemd-boot, kernel-install, ukify, and sbctl to maintain the signed boot chain.

You now have the guide’s signed boot chain and encrypted root setup. The EFI partition remains unencrypted. Further kernel or sysctl hardening is a separate choice; review the performance-oriented settings from the main guide if you want to change that balance.
