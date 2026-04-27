# Plasma desktop icon label wrapMode patch for Arch Linux

## Problem

Plasma's desktop folder view ships with a hardcoded label `wrapMode` rule that picks `Text.NoWrap` when `maximumLineCount === 1` and `Text.Wrap` otherwise. There is no GUI exposed for this. If you want a different wrap behavior, the only path is to edit the QML directly. This guide does that as a user-local override so the package-managed file under `/usr/share/...` is left alone.

## What this does

This applies a user-local override for Plasma's `org.kde.desktopcontainment` package and patches `FolderItemDelegate.qml` so the desktop icon label uses your chosen `wrapMode` unconditionally instead of the upstream ternary. The override works because Plasma package lookup searches both the system and user package paths and prefers the user copy. The relevant desktop containment files are shipped by Arch's `plasma-desktop` package.

The patch targets a single unique anchor:

```qml
wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
```

and replaces it with a single constant `wrapMode` value. The default in this guide is `Text.Wrap`, which matches what upstream uses on the multi-line branch. You can swap any of the four valid values (see below) by editing one variable in the sync script.

## Pick a wrap mode

Per the Qt 6 `Text` docs, `wrapMode` accepts four values. The trap to know about up front: `Text.WordWrap` overflows the label width whenever a filename has no whitespace word boundary. Qt's own docs are explicit: *"If a word is too long, contentWidth will exceed a set width."* Filenames like `IMG_20251104_long_screenshot_name.png` or `archive.tar.gz` are single "words" by that definition (no spaces), so `WordWrap` will paint outside the icon cell rather than break the name across lines. KDE contributor olib141 flagged this on r/kde and they are correct. **`Text.Wrap` is the recommended default** because it falls back to mid-word breaks only when a single token is too long to fit, otherwise behaves like `WordWrap`. The guide ships with `Text.Wrap` as the default for that reason. The other values:

- `Text.NoWrap` — no wrapping at all; long labels overflow the icon's text width. This is the upstream `maximumLineCount === 1` branch behavior.
- `Text.WordWrap` — wraps only at whitespace word boundaries. **Overflows on filenames without spaces.** Available, but not recommended for desktop folder view labels for the reason above.
- `Text.WrapAnywhere` — wraps at any character including mid-word. Never overflows, but breaks normal multi-word filenames (e.g. `Annual Report.pdf`) at arbitrary character positions instead of at the space.
- `Text.Wrap` — prefers word boundaries; falls back to mid-word only when a word is too long to fit. This matches the upstream non-single-line branch behavior and is what this guide patches in by default.

If you have a strong preference for `Text.WordWrap` despite the overflow caveat — for instance, if all your desktop filenames use spaces — change the `MODE` value at the top of the script. The patch logic is identical either way.

## Files involved

### System files

- `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml`

### Files created by this setup

- `~/.local/bin/plasma-folder-label-wrap-sync`
- `~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/...`
- Optional: `/usr/local/bin/plasma-folder-label-wrap-hook`
- Optional: `/etc/pacman.d/hooks/plasma-folder-label-wrap.hook`

If you also have the deselect-after-launch patch installed from the companion guide, see the **Combining with the deselect patch** section near the end. Running two independent sync scripts that both `rsync --delete` the override directory will clobber each other.

## Patch logic

### Original line

```qml
wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
```

### Patched line (default)

```qml
wrapMode: Text.Wrap
```

The ternary is dropped entirely. With `maximumLineCount === 1` the wrap mode no longer matters anyway (a one-line label cannot wrap), so collapsing the conditional is safe in both branches. The default `Text.Wrap` matches what upstream uses on the multi-line branch but applies it unconditionally instead of switching it off when `maximumLineCount === 1`.

The current line number in upstream `plasma-desktop` master is around 381, but the sync script anchors on the full text of the original line rather than a line number. If KDE shifts the file later, the script will still find the anchor. If the text shape itself changes, the script will refuse to apply rather than silently misedit.

## Install

### 1. Verify the live anchor exists

```bash
FILE=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml
grep -nC2 -F 'wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap' "$FILE"
```

You should see exactly one match. If you see zero matches, your installed `FolderItemDelegate.qml` differs from the expected shape and the patcher needs adjustment (see Troubleshooting). Make sure `rsync` is installed: `pacman -S --needed rsync`.

### 2. Create the sync script

Create `~/.local/bin/plasma-folder-label-wrap-sync` with this exact content. Change the `MODE` value at the top if you want something other than `Text.Wrap`. See the **Pick a wrap mode** section above for tradeoffs — note specifically that `Text.WordWrap` will overflow on filenames without whitespace, which is why this script defaults to `Text.Wrap` instead.

```bash
#!/usr/bin/env bash
set -euo pipefail

# One of: Text.NoWrap, Text.WordWrap, Text.WrapAnywhere, Text.Wrap
# Default Text.Wrap. Text.WordWrap overflows on filenames without spaces.
MODE="Text.Wrap"

SRC="/usr/share/plasma/plasmoids/org.kde.desktopcontainment"
DST="$HOME/.local/share/plasma/plasmoids/org.kde.desktopcontainment"
TARGET="$DST/contents/ui/FolderItemDelegate.qml"

mkdir -p "$HOME/.local/share/plasma/plasmoids"
mkdir -p "$HOME/.local/bin"

if [[ ! -f "$SRC/contents/ui/FolderItemDelegate.qml" ]]; then
    echo "[error] Source file not found: $SRC/contents/ui/FolderItemDelegate.qml" >&2
    exit 1
fi

# Refresh local shadow copy from the current package.
rsync -a --delete "$SRC/" "$DST/"

MODE="$MODE" python3 - "$TARGET" <<'PY'
from pathlib import Path
import os
import sys

path = Path(sys.argv[1])
mode = os.environ["MODE"]

valid = {"Text.NoWrap", "Text.WordWrap", "Text.WrapAnywhere", "Text.Wrap"}
if mode not in valid:
    print(f"[error] Invalid MODE: {mode!r}. Must be one of {sorted(valid)}.", file=sys.stderr)
    raise SystemExit(1)

src = path.read_text(encoding="utf-8")

anchor = "wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap"
replacement = f"wrapMode: {mode}"

if replacement in src and anchor not in src:
    print(f"[ok] Patch already present in {path} (mode={mode})")
    raise SystemExit(0)

count = src.count(anchor)
if count != 1:
    print(f"[error] Expected exactly 1 wrapMode anchor, found {count}.", file=sys.stderr)
    print("[error] Your installed FolderItemDelegate.qml does not match the expected code shape.", file=sys.stderr)
    raise SystemExit(1)

src = src.replace(anchor, replacement, 1)
path.write_text(src, encoding="utf-8")
print(f"[ok] Patched {path} (mode={mode})")
PY

echo
echo "[ok] Local override is ready:"
echo "     $DST"
echo
echo "[next] Restart plasmashell or log out/in to load the patched QML."
```

### 3. Make it executable and run it

```bash
chmod +x ~/.local/bin/plasma-folder-label-wrap-sync
~/.local/bin/plasma-folder-label-wrap-sync
```

### 4. Restart Plasma Shell

```bash
kquitapp6 plasmashell || true
kstart6 plasmashell
```

You can also log out and back in.

### 5. Test

Place a file on the desktop with a name long enough to exceed the icon's text width (or that has a space partway through it). The label should now wrap according to the mode you chose instead of behaving the way it did before.

## Verify

### Confirm the patch is present in the user-local override

```bash
grep -nF 'wrapMode: Text.Wrap' \
  ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml
```

Replace `Text.Wrap` with whichever mode you set (note: `grep -F 'Text.Wrap'` would also match `Text.WrapAnywhere` since it is a substring; if you set `WrapAnywhere`, grep for the full string).

### Confirm the override exists

```bash
ls -la ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/
```

### Compare system and local copies

```bash
diff -u \
  /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml \
  ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml
```

You should see exactly one hunk: the `wrapMode` line.

## Automatic reapply after updates

Arch supports post-transaction hooks in `/etc/pacman.d/hooks`. Use this only after the manual script works. Change user and home path to yours.

### 1. Create `/usr/local/bin/plasma-folder-label-wrap-hook`

```bash
#!/usr/bin/env bash
set -euo pipefail

USER_NAME="lars"
USER_HOME="/home/lars"

exec /usr/bin/runuser -u "$USER_NAME" -- \
    "$USER_HOME/.local/bin/plasma-folder-label-wrap-sync"
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/plasma-folder-label-wrap-hook
```

### 2. Create `/etc/pacman.d/hooks/plasma-folder-label-wrap.hook`

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = plasma-desktop

[Action]
Description = Refresh local Folder View label wrap override
When = PostTransaction
Exec = /usr/local/bin/plasma-folder-label-wrap-hook
Depends = python
Depends = rsync
Depends = util-linux
```

This refreshes and re-patches the user-local copy after `plasma-desktop` installs or upgrades. It does not restart Plasma automatically.

## Combining with the deselect patch

If you have the deselect-after-launch patch from the companion guide already installed, do **not** keep both `plasma-folderview-deselect-sync` and `plasma-folder-label-wrap-sync` running independently. Each one calls `rsync -a --delete "$SRC/" "$DST/"` and refreshes the entire override directory from the system package, which means whichever script ran last wins and the other patch silently disappears.

The fix is one unified sync script that applies both patches in a single pass. Replace your existing `~/.local/bin/plasma-folderview-deselect-sync` with this combined version, and adjust the pacman hook to call the unified script instead.

```bash
#!/usr/bin/env bash
set -euo pipefail

# One of: Text.NoWrap, Text.WordWrap, Text.WrapAnywhere, Text.Wrap
# Default Text.Wrap. Text.WordWrap overflows on filenames without spaces.
MODE="Text.Wrap"

SRC="/usr/share/plasma/plasmoids/org.kde.desktopcontainment"
DST="$HOME/.local/share/plasma/plasmoids/org.kde.desktopcontainment"
TARGET_VIEW="$DST/contents/ui/FolderView.qml"
TARGET_DELEGATE="$DST/contents/ui/FolderItemDelegate.qml"

mkdir -p "$HOME/.local/share/plasma/plasmoids"
mkdir -p "$HOME/.local/bin"

if [[ ! -f "$SRC/contents/ui/FolderView.qml" ]] || \
   [[ ! -f "$SRC/contents/ui/FolderItemDelegate.qml" ]]; then
    echo "[error] Source files not found under $SRC" >&2
    exit 1
fi

# Refresh local shadow copy from the current package.
rsync -a --delete "$SRC/" "$DST/"

# --- Patch 1: deselect after launch in FolderView.qml ---
python3 - "$TARGET_VIEW" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
src = path.read_text(encoding="utf-8")

marker = """Qt.callLater(() => {
                        dir.clearSelection();
                        gridView.currentIndex = -1;
                        main.previouslySelectedItemIndex = -1;
                    });"""

if marker in src:
    print(f"[ok] Deselect patch already present in {path}")
    raise SystemExit(0)

anchor = "dir.run(positioner.map(gridView.currentIndex));"
count = src.count(anchor)
if count != 1:
    print(f"[error] Expected exactly 1 launch anchor in FolderView.qml, found {count}.", file=sys.stderr)
    raise SystemExit(1)

replacement = """dir.run(positioner.map(gridView.currentIndex));
                    Qt.callLater(() => {
                        dir.clearSelection();
                        gridView.currentIndex = -1;
                        main.previouslySelectedItemIndex = -1;
                    });"""

src = src.replace(anchor, replacement, 1)
path.write_text(src, encoding="utf-8")
print(f"[ok] Patched deselect into {path}")
PY

# --- Patch 2: wrapMode in FolderItemDelegate.qml ---
MODE="$MODE" python3 - "$TARGET_DELEGATE" <<'PY'
from pathlib import Path
import os
import sys

path = Path(sys.argv[1])
mode = os.environ["MODE"]

valid = {"Text.NoWrap", "Text.WordWrap", "Text.WrapAnywhere", "Text.Wrap"}
if mode not in valid:
    print(f"[error] Invalid MODE: {mode!r}. Must be one of {sorted(valid)}.", file=sys.stderr)
    raise SystemExit(1)

src = path.read_text(encoding="utf-8")

anchor = "wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap"
replacement = f"wrapMode: {mode}"

if replacement in src and anchor not in src:
    print(f"[ok] wrapMode patch already present in {path} (mode={mode})")
    raise SystemExit(0)

count = src.count(anchor)
if count != 1:
    print(f"[error] Expected exactly 1 wrapMode anchor in FolderItemDelegate.qml, found {count}.", file=sys.stderr)
    raise SystemExit(1)

src = src.replace(anchor, replacement, 1)
path.write_text(src, encoding="utf-8")
print(f"[ok] Patched wrapMode in {path} (mode={mode})")
PY

echo
echo "[ok] Local override is ready:"
echo "     $DST"
echo
echo "[next] Restart plasmashell or log out/in to load the patched QML."
```

If you go this route, your pacman hook should target the unified script. You only need one hook file, not two.

## Uninstall

### Remove the local override

```bash
rm -rf ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment
```

This also removes the deselect override if it was installed in the same directory. If you only want to revert the wrap patch and keep the deselect patch, re-run the deselect or unified sync script after this command.

### Restart Plasma Shell

```bash
kquitapp6 plasmashell || true
kstart6 plasmashell
```

### Remove the sync script

```bash
rm -f ~/.local/bin/plasma-folder-label-wrap-sync
```

### Remove the optional pacman automation

```bash
sudo rm -f /usr/local/bin/plasma-folder-label-wrap-hook
sudo rm -f /etc/pacman.d/hooks/plasma-folder-label-wrap.hook
```

After that, Plasma falls back to the stock system copy because the user-local override is gone.

## Troubleshooting

### Script says it found 0 anchors

Run:

```bash
FILE=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderItemDelegate.qml
grep -nF 'wrapMode' "$FILE"
```

If you see a `wrapMode:` line whose right-hand side does not match the string `(maximumLineCount === 1) ? Text.NoWrap : Text.Wrap`, KDE has changed the file shape. Inspect what the new RHS looks like, decide whether you still want to override it, and adjust the `anchor` string in the script accordingly. The replacement value (`Text.Wrap` or whichever you chose) does not need to change.

### Patch applies but behavior does not change

Restart `plasmashell` or log out and back in. Plasma may still be using the old loaded QML.

```bash
kquitapp6 plasmashell || true
kstart6 plasmashell
```

### Hook does not run

Check:

- `/usr/local/bin/plasma-folder-label-wrap-hook` exists
- it is executable
- username and home path are correct
- `/etc/pacman.d/hooks/plasma-folder-label-wrap.hook` exists
- `python`, `rsync`, and `runuser` are available

### Plasma logs a QML error after restart

If you see selection or layout errors in `journalctl --user -u plasma-plasmashell.service`, your chosen `wrapMode` value may be incompatible with the surrounding code path (extremely unlikely with the four standard values, but possible if you typoed). Re-run the sync script with `MODE="Text.Wrap"` to fall back to the upstream non-single-line behavior, then restart `plasmashell`.

### File becomes pre-compiled

If a future `plasma-desktop` ships `FolderItemDelegate.qml` as a precompiled `.qmlc` or pulls the logic into the C++ side of `libfolderplugin.so`, this patch will stop working. There is no clean userspace fix for that case short of forking the package. If that happens, the `grep` step at the start of Install will return zero matches and the script will refuse to run, which is the intended failure mode.

## Notes

This method avoids editing package-managed files under `/usr/share/...`. It uses a user-local package override, which is the intended package lookup behavior for Plasma packages. The installer patches a single unique anchor instead of replacing a whole formatting-sensitive block, so it survives upstream line shifts as long as the anchor text itself is unchanged. The approach is local and reversible.

## Sources

- Qt 6 `Text` QML type, `wrapMode` property documentation: <https://doc.qt.io/qt-6/qml-qtquick-text.html#wrapMode-prop>
- Plasma desktop containment source: `FolderItemDelegate.qml` in `KDE/plasma-desktop`.
- Arch `plasma-desktop` package file list.
- KDE KPackage lookup behavior for system and user package paths.
- Arch pacman hook documentation.
