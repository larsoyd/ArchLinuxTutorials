
# NVIDIA GSP ISSUES - TUTORIAL 

As of now there is an issue on Wayland with NVIDIA where the power state goes down too low on idle which causes lag and a jump during various use like desktop animations etc. The only solution for this is to either turn off GSP which you need the propietary driver to do (i.e not open kernel modules) or set minimum and max clocks so it doesn't enter that idle state. This is how to do the latter with a systemd service I wrote for it. There are trade offs to this obv, your wattage will go up by about 20 watts on idle, which to me is an acceptable trade off since its about 25 to 30 watt on my computer which is about the same as my usage on other systems in general after benchmarking. I make no guarantees on safety, only that I myself use this. Use at your own volition. I have done it the only way possible by locking the VRAM clocks to a valid safe range chosen from the device’s supported table.



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

### 1) create the clock-locking script
```zsh
# to solve this we will set minimum clock speed
# what it does: installs /usr/local/sbin/lock-nvidia-mem.sh with a safe, dynamic min/max picker
sudo nano /usr/local/sbin/lock-nvidia-mem.sh
```

```zsh
#!/usr/bin/env bash
set -euo pipefail

GPU=${GPU:-0}
PCT=${PCT:-0.70}
B1=${B1:-5000};  B2=${B2:-10000}; B3=${B3:-15000}
V1=${V1:-0.60};  V2=${V2:-0.75};  V3=${V3:-0.80}

SUDO=""
(( EUID != 0 )) && SUDO="sudo"

mapfile -t S < <(
  nvidia-smi -i "$GPU" \
    --query-supported-clocks=memory \
    --format=csv,noheader,nounits \
  | tr -d ' ' | sort -nu
)

((${#S[@]})) || { echo "no supported clocks for GPU $GPU"; exit 1; }

MAX="${S[-1]}"

beta() {
  local m="$1"
  if (( m <= B1 )); then
    awk -v v="$V1" 'BEGIN{print v}'
  elif (( m <= B2 )); then
    awk -v v1="$V1" -v v2="$V2" -v m="$m" -v b1="$B1" -v b2="$B2" \
      'BEGIN{print v1 + (v2-v1)*(m-b1)/(b2-b1)}'
  elif (( m <= B3 )); then
    awk -v v2="$V2" -v v3="$V3" -v m="$m" -v b2="$B2" -v b3="$B3" \
      'BEGIN{print v2 + (v3-v2)*(m-b2)/(b3-b2)}'
  else
    awk -v v="$V3" 'BEGIN{print v}'
  fi
}

pick_le() {
  awk -v t="$1" '$1<=t{m=$1} END{if(m)print m}'
}

k=${#S[@]}
q=$(awk -v p="$PCT" -v k="$k" 'BEGIN{printf("%d",(p*k==int(p*k)?p*k:(int(p*k)+1)))}')
(( q < 1 )) && q=1
(( q > k )) && q=k
S_Q="${S[$((q-1))]}"

BETA=$(beta "$MAX")
TGT=$(awk -v b="$BETA" -v m="$MAX" 'BEGIN{printf("%.0f", b*m)}')
S_F="$(printf "%s\n" "${S[@]}" | pick_le "$TGT")"
[[ -n "$S_F" ]] || S_F="${S[0]}"

MIN="$S_Q"
(( S_F > MIN )) && MIN="$S_F"
(( MIN > MAX )) && MIN="$MAX"

echo "GPU=$GPU k=${#S[@]} DYNAMIC_MIN=$MIN MAX=$MAX (percentile=${PCT}, beta=${BETA})"

$SUDO nvidia-smi -i "$GPU" -pm 1

$SUDO nvidia-smi -i "$GPU" --reset-gpu-clocks || true
$SUDO nvidia-smi -i "$GPU" --reset-memory-clocks || true

MEM_MIN="${MEM_MIN:-$MAX}"
MEM_MAX="${MEM_MAX:-$MAX}"

# 4070 RTX default, check for your own card if this default dont work
GFX_MIN="${GFX_MIN:-900}"
GFX_MAX="${GFX_MAX:-2520}"

echo "GPU=$GPU MEM_MIN=$MEM_MIN MEM_MAX=$MEM_MAX GFX_MIN=$GFX_MIN GFX_MAX=$GFX_MAX"

if ! $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks="${MEM_MIN},${MEM_MAX}"; then
  $SUDO nvidia-smi -i "$GPU" --lock-memory-clocks-deferred="$MEM_MAX" || true
fi

$SUDO nvidia-smi -i "$GPU" --lock-gpu-clocks="${GFX_MIN},${GFX_MAX}"
```

### 2) make it executable
```zsh
# what it does: sets correct mode so systemd can run it
sudo chmod 755 /usr/local/sbin/lock-nvidia-mem.sh
```

### 3) create env overrides
```zsh
# what it does: lets you change GPU/PCT/B1..B3/V1..V3 without editing the script
sudo nano /etc/default/nvidia-lock
```

```zsh
# ----- /etc/default/nvidia-lock -----
# GPU index and percentile
GPU=0

# Known-good for RTX 4070
# Test for yourself
MEM_MIN=10501
MEM_MAX=10501
GFX_MIN=900
GFX_MAX=2520
```

### 4) create a systemd unit
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

### 5) enable NVIDIA persistence daemon
```zsh
# what it does: keeps GPU initialized so your lock survives idle periods
sudo systemctl enable --now nvidia-persistenced.service
```
### 6) reload units and enable our service
```zsh
# what it does: starts clock lock at boot and immediately
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-lock.service
```
### 7) verify supported clocks + current locks
```zsh
# what it does: shows supported memory clocks and the lock status
nvidia-smi -i "${GPU:-0}" -q -d SUPPORTED_CLOCKS | head -n 60
nvidia-smi -i "${GPU:-0}" -q -d CLOCK | head -n 80
```
### 8) test run manually (optional)
```zsh
# what it does: prints chosen MIN/MAX and applies lock interactively
sudo /usr/local/sbin/lock-nvidia-mem.sh

# now test again with the script from step 0 and see the difference
nvidia-smi --query-gpu=clocks.mem,clocks.gr,pstate,power.draw,temperature.gpu \
  --format=csv -l 1

# this also allows you to keep an eye on temps and power.
```

---
