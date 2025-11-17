# OPTIONAL: How to fix those annoying 'missing firmware' warnings in mkinitcpio

#### 0) Find the module names that warn

```bash
# So everytime you run mkinicpio -P it warns you about a bunch of "missing firmware" 
# but none of these are important, they are ancient. You probably won't need them.
#
# IF you are unsure that you might need them or if the ones you are seeing are the ones
# I am talking about or actual problems, then you can find a list of them here :
#
# https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX
#
# To see them, run this, and you'll see multiple lines ala:
# "Possibly missing firmware for module: qla2xxx"
# Write down all you see and confirm that you won't need them.
#
sudo mkinitcpio -P
```

### OPTION A) Install all the firmware from the AUR

This may seem like a nobrainer compared to Option B, but it really isn't. It is maintained by a third party which is by definition unsafe and it will populate your hardware with a bunch of outdated firmware which will take up space and introduce a wildcard element. It **should** be fine but it might not be one day. It is overkill for a bunch of terminal noise anyways, but that terminal noise has a real effect of harm which I wish the mkinitcpio maintainers could understand.

```bash
yay -S --needed --noconfirm mkinitcpio-firmware
```

### OPTION B) OR Copy a script that silences them by making dummy firmware

---

### **Disclaimer:**  
##### There is no guarantee that what the scripts write dummies for is one of these ancient modules.
##### PLEASE confirm that the errors you see are irrelevant by checking the wiki list of firmware FIRST, before running this script:

[Arch Wiki | Mkinitcpio/Possibly_missing_firmware_for_module_XXXX
](https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX
)

---

This by the way is why this is such a huge problem, people either become complacant to seeing firmware errors so they are unaware of which ones are real and which ones are a problem. Ideally the firmware would only give such errors based on a system information query of some kind, but that is not the case.

This is one of the few things I would say is a geniune a criticism of Arch Linux. There is just no justification for mkinitcpio spamming this type of completely outdated nonsense every initramfs generation. Whatever reason it is, it is still not justified because end users are confused and it leads to a less secure environment when complacancy sets in. This is why I found it vital to include this seperate tutorial despite deciding to remove fallback from my opinionated tutorial.

```bash
# The Arch Wiki recommends instead writing dummy files manually for them
#
# I wrote a script that creates harmless dummy firmware files for you
# It automatically captures the ones on a single run and then writes dummies for all of them
# then you run mkinitcpio again to build with the dummies to never see them ever again
#
# First open nano like so, which will create a new file:
#
sudo nano /usr/local/sbin/mkinitcpio-silence-missing-fw
```

#### 1.5) Then paste ALL of this underneath into it with CTRL + **SHIFT** + V
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

# Try modinfo with common dash/underscore variants
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
#### 2) Make it executable
```bash
sudo chmod +x /usr/local/sbin/mkinitcpio-silence-missing-fw
```
#### 3) Run & Undo

```bash
# By running this you acknowledge you have checked the wiki first and any liability that follows

## 1) FIRST run this to write the dummies for the ancient modules warned on your machine
sudo /usr/local/sbin/mkinitcpio-silence-missing-fw

## 2) THEN run this to confirm, and you are done
sudo mkinitcpio -P
---

# Ignored both my warnings up there and found yourself screwed?
## 1) Don't worry, I wrote a way to undo a run of this script, just do:
sudo /usr/local/sbin/mkinitcpio-silence-missing-fw --undo

## 2) And once again to confirm, run this afterwards:
sudo mkinitcpio -P
```

---
