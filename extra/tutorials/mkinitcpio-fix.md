# Optional: Handle missing-firmware warnings

Repeated warnings can make real problems harder to notice. Before suppressing a mkinitcpio warning, confirm that the named module and firmware are not needed by your hardware.

## Identify the warnings

Run mkinitcpio and note messages such as `Possibly missing firmware for module: qla2xxx`:

```bash
sudo mkinitcpio -P
```

Compare the module names with the [Arch Wiki's missing-firmware guidance](https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX). Do not assume every warning is irrelevant.

Choose one of the following approaches only after reviewing those warnings.

## Option A: Install the firmware package

The AUR package adds firmware that may be unnecessary for your hardware. It uses additional space and depends on a third-party package maintainer. Review the package before choosing it.

```bash
yay -S --needed --noconfirm mkinitcpio-firmware
```

## Option B: Create dummy firmware files

**The script cannot establish that every warning is harmless. Confirm that the affected firmware is not needed before running it.**

The script captures warnings from one mkinitcpio run and creates dummy files for the reported modules, skipping modules currently loaded. It records the files it creates so its undo mode can remove them. If you later add matching hardware, remove the dummies and install the real firmware.

Create the script:

```bash
sudo nano /usr/local/sbin/mkinitcpio-silence-missing-fw
```

Contents of `/usr/local/sbin/mkinitcpio-silence-missing-fw`:

```bash
#!/usr/bin/env bash
# mkinitcpio-silence-missing-fw
#
# Copyright (c) 2025 Lars
# SPDX-License-Identifier: MIT
#
# Permission is granted to use, copy, modify, and distribute this script
# under the terms of the MIT License. See the LICENSE file distributed
# in this repository or <https://opensource.org/license/mit> for details.
#
set -euo pipefail

FWROOT="/usr/lib/firmware"
LIST="/etc/mkinitcpio.local-firmware-ignore"
MARKER="### mkinitcpio-dummy-fw created, remove if you add matching hardware ###"
LOG="/var/tmp/mkinitcpio-warnings.$$.log"
HOST="$(uname -n 2>/dev/null || echo unknown-host)"

usage() {
  cat <<'USAGE'
Usage:
  mkinitcpio-silence-missing-fw         Run mkinitcpio, show output live, detect modules that warn, create dummy firmware only for those modules not in use.
  mkinitcpio-silence-missing-fw --undo  Remove only the dummy firmware files previously created by this tool.
Notes:
  - Future new warnings remain visible, this only touches modules found in this run.
  - Modules currently loaded are skipped.
USAGE
}

undo() {
  if [[ ! -f "$LIST" ]]; then
    echo "Nothing to undo, $LIST not found."
    exit 0
  fi
  while IFS= read -r f; do
    [[ -z "$f" || ! -e "$f" ]] && continue
    if grep -q "$MARKER" "$f" 2>/dev/null; then
      rm -v -- "$f"
    else
      echo "Skip non-dummy file: $f"
    fi
  done < "$LIST"
  : > "$LIST"
  echo "Removed recorded dummy firmware files."
}

# Try common module name variants
get_fw_list() {
  local m="$1"
  # print unique non-empty firmware paths to stdout
  for name in "$m" "${m//-/_}" "${m//_/-}"; do
    if mapfile -t _x < <(modinfo -F firmware "$name" 2>/dev/null); then
      printf '%s\n' "${_x[@]}" | sed '/^$/d' | sort -u
      return 0
    fi
  done
  return 1
}

create_from_warnings() {
  echo "Running mkinitcpio -P (output will be shown and logged to $LOG)..."
  set +e
  mkinitcpio -P 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "mkinitcpio exited with status $status, continuing (warnings were captured)."
  fi

  # Extract module names from warning lines
  declare -A seen=()
  modules=()
  while IFS= read -r line; do
    case "$line" in
      *"Possibly missing firmware for module"*)
        m="${line##*: }"
        m="${m#"${m%%[![:space:]]*}"}"; m="${m%"${m##*[![:space:]]}"}"
        [[ "$m" == \"*\" && "$m" == *\" ]] && m="${m:1:${#m}-2}"
        [[ "$m" == \'*\' && "$m" == *\' ]] && m="${m:1:${#m}-2}"
        if [[ -n "$m" && -z "${seen[$m]+x}" ]]; then
          seen[$m]=1
          modules+=("$m")
        fi
      ;;
    esac
  done < "$LOG"

  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "No 'Possibly missing firmware' warnings found in this run."
    echo "Log: $LOG"
    return 0
  fi

  echo "Modules with warnings: ${modules[*]}"
  touch "$LIST"

  for module in "${modules[@]}"; do
    # Skip if the module is actually in use
    if lsmod | grep -qw "$module"; then
      echo "SKIP $module (module is loaded, will not create dummies for hardware in use)"
      continue
    fi

    mapfile -t fws < <(get_fw_list "$module" || true)
    if [[ ${#fws[@]} -eq 0 ]]; then
      echo "No firmware filenames reported by $module, nothing to create."
      continue
    fi

    for fw in "${fws[@]}"; do
      target="$FWROOT/$fw"
      mkdir -p "$(dirname "$target")"
      if [[ -e "$target" ]]; then
        echo "Exists: $target, leaving as is."
        continue
      fi
      {
        echo "$MARKER"
        echo "Dummy firmware for module $module on $HOST."
        echo "If you later add matching hardware, delete this file and install the proper firmware package."
      } > "$target"
      chmod 0644 "$target"
      echo "$target" >> "$LIST"
      echo "Created dummy: $target"
    done
  done

  echo "Recorded created files in $LIST"
  echo "Done. You can now rebuild: sudo mkinitcpio -P"
  echo "Full mkinitcpio output is in: $LOG"
}

case "${1:-}" in
  --undo) undo ;;
  -h|--help) usage ;;
  *) create_from_warnings ;;
esac
```

Make it executable:

```bash
sudo chmod +x /usr/local/sbin/mkinitcpio-silence-missing-fw
```

### Apply

After reviewing the warnings, create the dummy files and rebuild:

```bash
sudo /usr/local/sbin/mkinitcpio-silence-missing-fw
sudo mkinitcpio -P
```

### Undo

To remove the recorded dummy files and rebuild again:

```bash
sudo /usr/local/sbin/mkinitcpio-silence-missing-fw --undo
sudo mkinitcpio -P
```
