# NVIDIA GSP ISSUES - TUTORIAL

As of now there is an issue on Wayland with NVIDIA where the power state goes down too low on idle which causes lag and a jump during various use like desktop animations etc. The only solution for this is to either turn off GSP which you need the propietary driver to do (i.e not open kernel modules) or set minimum and max clocks so it doesn't enter that idle state. This is how to do the latter with a systemd service I wrote for it. There are trade offs to this obv, your wattage will go up by about 20 watts on idle, which to me is an acceptable trade off since its about 25 to 30 watt on my computer which is about the same as my usage on other systems in general after benchmarking. I make no guarantees on safety, only that I myself use this. Use at your own volition. I have done it the only way possible by locking the VRAM clocks to a valid safe range chosen from the device's supported table.

This version is **fully dynamic**: it reads the supported memory and graphics clock tables from `nvidia-smi` at runtime and picks safe lock values for whatever card is in the box. No hardcoded numbers, no per-card editing. The `/etc/default/nvidia-lock` file is now optional and only exists for overrides — and the script sources it directly so manual runs honor it the same way the systemd unit does.

### 0) confirm driver + tool exist
```zsh
nvidia-smi || { echo "nvidia-smi not found or driver not loaded"; exit 1; }

# try idling a bit in firefox wait 5 seconds then scroll
# you will see a noticable jump or lag when doing so, esp on 4k.

# try it again and this time run this in another monitor on a terminal:
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1

# you will see the jump happens from when the clocks readjust from a very low point
```

### 1) inspect what your card actually supports

The dynamic script keys off these two tables, so it's worth eyeballing them once before you commit:

```zsh
# supported memory clocks (we lock to the max of these)
nvidia-smi -i 0 --query-supported-clocks=memory \
  --format=csv,noheader,nounits | sort -nu | tail

# supported graphics clocks (we pick a floor inside this range)
nvidia-smi -i 0 --query-supported-clocks=graphics \
  --format=csv,noheader,nounits | sort -nu
```

The script will pick `MEM_MAX` = the largest entry in the first list, `GFX_MAX` = the largest entry in the second, and `GFX_MIN` = the largest supported graphics clock at-or-below 40% of `GFX_MAX`. That 0.40 ratio reproduces the original RTX 4070 default (900 MHz floor on a 2520 MHz boost) and lands at sane idle floors on everything from Turing through Ada.

### 2) create the clock-locking script
```zsh
# what it does: installs /usr/local/sbin/lock-nvidia-mem.sh, fully dynamic
sudo nano /usr/local/sbin/lock-nvidia-mem.sh
```

```zsh
#!/usr/bin/env bash
# /usr/local/sbin/lock-nvidia-mem.sh
# Dynamically lock NVIDIA clocks to mitigate GSP idle-drop lag on Wayland.
# All values are auto-detected from `nvidia-smi --query-supported-clocks=...`.
# Any detected value can be overridden via /etc/default/nvidia-lock.

set -euo pipefail

# Pull overrides for both manual and systemd-launched invocations. The unit
# also sets EnvironmentFile=- on this same path; sourcing here as well is
# redundant in that case but harmless (just re-assigns the same vars), and
# it makes manual `sudo /usr/local/sbin/lock-nvidia-mem.sh` honor the file.
CONFIG=/etc/default/nvidia-lock
# shellcheck disable=SC1090
[[ -r "$CONFIG" ]] && . "$CONFIG"

GPU=${GPU:-0}

# Graphics-clock floor as a fraction of detected boost. 0.40 reproduces the
# original RTX 4070 default (900 MHz on a 2520 MHz boost) and gives a sensible
# idle floor across the Ada / Ampere / Turing range without ever sitting in
# the lowest power bin where the GSP idle-drop lag actually shows up.
GFX_FLOOR_PCT=${GFX_FLOOR_PCT:-0.40}

# --- validate overrides early so we fail loudly, not silently ---
[[ "$GPU" =~ ^[0-9]+$ ]] \
  || { echo "invalid GPU index: $GPU" >&2; exit 1; }
[[ "$GFX_FLOOR_PCT" =~ ^[0-9]+([.][0-9]+)?$ ]] \
  || { echo "invalid GFX_FLOOR_PCT: $GFX_FLOOR_PCT" >&2; exit 1; }
for v in MEM_MIN MEM_MAX GFX_MIN GFX_MAX; do
  val="${!v:-}"
  [[ -z "$val" || "$val" =~ ^[0-9]+$ ]] \
    || { echo "invalid $v: $val" >&2; exit 1; }
done

SUDO=""
(( EUID != 0 )) && SUDO="sudo"

command -v nvidia-smi >/dev/null || { echo "nvidia-smi not found"; exit 1; }

# --- detect supported memory clocks (MHz, ascending, deduped) ---
mapfile -t MEM < <(
  nvidia-smi -i "$GPU" --query-supported-clocks=memory \
    --format=csv,noheader,nounits 2>/dev/null \
  | tr -d ' ' | sort -nu
)
((${#MEM[@]})) || { echo "no supported memory clocks for GPU $GPU"; exit 1; }

# --- detect supported graphics clocks (MHz, ascending, deduped) ---
mapfile -t GFX < <(
  nvidia-smi -i "$GPU" --query-supported-clocks=graphics \
    --format=csv,noheader,nounits 2>/dev/null \
  | tr -d ' ' | sort -nu
)
((${#GFX[@]})) || { echo "no supported graphics clocks for GPU $GPU"; exit 1; }

MEM_MAX_DETECTED="${MEM[-1]}"
GFX_MAX_DETECTED="${GFX[-1]}"
GFX_MIN_DETECTED="${GFX[0]}"

# Pick a sensible graphics floor: GFX_FLOOR_PCT of detected max, snapped DOWN
# to the nearest actually-supported clock so the driver always accepts it.
TARGET=$(awk -v m="$GFX_MAX_DETECTED" -v p="$GFX_FLOOR_PCT" \
  'BEGIN{printf "%d", m*p}')
GFX_FLOOR=$(
  printf "%s\n" "${GFX[@]}" \
  | awk -v t="$TARGET" '$1<=t{m=$1} END{print m}'
)
[[ -n "$GFX_FLOOR" ]] || GFX_FLOOR="$GFX_MIN_DETECTED"

# --- defaults: lock memory at max (the actual GSP fix), GFX clamped above floor ---
MEM_MIN="${MEM_MIN:-$MEM_MAX_DETECTED}"
MEM_MAX="${MEM_MAX:-$MEM_MAX_DETECTED}"
GFX_MIN="${GFX_MIN:-$GFX_FLOOR}"
GFX_MAX="${GFX_MAX:-$GFX_MAX_DETECTED}"

# sanity: never let MIN exceed MAX (env override could invert them)
(( MEM_MIN > MEM_MAX )) && MEM_MIN="$MEM_MAX"
(( GFX_MIN > GFX_MAX )) && GFX_MIN="$GFX_MAX"

cat <<EOF
[lock-nvidia-mem] GPU=$GPU
  detected mem clocks : ${#MEM[@]} entries, range ${MEM[0]}..${MEM[-1]} MHz
  detected gfx clocks : ${#GFX[@]} entries, range ${GFX[0]}..${GFX[-1]} MHz
  gfx floor target    : ${TARGET} MHz (pct=${GFX_FLOOR_PCT}) -> snapped to ${GFX_FLOOR} MHz
  applying            : MEM=${MEM_MIN},${MEM_MAX}  GFX=${GFX_MIN},${GFX_MAX}
EOF

# enable persistence so locks survive idle. Note: persistence mode does NOT
# survive a reboot, which is why this script runs from a boot service.
$SUDO nvidia-smi -i "$GPU" -pm 1 >/dev/null

# clear existing locks (immediate AND any queued deferred lock) before re-applying
$SUDO nvidia-smi -i "$GPU" --reset-gpu-clocks             >/dev/null 2>&1 || true
$SUDO nvidia-smi -i "$GPU" --reset-memory-clocks          >/dev/null 2>&1 || true
$SUDO nvidia-smi -i "$GPU" --reset-memory-clocks-deferred >/dev/null 2>&1 || true

# memory lock: try immediate first; on cards/drivers that only accept the
# deferred path, fall back -- but make it explicit that deferred locks take
# effect on the NEXT GPU init (driver reload / reboot), not in this session.
if ! $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks="${MEM_MIN},${MEM_MAX}"; then
  echo "[lock-nvidia-mem] immediate memory lock failed, trying deferred" >&2
  if $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks-deferred="$MEM_MAX"; then
    echo "[lock-nvidia-mem] deferred memory lock queued -- effective after GPU re-init (driver reload / reboot), NOT this session" >&2
  else
    echo "[lock-nvidia-mem] memory lock failed (both immediate and deferred)" >&2
    exit 1
  fi
fi

# graphics lock
$SUDO nvidia-smi -i "$GPU" --lock-gpu-clocks="${GFX_MIN},${GFX_MAX}"

echo "[lock-nvidia-mem] done"
```

### 3) make it executable
```zsh
# what it does: sets correct mode so systemd can run it
sudo chmod 755 /usr/local/sbin/lock-nvidia-mem.sh
```

### 4) (optional) env overrides

The script works with **no config file at all** — every value is auto-detected. Only create this if you want to tweak the floor ratio or pin specific values. The script validates all values as numeric, so a typo produces an explicit error rather than silent fallthrough:

```zsh
sudo nano /etc/default/nvidia-lock
```

```zsh
# ----- /etc/default/nvidia-lock -----
# Everything here is OPTIONAL. Comment out a line and the script auto-detects.

# which GPU index to operate on (default 0)
#GPU=0

# graphics-clock floor as fraction of detected boost (default 0.40)
# raise toward 0.50 if you still see micro-stutters on idle->load transitions,
# lower toward 0.30 if you want a couple watts back at idle
#GFX_FLOOR_PCT=0.40

# hard pins (override detection entirely). only set these if you know the
# exact MHz value from `nvidia-smi --query-supported-clocks=memory`.
#MEM_MIN=10501
#MEM_MAX=10501
#GFX_MIN=900
#GFX_MAX=2520
```

### 5) create a systemd unit
```zsh
# what it does: runs the lock at boot and keeps state via persistence
sudo nano /etc/systemd/system/nvidia-lock.service
```
```zsh
[Unit]
Description=Lock NVIDIA memory clocks and enable persistence
Wants=nvidia-persistenced.service
After=nvidia-persistenced.service

[Service]
Type=oneshot
EnvironmentFile=-/etc/default/nvidia-lock
ExecStart=/usr/bin/bash /usr/local/sbin/lock-nvidia-mem.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

The `-` in `EnvironmentFile=-/etc/default/nvidia-lock` makes the file optional, so the unit still starts cleanly when you skip step 4. The script also sources the same file directly, so manual invocations get the same behavior.

### 6) enable NVIDIA persistence daemon
```zsh
# what it does: keeps GPU initialized so your lock survives idle periods
sudo systemctl enable --now nvidia-persistenced.service
```

### 7) reload units and enable our service
```zsh
# what it does: starts clock lock at boot and immediately
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-lock.service
```

### 8) verify supported clocks + current locks
```zsh
# what it does: shows supported memory clocks and the lock status
nvidia-smi -i "${GPU:-0}" -q -d SUPPORTED_CLOCKS | head -n 60
nvidia-smi -i "${GPU:-0}" -q -d CLOCK | head -n 80
```

### 9) test run manually (optional)
```zsh
# what it does: prints detected ranges + chosen MIN/MAX and applies lock interactively
sudo /usr/local/sbin/lock-nvidia-mem.sh

# expected output looks like:
# [lock-nvidia-mem] GPU=0
#   detected mem clocks : 4 entries, range 405..10501 MHz
#   detected gfx clocks : 117 entries, range 210..2520 MHz
#   gfx floor target    : 1008 MHz (pct=0.40) -> snapped to 900 MHz
#   applying            : MEM=10501,10501  GFX=900,2520
# [lock-nvidia-mem] done

# now test again with the script from step 0 and see the difference
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1

# this also allows you to keep an eye on temps and power.
```

### Note on the deferred memory-lock fallback

If your card or driver rejects `--lock-memory-clocks` outright, the script falls back to `--lock-memory-clocks-deferred`. This is **not** equivalent to the immediate lock: per NVIDIA's `nvidia-smi` docs the deferred lock only takes effect on the next GPU initialization, i.e. after a driver reload or reboot. The script announces this explicitly when it happens. Your *current* graphical session will still drop into the GSP idle bin until the GPU is re-initialized — so if you see that warning during the manual test, reboot once and verify with step 8 afterwards.

---
