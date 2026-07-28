
### EXTRA TUTORIAL: Enable Secure Boot with systemd-boot + UKIs + sbctl

This tutorial uses:

* UEFI firmware
* systemd-boot
* An EFI System Partition mounted at `/efi`
* `kernel-install`
* `mkinitcpio` for the initramfs
* `systemd-ukify` for creating Unified Kernel Images
* UKIs stored inside `/efi/EFI/Linux`

**ONLY follow this section if you installed Arch using this tutorial.**

This is not written for GRUB, shim, rEFInd, split kernel/initramfs booting, or an EFI partition mounted somewhere other than `/efi`.

Secure Boot makes the firmware reject untrusted or modified EFI boot files. In this setup that includes systemd-boot and the UKI containing your kernel, initramfs, microcode, and embedded kernel command line.

**Secure Boot does not encrypt your files.** For protection against someone removing the SSD and reading it from another computer, you also need LUKS encryption.

---


### OPTIONAL: If Dual-Booting Windows with Secure Boot

This is an optional first step of the tutorial that is only relevant to users who followed my tutorial but also have Windows installed on another partition or drive with SecureBoot enabled, you must read & do this part before you start the tutorial.

You may wonder if changing your SecureBoot keys while an OS already exists on another drive would render that install forever unbootable. This is an understandable fear, but unless something went wrong it **won't.** Windows does not require the original OEM Platform Key to boot with SecureBoot enabled, meaning you can replace the Platform Key with your custom sbctl key while retaining Microsoft’s certificates in `KEK` and `db`. To do this you must simply ensure that you always enroll the keys with Microsoft's certs by using the `--microsoft` flag like we do in this tutorial:

```zsh
sudo sbctl enroll-keys --microsoft
```

It is a good rule of thumb to always include it with this command regardless if you are dual booting or not. The reason why the flag should always be included is because a custom-only enrollment on Windows can cause firmware to reject Windows Boot Manager when Secure Boot is enabled.

___

#### Windows Housekeeping

Before starting the tutorial if you are dual booting with Windows boot into Windows, before you do ensure you have re-enabled SecureBoot in firmware which had to be disabled during the Arch install.

Open **Command Prompt as Administrator** (`cmd`) and check whether BitLocker or Windows Device Encryption protects the Windows system drive:

```bat
manage-bde -status C:
```

If protection is not enabled, you can reboot back into the firmware, turn off SecureBoot again and boot into Arch to begin the process. If it *is* enabled, make sure you possess the 48-digit BitLocker recovery password:

```bat
manage-bde -protectors -get C:
```

Store the recovery password somewhere that is **not located only on this computer**.

Do not continue until the recovery key has been saved somewhere accessible.

#### Suspend BitLocker before changing Secure Boot keys

From an Administrator Command Prompt:

```bat
manage-bde -protectors -disable C: -rebootcount 0
```

`-rebootcount 0` keeps protection suspended until you manually enable it again. This is useful because setting up custom Secure Boot keys may require several reboots between Windows, Arch, and the firmware settings.

This does **not** decrypt the Windows partition and does not remove its BitLocker protectors. All it does is temporarily stop the TPM from blocking access because the Secure Boot measurements changed. You may now reboot back into the firmware, turn off SecureBoot again and boot into Arch to begin the process. 

---

### IMPORTANT WARNING BEFORE STARTING

Now that you are back in Arch, do some housekeeping before starting. First ensure you have these ready:

* A recent backup of important files
* Your Arch installation USB or another Linux recovery USB
* Access to your firmware/BIOS setup
* The laptop (if used) connected to AC power

**NEVER** use any option/flag called:

* `--yolo`
* `--yes-this-might-brick-my-machine`
* Ignore Option ROM errors
* Clear keys after finishing
* Restore factory keys after finishing

If Arch fails to boot after enabling Secure Boot, always go back into the firmware and **only disable Secure Boot**. Do not clear the keys.

---

### 1) Install the Secure Boot tools

Let's begin the tutorial then, first install the necessary tools:

```zsh
sudo pacman -S --needed sbctl efitools mokutil
```

What each package does:

* `sbctl` creates keys, enrolls them, signs EFI files, and verifies the boot chain
* `efitools` provides `efi-readvar` for viewing the firmware key databases
* `mokutil` provides an additional way to check the Secure Boot state

The Arch `sbctl` package also installs integration for `kernel-install`, mkinitcpio, and pacman transactions.

---

### 2) Confirm that this is the correct boot setup

```zsh
printf 'Firmware boot mode: '

if [[ -d /sys/firmware/efi ]]; then
    echo 'UEFI'
else
    echo 'Legacy BIOS'
fi

echo
echo 'Secure Boot state:'
mokutil --sb-state

echo
echo 'ESP mount:'
findmnt /efi

echo
echo 'Disk layout:'
lsblk -o NAME,SIZE,PTTYPE,FSTYPE,PARTTYPENAME,MOUNTPOINTS

echo
echo 'kernel-install configuration:'
kernel-install inspect
```

You want to see:

```text
Firmware boot mode: UEFI
```

Your main system disk should use GPT, and `/efi` should be a VFAT EFI System Partition.

`kernel-install inspect` should include something similar to:

```text
Layout: uki
Boot Root: /efi
```

Stop here if:

* It says `Legacy BIOS`
* `/efi` is not your EFI System Partition
* Your disk uses MBR instead of GPT
* `kernel-install` is not configured with the `uki` layout
* You did not install using this tutorial

---

### 3) Check whether the firmware is in Setup Mode

```zsh
sudo sbctl status
```

The ideal state before creating and enrolling custom keys is:

```text
Setup Mode: Enabled
Secure Boot: Disabled
```

You may also see:

```text
Installed: ✗ sbctl is not installed
```

This does **NOT** mean the Arch package is missing.

In this context, it means sbctl has not yet created its key hierarchy and owner GUID.

#### If Setup Mode is already enabled

Continue to the next step.

#### If Setup Mode is disabled

Your firmware probably still has its factory Platform Key enrolled. Custom Secure Boot keys cannot normally be enrolled until the firmware is placed into Setup Mode.

Reboot into the firmware:

```zsh
systemctl reboot --firmware-setup
```

If that command is ignored, reboot normally and press the firmware setup key. Common keys are `Esc`, `F2`, `F10`, `F12`, and `Delete`.

Inside the firmware, locate the Secure Boot key-management settings.

Depending on the manufacturer, the required option may be called:

* Delete Platform Key
* Clear Secure Boot Keys
* Reset to Setup Mode
* Key Management
* Custom Secure Boot Keys

The goal is to remove the existing **Platform Key**, which places the firmware into Setup Mode.

Boot back into Arch with Secure Boot still disabled and run:

```zsh
sudo sbctl status
```

Do not continue until it reports that Setup Mode is enabled.

The sbctl documentation requires Setup Mode for live key enrollment and recommends retaining Microsoft trust certificates because some firmware and Option ROM components depend on them.

---

### 4) Inspect the current firmware key databases

This step is read-only:

```zsh
for sb_variable in PK KEK db; do
    printf '\n===== %s =====\n' "$sb_variable"
    sudo efi-readvar -v "$sb_variable" 2>&1
done
```

The variables mean:

* `PK` is the Platform Key that establishes ownership
* `KEK` contains keys allowed to update the trusted and forbidden databases
* `db` contains trusted certificates and hashes

When the firmware is in Setup Mode, `PK` should have no entries.

---

### 5) Create your Secure Boot keys

```zsh
sudo sbctl create-keys
```

Check the result:

```zsh
sudo sbctl status

sudo find /var/lib/sbctl/keys \
    -maxdepth 2 \
    -type f \
    -printf '%M %p\n'
```

sbctl should create:

* A Platform Key
* A Key Exchange Key
* A Signature Database key
* An owner GUID

The private keys are stored below:

```text
/var/lib/sbctl
```

Do not upload that directory or put it in a public repository.

After everything is working, make an encrypted offline backup of `/var/lib/sbctl`. Someone who obtains your private database key can sign a modified UKI that your computer will trust.

---

### 6) Create a signed systemd-boot source file

systemd’s `bootctl install` and `bootctl update` prefer a file ending in `.efi.signed` when one is available.

Create and register the signed source:

```zsh
sudo sbctl sign --save \
    --output /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```

Now update the copies installed on the EFI System Partition:

```zsh
sudo bootctl update
```

This should install or update the signed systemd-boot binaries under `/efi/EFI/`.

---

### 7) Sign every currently installed UKI

The UKIs created by this tutorial are stored in:

```text
/efi/EFI/Linux
```

Sign and register all current UKIs:

```zsh
sudo find /efi/EFI/Linux \
    -maxdepth 1 \
    -type f \
    -name '*.efi' \
    -exec sbctl sign --save {} +
```

This does not depend on zsh glob expansion. `find` passes the exact filenames directly to sbctl.

---

### 8) Verify the complete boot chain

```zsh
sudo sbctl verify
```

You want every EFI executable used by this installation to show a checkmark, for example:

```text
✓ /efi/EFI/BOOT/BOOTX64.EFI is signed
✓ /efi/EFI/systemd/systemd-bootx64.efi is signed
✓ /efi/EFI/systemd/systemd-boot-fallbackx64.efi is signed
✓ /efi/EFI/Linux/YOUR-UKI.efi is signed
✓ /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed is signed
```

**DO NOT reboot with Secure Boot enabled if a required boot file is unsigned.**

If sbctl reports an unsigned UKI or systemd-boot file, sign the exact path it prints:

```zsh
sudo sbctl sign --save '/exact/path/reported/by/sbctl.efi'
sudo sbctl verify
```

Repeat until every boot file belonging to this installation is signed.

---

### 9) Enroll your keys and Microsoft’s certificates

```zsh
sudo sbctl enroll-keys --microsoft
```

Using `--microsoft` retains compatibility with firmware components, hardware Option ROMs, Windows boot files, and other EFI programs signed by Microsoft.

If sbctl prints an Option ROM or firmware warning, **STOP and read the message**.

Do not bypass the warning with `--yolo` or `--yes-this-might-brick-my-machine`.

After enrollment, check the status:

```zsh
sudo sbctl status
```

The expected state is:

```text
Installed:    ✓ sbctl is installed
Setup Mode:   ✓ Disabled
Secure Boot:  ✗ Disabled
Vendor Keys:  microsoft
```

Setup Mode should now be disabled because your new Platform Key has been enrolled.

Secure Boot will remain disabled until you enable it in the firmware.


### 10) Confirm that the keys were actually enrolled

```zsh
for sb_variable in PK KEK db; do
    printf '\n===== %s =====\n' "$sb_variable"
    sudo efi-readvar -v "$sb_variable" 2>&1
done
```

You should see:

* Your custom Platform Key in `PK`
* Your custom key plus Microsoft certificates in `KEK`
* Your custom database certificate plus Microsoft certificates in `db`

Current sbctl versions include Microsoft’s newer Secure Boot certificate generation when using `--microsoft`. When this is present and confirmed your Windows partition should boot with SecureBoot enabled.

---

### 11) Reboot into the firmware and enable Secure Boot

```zsh
sync
systemctl reboot --firmware-setup
```

Inside the firmware:

1. Ensure Legacy Boot or CSM is disabled.
2. Enable Secure Boot.
3. Save the settings.
4. Boot Arch.

On some computers, you must disable **Legacy Support** before the Secure Boot option becomes selectable.

Do **NOT** choose any of these after enrolling with sbctl:

* Clear Secure Boot Keys
* Delete All Keys
* Restore Factory Keys
* Load Factory Default Keys

Those options may replace or remove the custom key that signs your Arch UKIs.

---

### 12) Verify Secure Boot after Arch starts

```zsh
sudo sbctl status
mokutil --sb-state
sudo sbctl verify
bootctl status
```

You want:

```text
Setup Mode:   Disabled
Secure Boot:  Enabled
SecureBoot enabled
```

Every file from `sbctl verify` should still show a checkmark.

Congrats. You are now using Secure Boot with your own Arch signing key.

Your boot chain is approximately:

```text
UEFI firmware
    ↓ verifies
systemd-boot
    ↓ loads and verifies
Signed UKI
    ├─ Linux kernel
    ├─ initramfs
    ├─ CPU microcode
    └─ embedded kernel command line
```

---

### 13) Confirm that future kernel updates will be signed

One thing that may worry a technical minded user is if the signing of kernels to work with SecureBoot can be relied upon to persist on new kernel installs & updates automatically. In short, yes it should. Arch's sbctl package comes with a `kernel-install` plugin named:

```text
91-sbctl.install
```

This is a hook that automatically signs your UKI with `sbctl` for you whenever a new kernel is installed, i.e via an update. To confirm that it exists you can check the complete local plugin chain:

```zsh
sudo find /usr/lib/kernel/install.d /etc/kernel/install.d \
    -maxdepth 1 \
    -type f \
    -name '*.install' \
    -printf '%f -> %p\n' 2>/dev/null |
    sort

kernel-install inspect
```

If you followed this tutorial, you should see this general order:

```text
50-mkinitcpio.install
60-ukify.install
90-uki-copy.install
91-sbctl.install
```

What this means is when `kernel-install` is initiated it should follow this chain:

```text
Kernel package update
        ↓
mkinitcpio builds the initramfs
        ↓
systemd-ukify assembles the UKI
        ↓
90-uki-copy installs it in /efi/EFI/Linux
        ↓
91-sbctl signs the installed UKI
```

The final UKI filename contains the kernel version, so every kernel update creates a new filename. The sbctl `kernel-install` plugin then signs that new file automatically.

However, you should always still verify after every update before rebooting:

```zsh
sudo sbctl verify
```

**Never blindly assume that an automatic hook succeeded.**

---

### 14) Add a Secure Boot check to Topgrade

This could be tedious to do with `yay` as you would always have to add `sudo sbctl verify` to the end of the command after `&&` or with an alias. The better way to do this is to use Topgrade and add it as a `post_command` which runs after your updates are done. To do this, first open your Topgrade configuration:

```zsh
topgrade --edit-config
```

Then locate the existing `[post_commands]` section and uncomment it. **Do not create a second `[post_commands]` header if one already exists.**

Add underneath `[post_commands]` after uncommenting it:

```toml
[post_commands]
"Verify Secure Boot chain" = "sudo sbctl status && sudo sbctl verify"
```

Now every Topgrade run will finish by checking:

* Whether Secure Boot is enabled
* Whether Setup Mode remains disabled
* Whether every EFI boot file and UKI is signed

If verification fails, do not reboot until you fix the unsigned file.

---

### 15) TROUBLESHOOT: What to do if a future UKI is unsigned

Run:

```zsh
sudo sbctl verify
```

Find the exact unsigned path in the output, then sign it:

```zsh
sudo sbctl sign --save '/efi/EFI/Linux/EXACT-UNSIGNED-FILENAME.efi'
sudo sbctl verify
```

Only reboot after it reports that every required EFI file is signed.

---

### 16a) Resume BitLocker after Windows boots successfully

This step is ONLY if you have another partition with Windows on it, if not skip to 16b. You may now reboot back into the Windows partition with SecureBoot on to confirm that it works. If you use BitLocker and turned it off at the beginning you must launch `cmd` as an Administrator and re-enable it, but again, **ONLY** if you had BitLocker on and disabled it:

```bat
manage-bde -protectors -enable C:
```

Then confirm:

```bat
manage-bde -status C:
```

You want the Windows drive to report:

```text
Protection Status: Protection On
```

**When protection is resumed, BitLocker seals its key against the new valid boot measurements.** If everything is okay then you may go back to Arch Linux. If not, here is a list of common troubleshooting:

___

#### TROUBLESHOOT: If Windows asks for the recovery key

Don't panic. This does not necessarily mean Windows or the encryption is broken.

Changing the Secure Boot configuration can sometimes change the TPM measurements that BitLocker uses to validate the boot environment. All you have to do is enter the previously saved 48-digit recovery password.

Once Windows starts, resume or reset BitLocker protection as normal so that it accepts the new Secure Boot measurements:

```bat
manage-bde -protectors -enable C:
```

___

#### TROUBLESHOOT: If Windows is rejected by the firmware

Enter the firmware and temporarily **disable Secure Boot only**.

Do not clear the keys again.

Boot Arch and inspect the trusted database:

```zsh
sudo efi-readvar -v db
```

If Microsoft certificates are absent, return the firmware to Setup Mode and enroll again using:

```zsh
sudo sbctl enroll-keys --microsoft
```

**DO NOT** manually modify or privately re-sign `bootmgfw.efi`. Windows Boot Manager should remain signed, maintained and serviced by Microsoft.

---

### 16b) OPTIONAL: Update the Secure Boot dbx revocation database

The `dbx` database prevents known vulnerable EFI programs and bootloaders from starting. After you enable SecureBoot on Linux you may see a new firmware update available when running fwupd for SecureBoot.

This is because your firmware may have an old dbx even if your BIOS itself has no available update.

To check, install and start fwupd if you have not already:

```zsh
sudo pacman -S --needed fwupd
sudo systemctl enable --now fwupd.service
```

Refresh its metadata:

```zsh
sudo fwupdmgr refresh
fwupdmgr get-updates
```

If it offers a **UEFI dbx** update, first verify your current boot chain:

```zsh
sudo sbctl verify
```

#### Check the battery and charger state

If you are on a laptop the firmware update might refuse to continue if the battery is under a certain treshold, regardless of if you are charging or not.

```zsh
sudo fwupdtool get-report-metadata 2>/dev/null |
    grep -E '^(BatteryLevel|BatteryThreshold|PowerState):'
```

You want:

* `PowerState: ac`
* `BatteryLevel` equal to or higher than `BatteryThreshold`

When that is met you can proceed to install, just keep the charging cable connected during the update. Power failures during firmware updates is a good way to brick your computer.

Now you can evaluate if you want this update or not. If you choose to install this firmware update, then install and apply it like this:

```zsh
sudo fwupdmgr update
```

Read the update description CAREFULLY before accepting it. Ensure it is the UEFI dbx update you expected.

Reboot when requested:

```zsh
systemctl reboot
```

After booting:

```zsh
sudo sbctl status
mokutil --sb-state
sudo sbctl verify

fwupdmgr get-history
fwupdmgr check-reboot-needed

fwupdmgr get-devices |
    grep -A12 -F 'UEFI dbx'
```

You want the history to report:

```text
Update State: Success
```

and:

```text
No reboot is necessary
```

fwupd uses date-formatted dbx versions, so a large-looking jump such as `20220801` to a much newer date is not automatically suspicious. dbx releases are cumulative enough for fwupd to support direct upgrades.

The dbx payload is written while Linux is running but becomes active after restarting.

---

### 17) TROUBLESHOOT: Older computers and limited EFI NVRAM

Sometimes after a `dbx` update if your computer is very old it may say it "failed" due to hitting a limit on the size requirements of your EFI variable storage. This storage is **NOT** your EFI System Partition, as confusing as that may be. The EFI System Partition and EFI variable storage are two completely different things:

```text
/efi
```

is a normal partition on your SSD.

```text
/sys/firmware/efi/efivars
```

while this is a small amount of nonvolatile storage built into your motherboard firmware.

**Making your `/efi` larger will not increase the firmware’s variable storage.**

Check the firmware-reported usage with:

```zsh
sudo fwupdtool get-report-metadata 2>/dev/null |
    grep -E 'EfivarsNvram(Free|Used)'
```

If fwupd reports that there is not enough efivarfs space:

* **Do not delete random files from `/sys/firmware/efi/efivars`**
* **Do not delete `dbx`**
* **Do not clear your Secure Boot keys**
* **Do not force the update**
* **Do not resize the ESP expecting it to help**

A complete shutdown and cold power cycle may allow old firmware to garbage-collect replaced EFI variables. Shut your laptop down with:

```zsh
systemctl poweroff
```

Then wait until the machine is fully powered off, and finally start it again and recheck the free space. This is not a guarantee however, and it is probable that it will still report size issues and an "update failure"

But this "failure" report should not be taken as gospel, since if a dbx update still reports success and the new version is shown after reboot, the update worked even if fwupd warns that there is not enough space for another future write. Yes its very annoying, however in the future `dbx` updates will most likely fail due to space requirements. The sad report to give here is that there is really nothing you can do about this. The last `dbx` should be treated as the ceiling for the security of w/e hardware you are using. Take whatever precautions necessary in response, which includes getting a new laptop.



### Troubleshooting For Secure Boot In General

#### Secure Boot is gray in the BIOS

Disable Legacy Boot or CSM first.

On some systems, the option is commonly called **Legacy Support**.

#### `sbctl` says it is not installed after installing the package

This normally means its key hierarchy has not been created yet:

```zsh
sudo sbctl create-keys
```

#### `sbctl verify` says `db.key` does not exist

The keys have not been created yet:

```zsh
sudo sbctl create-keys
```

#### The machine will not boot after enabling Secure Boot

Enter the firmware and disable Secure Boot.

Do not clear the enrolled keys.

Boot Arch, run:

```zsh
sudo sbctl verify
```

and sign whatever required file was missed.

#### A kernel update finishes with an unsigned UKI

Do not reboot.

Sign the exact new UKI:

```zsh
sudo sbctl sign --save '/efi/EFI/Linux/EXACT-FILENAME.efi'
sudo sbctl verify
```

#### Secure Boot works, but the root filesystem is still readable from another computer

That is expected.

Secure Boot verifies the boot chain. It does not encrypt the SSD.

Use LUKS encryption for protection against offline access to your files. If you are wondering on how to do that, you may follow **this** tutorial (Currently writing it)
