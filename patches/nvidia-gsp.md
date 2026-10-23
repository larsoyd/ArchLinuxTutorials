# NVIDIA clock-locking workaround for idle stutter

This is the workaround I use for stutter when my NVIDIA GPU moves out of a low idle power state on Wayland. It keeps memory clocks at a supported value and sets a graphics-clock floor through a systemd service.

The tradeoff is higher idle power use. On my system, idle consumption increased by about 20 W, reaching roughly 25–30 W. Those are observations from my hardware, not guarantees for other cards. Review the temperatures, power use, and behaviour on your own system before keeping the change.

The script reads supported clocks from `nvidia-smi` rather than requiring per-card values. It accepts optional overrides from `/etc/default/nvidia-lock` during both manual and service runs.

## 1. Check the driver and observe the clocks

Confirm that `nvidia-smi` can reach the driver. Then watch clocks, power, and temperature while comparing idle and scrolling behaviour, for example in Firefox. Stop the repeating display with Ctrl+C when finished.

```zsh
nvidia-smi || { echo "nvidia-smi not found or driver not loaded"; exit 1; }

nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1
```

## 2. Inspect supported clocks

The first query lists memory clocks; the second lists graphics clocks:

```zsh
nvidia-smi -i 0 --query-supported-clocks=memory \
  --format=csv,noheader,nounits | sort -nu | tail

nvidia-smi -i 0 --query-supported-clocks=graphics \
  --format=csv,noheader,nounits | sort -nu
```

By default, the script chooses the highest memory clock and the highest graphics clock. It sets the graphics floor to the largest supported clock at or below 40% of the maximum. On the original RTX 4070 example, this selects 900 MHz below a 2520 MHz maximum.

## 3. Create the script

```zsh
sudo nano /usr/local/sbin/lock-nvidia-mem.sh
```

Contents of `/usr/local/sbin/lock-nvidia-mem.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Read overrides for manual runs too
CONFIG=/etc/default/nvidia-lock
# shellcheck disable=SC1090
[[ -r "$CONFIG" ]] && . "$CONFIG"

GPU=${GPU:-0}

GFX_FLOOR_PCT=${GFX_FLOOR_PCT:-0.40}

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

mapfile -t MEM < <(
  nvidia-smi -i "$GPU" --query-supported-clocks=memory \
    --format=csv,noheader,nounits 2>/dev/null \
  | tr -d ' ' | sort -nu
)
((${#MEM[@]})) || { echo "no supported memory clocks for GPU $GPU"; exit 1; }

mapfile -t GFX < <(
  nvidia-smi -i "$GPU" --query-supported-clocks=graphics \
    --format=csv,noheader,nounits 2>/dev/null \
  | tr -d ' ' | sort -nu
)
((${#GFX[@]})) || { echo "no supported graphics clocks for GPU $GPU"; exit 1; }

MEM_MAX_DETECTED="${MEM[-1]}"
GFX_MAX_DETECTED="${GFX[-1]}"
GFX_MIN_DETECTED="${GFX[0]}"

# Snap the floor down to a supported clock
TARGET=$(awk -v m="$GFX_MAX_DETECTED" -v p="$GFX_FLOOR_PCT" \
  'BEGIN{printf "%d", m*p}')
GFX_FLOOR=$(
  printf "%s\n" "${GFX[@]}" \
  | awk -v t="$TARGET" '$1<=t{m=$1} END{print m}'
)
[[ -n "$GFX_FLOOR" ]] || GFX_FLOOR="$GFX_MIN_DETECTED"

MEM_MIN="${MEM_MIN:-$MEM_MAX_DETECTED}"
MEM_MAX="${MEM_MAX:-$MEM_MAX_DETECTED}"
GFX_MIN="${GFX_MIN:-$GFX_FLOOR}"
GFX_MAX="${GFX_MAX:-$GFX_MAX_DETECTED}"

(( MEM_MIN > MEM_MAX )) && MEM_MIN="$MEM_MAX"
(( GFX_MIN > GFX_MAX )) && GFX_MIN="$GFX_MAX"

cat <<EOF
[lock-nvidia-mem] GPU=$GPU
  detected mem clocks : ${#MEM[@]} entries, range ${MEM[0]}..${MEM[-1]} MHz
  detected gfx clocks : ${#GFX[@]} entries, range ${GFX[0]}..${GFX[-1]} MHz
  gfx floor target    : ${TARGET} MHz (pct=${GFX_FLOOR_PCT}) -> snapped to ${GFX_FLOOR} MHz
  applying            : MEM=${MEM_MIN},${MEM_MAX}  GFX=${GFX_MIN},${GFX_MAX}
EOF

$SUDO nvidia-smi -i "$GPU" -pm 1 >/dev/null

$SUDO nvidia-smi -i "$GPU" --reset-gpu-clocks             >/dev/null 2>&1 || true
$SUDO nvidia-smi -i "$GPU" --reset-memory-clocks          >/dev/null 2>&1 || true
$SUDO nvidia-smi -i "$GPU" --reset-memory-clocks-deferred >/dev/null 2>&1 || true

# Deferred locks apply at the next GPU initialization
if ! $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks="${MEM_MIN},${MEM_MAX}"; then
  echo "[lock-nvidia-mem] immediate memory lock failed, trying deferred" >&2
  if $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks-deferred="$MEM_MAX"; then
    echo "[lock-nvidia-mem] deferred memory lock queued -- effective after GPU re-init (driver reload / reboot), NOT this session" >&2
  else
    echo "[lock-nvidia-mem] memory lock failed (both immediate and deferred)" >&2
    exit 1
  fi
fi

$SUDO nvidia-smi -i "$GPU" --lock-gpu-clocks="${GFX_MIN},${GFX_MAX}"

echo "[lock-nvidia-mem] done"
```

Make it executable:

```zsh
sudo chmod 755 /usr/local/sbin/lock-nvidia-mem.sh
```

## 4. Optional overrides

The script works without an override file. Create one only if you want a different GPU index, floor ratio, or explicit clock values:

```zsh
sudo nano /etc/default/nvidia-lock
```

Example contents of `/etc/default/nvidia-lock`. All entries are commented out. Uncomment only the ones you want to override:

```sh
#GPU=0

#GFX_FLOOR_PCT=0.40

#MEM_MIN=10501
#MEM_MAX=10501

#GFX_MIN=900
#GFX_MAX=2520
```

A higher floor ratio, such as `0.50`, may reduce idle-to-load stutter further; a lower value, such as `0.30`, may reduce idle power. Use explicit MHz values only after checking your card's supported tables. The script checks that overrides are numeric.

## 5. Create the service

```zsh
sudo nano /etc/systemd/system/nvidia-lock.service
```

Contents of the service file:

```ini
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

The leading `-` in `EnvironmentFile` makes the override file optional. The script also reads it directly so manual runs use the same settings.

Enable NVIDIA's persistence daemon, then reload units and start the clock-locking service:

```zsh
sudo systemctl enable --now nvidia-persistenced.service
```

```zsh
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-lock.service
```

## 6. Verify the result

Inspect the supported clocks and current lock settings:

```zsh
nvidia-smi -i "${GPU:-0}" -q -d SUPPORTED_CLOCKS | head -n 60
nvidia-smi -i "${GPU:-0}" -q -d CLOCK | head -n 80
```

Optionally run the script manually:

```zsh
sudo /usr/local/sbin/lock-nvidia-mem.sh
```

Example output from the original card:

```text
[lock-nvidia-mem] GPU=0
  detected mem clocks : 4 entries, range 405..10501 MHz
  detected gfx clocks : 117 entries, range 210..2520 MHz
  gfx floor target    : 1008 MHz (pct=0.40) -> snapped to 900 MHz
  applying            : MEM=10501,10501  GFX=900,2520
[lock-nvidia-mem] done
```

Repeat the idle-to-load comparison while watching power and temperature. Stop with Ctrl+C:

```zsh
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1
```

## Deferred memory locks

If the driver rejects `--lock-memory-clocks`, the script tries `--lock-memory-clocks-deferred`. A deferred lock applies on the next GPU initialization, such as a driver reload or reboot. It does not change the current session immediately.

The script prints a warning when it uses this fallback. Reboot and verify the lock settings before judging the result. Persistence mode also needs to be reapplied at boot, which is why the service is included.
