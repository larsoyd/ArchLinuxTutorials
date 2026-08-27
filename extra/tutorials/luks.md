# Encrypting the Root Partition with LUKS (Post-Install)

**Executive Summary:** This tutorial converts your existing Arch system’s unencrypted root filesystem into a LUKS2-encrypted root **in place**, preserving the current GPT layout, systemd-boot/UKI setup, and Secure Boot. It *does not* require reinstalling or repartitioning. You will *pre-stage* the LUKS-capable initramfs, reboot once to verify everything still boots, then boot a live USB (with Secure Boot temporarily disabled) to shrink the ext4 filesystem, run `cryptsetup reencrypt --encrypt` with a 32 MiB tail spare, and finally restore the filesystem size. After returning to firmware to re-enable Secure Boot, you reboot normally into the encrypted system. We include preflight checks, exact commands with expected output, **STOP** confirmations, TRIM/discard options, mandatory LUKS header backup, full verification steps, and an optional TPM2 unlock addendum. 

This tutorial assumes exactly the state after **extra/tutorials/secureboot.md**: a working Arch KDE install, systemd-boot with signed UKIs, an ext4 `/`, and Secure Boot on. **Backup everything important before proceeding.** You will _not_ be able to undo this easily without specialized steps, so ensure you really want full-disk encryption. **DO NOT continue if you are uncertain or lack a backup.** 

## Prerequisites

- **Completed tutorials:** The main Arch install and post-install (part 1), plus the **secureboot.md** tutorial (part 2), must all be done. The system uses GPT, systemd-boot, UKIs, and has Secure Boot enabled.
- **EFI in UEFI mode:** Confirm you are booted with UEFI, Secure Boot enabled (Setup Mode off). The ESP should be mounted at `/efi`.
- **GPT partition layout:** Exactly two partitions: a FAT ESP (∼2 GiB) and one “Root Partition (x86-64)” of type GUID `4f68bce3-e8cd-4db1-96e7-fbcaf984b709` containing the ext4 root.
- **Running Arch environment:** The root partition is ext4 (no LUKS yet) and currently mounted as `/`. A Linux-lts and/or linux-zen kernel with `systemd` must be installed as UKIs.
- **Backup & recovery materials:** Verified backup of all data; a backup of your Secure Boot (`/var/lib/sbctl/`) keys (as your Secure Boot tutorial instructed); and a recovery USB drive (Arch or SystemRescue with a working LUKS-capable environment). If dual-booting Windows, ensure you have BitLocker recovery info as per the Secure Boot guide.
- **Password readiness:** Be prepared to enter an **UNIQUE** and **STRONG** LUKS passphrase & ANOTHER separately unique and strong fallback during live-USB boot. If you are planning to add the same password as your user password here or any other non-unique password then you can skip this tutorial since you are not going to benefit from enabling LUKS. If you are worried about password fatigue, see my TPM2 section under which for the most part will allow for passwordless de-encryption unless TPM state is changed like with firmware updates. Then you have to enter your LUKS password which is why its *vital* that you still keep both the LUKS password and the fallback somewhere safely off machine on a device not connected to the internet or inside a locked container.

**Warning:** This guide does **not** cover how to remove or *decrypt* the LUKS root later. While `cryptsetup reencrypt --decrypt` exists, undoing this encryption is a separate destructive process with its own risks (and is not documented here). If you think you might need to revert to an unencrypted system, do **not** proceed until you are absolutely sure. We will explicitly warn again before the destructive step.

## 1. Preflight on the Live System

Before changing anything, verify your current system state to match expectations. Run these checks on your installed Arch system (not the live USB yet):

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
  *Expected:* No errors or prompts (the `-n` option means "don't actually fix"). If errors are found, shutdown the computer, chroot in with your Installation Medium or SystemRescue (recommended for this), and fix it with `e2fsck -fy /dev/YOUR-ROOT-PARTITION` before proceeding.

If any check is unexpected, stop and fix it **before** continuing. This tutorial must start from a correct Secure Boot + signed-UKI Arch system.


## NB: On the Performance Considerations

Some of you may wonder if your system will suffer a lot from enabling this. That is understandable, encryption adds CPU overhead to every disk I/O. Modern CPUs with AES hardware can often handle AES-XTS at near SSD speeds though, but it is worth checking:

 **Install `cryptsetup` (if not already):**  
   ```zsh
   sudo pacman -Syu cryptsetup
```

**Run the benchmark (can be done without encryption enabled):**
```zsh
cryptsetup benchmark
```

This shows your CPU's encryption speed for various algorithms. Look at **AES** (e.g. `aes xts` 128/256) and compare to your SSD’s performance. If the reported MB/s is well above your SSD’s throughput, then encryption overhead is likely negligible. If it’s comparable or lower, expect some slowdown under heavy I/O. 

We *will not* tune ciphers or sector sizes here; we use cryptsetup’s defaults (AES-XTS, Argon2id KDF). If you wish, later you could re-encrypt with different parameters, but that is advanced.

Also note: by default, dm-crypt uses a multi-queue work mechanism. If you *do* notice performance issues (especially on NVMe SSDs), ArchWiki notes you can disable the dm-crypt workqueues by adding options like `no_read_workqueue` and `no_write_workqueue` on your kernel command line. This is **optional and advanced**. We will not enable it here.

**Summary:** Expect a small CPU cost and possibly a few percent disk throughput loss. Use `cryptsetup benchmark` to gauge the impact.

## 2. Add the `sd-encrypt` Hook (Pre-staging LUKS)

Now we will configure the initramfs to support an encrypted root *before* encrypting anything. Still on the installed system:

   
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

At this point, without yet encrypting the disk, your kernels’ initramfs are *capable* of decrypting a LUKS root. We now reboot **once** to make sure nothing has broken. 

## 3. Safety Reboot (Before Encryption)

**STOP:** Ensure you have backups and are ready. Then reboot:

```zsh
sudo reboot
```

- During reboot, leave Secure Boot enabled (do not disable it yet). The system should boot normally into Linux as it did before.  
- Login and verify: run `sbctl status` and `sbctl verify` again to ensure the system boots with the signed UKIs. Make sure `/` is still mounted and working. 

This confirms that adding `sd-encrypt` did not break your current system. If reboot fails, restore your old `HOOKS=` or fix the issue before proceeding.

## 4. Prepare Live USB and Disable Secure Boot

All encryption and disk resizing must happen with `/` unmounted. We will **only disable Secure Boot**, not erase keys or change anything else. Then we boot a live environment that supports LUKS2:

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

We must shrink the ext4 filesystem to free up at least 32 MiB at the end of the partition for the LUKS header. **Do not** shrink the partition itself; we leave the partition size unchanged. We only shrink the filesystem inside it.

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

> **IMPORTANT – LAST CHANCE:** Up to this point, your root filesystem is still unencrypted ext4. If at any point you decide to abort, you can skip the next steps. **Once you run the next command, the partition will become encrypted.** Make sure you have backups and really want to continue. This tutorial **does not** provide an undo path. Proceed only if you’re certain.

## 6. In-Place LUKS2 Conversion

Now we convert the partition in-place to LUKS2. We assume **no data** exists in the final ~32 MiB of the partition (the previous shrink step ensured this). We use `cryptsetup reencrypt` which will encrypt the existing data and set up a new LUKS2 header in the freed space.

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

Now grow the ext4 filesystem to use all available space inside the LUKS container.

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

Once logged in (graphical or text login), perform a thorough check:

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

Everything should work as before, except `/` is now on `/dev/mapper/root` and automatically unlocked by your passphrase. Systemd’s auto-detection means you still do **not** use a UUID or cryptdevice line in `/etc/kernel/cmdline`.

## 11. TRIM (Discard) Options

Your original system probably had `fstrim.timer` enabled for SSD maintenance. By default, dm-crypt **blocks** discards (TRIM) for security reasons. We present **two options**:

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

I recommend Option 1 (disable) if maximum secrecy is desired, or Option 2 (enable) if you prefer SSD health over the allocation pattern privacy. 

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

Once your encrypted system is verified working, you may optionally enroll a TPM2 so that your disk unlocks without a passphrase (subject to machine state). This **must come last**; the system already boots with a passphrase. If TPM auto-unlock fails (e.g. after a firmware change), you always have the passphrase as backup. Do **not** remove the passphrase!

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
   Type your LUKS passphrase, then it will show a 32-word recovery key. **Save this externally** (off-device) in case TPM or passphrase fails.

4. **Enroll TPM2 token with PCR7 & PCR15:**  
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

6. **(Optional) TPM PIN:** For extra security, you could have used `--tpm2-with-pin=yes` during enrollment; that makes TPM request a PIN on each boot. We won’t cover that in detail here, but it’s an option if you want a two-factor unlock. Note: repeated bad PIN attempts can lock the TPM (with timeout), so choose wisely.

7. **Recovery & Re-enrollment:** If you ever update your Secure Boot keys or firmware and TPM unlock stops working (PCR7 changed), just boot with the passphrase, then re-run `systemd-cryptenroll` with the new PCR values (it can wipe the old TPM token and enroll a new one). Your recovery key ensures you can always unlock in the meantime.

**Pitfall:** Do **not** delete the original passphrase keyslot (Slot 0) or the recovery key. Losing both would be disaster. Keep the passphrase and recovery key around.

## Final Architecture

After all this, your system looks like this:

- **UEFI firmware + Secure Boot** verify the signed bootloader (`systemd-boot`).
- **systemd-boot** loads a signed Unified Kernel Image (kernel+initramfs+cmdline) which was built by `kernel-install` and signed by `sbctl`.
- The **initramfs** contains the `sd-encrypt` hook. It sees the LUKS2 root partition (via GPT) and prompts for the passphrase. (If TPM enrolled, systemd tries TPM2 automatically first.)
- **/dev/mapper/root** is opened from LUKS2 and becomes the real `/`.
- The kernel then mounts the ext4 root on `/dev/mapper/root` via systemd-gpt-auto.
- **Swap** is a file on that ext4, so it’s encrypted too.
- The regular fstrim is either disabled (option 1) or runs through LUKS with `allow-discards` (option 2).
- The EFI System Partition remains mounted at /efi with the restrictive fmask=0177,dmask=0077,noexec,nodev,nosuid options from the original install, limiting Linux-side access and execution on the ESP while still allowing systemd-boot, kernel-install, ukify, and sbctl to maintain the signed boot chain.


If you did all of this, CONGRATULATIONS, you are now an Arch Linux user with a sufficiently hardened system. You could go further if you want, look into sysctl & kernel cmdline hardening defaults, maybe remove some of the ones I use that turn off security for performance, add others, etc - but these are the three things that are really needed IMO. SecureBoot, hardened EFI, and encryption.  Anything more is overkill IMO


