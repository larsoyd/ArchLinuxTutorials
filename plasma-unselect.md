# Plasma desktop icon deselect patch for Arch Linux

## Problem

When you launch something from the Plasma desktop using a desktop launcher, the app opens, but its selection state is not cleared afterward. So for example if I click a text file on the desktop and it opens in Kate, the file still sits there highlighted as if it is still the active selection. Functionally it is harmless, but visually it feels wrong and inconsistent with how desktop icons usually behave. I got so tired of this I decided to look into fixing it in the most simple manner.


## What this does

This applies a user-local override for Plasma’s `org.kde.desktopcontainment` package and patches `FolderView.qml` so launching a desktop icon clears its selection afterward. The override works because Plasma package lookup searches both the system and user package paths and prefers the user copy. The relevant desktop containment files are shipped by Arch’s `plasma-desktop` package. 

The patch targets the current launch path in `FolderView.qml`, where the activation branch calls:

```qml
dir.run(positioner.map(gridView.currentIndex));
````

`Qt.callLater()` is used so the deselect runs after the current QML event turn completes.

## Files involved

### System files

* `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml`
* `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/main.qml`
* `/usr/lib/qt6/qml/org/kde/private/desktopcontainment/folder/libfolderplugin.so`

### Files created by this setup

* `~/.local/bin/plasma-folderview-deselect-sync`
* `~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/...`
* Optional: `/usr/local/bin/plasma-folderview-deselect-hook`
* Optional: `/etc/pacman.d/hooks/plasma-folderview-deselect.hook`

Arch’s current `plasma-desktop` package file list confirms those installed locations.

## Patch logic

### Original branch

```qml
} else {
    dir.run(positioner.map(gridView.currentIndex));
}
```

### Patched branch

```qml
} else {
    dir.run(positioner.map(gridView.currentIndex));
    Qt.callLater(() => {
        dir.clearSelection();
        gridView.currentIndex = -1;
        main.previouslySelectedItemIndex = -1;
    });
}
```

This clears the selection model and resets the two index variables so the post-launch state matches Plasma’s existing deselect behavior more closely. The current source shows blank-space deselection resetting `gridView.currentIndex`, `main.previouslySelectedItemIndex`, and the selection state.

## Install

### 1. Verify the live anchor exists

Run:

```bash
FILE=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml
grep -nC3 -F 'dir.run(positioner.map(gridView.currentIndex));' "$FILE"
```

You should see exactly one match. Ensure `rsync` is installed, if not install it with `$ pacman -S --needed rsync`.

### 2. Create the sync script

Create `~/.local/bin/plasma-folderview-deselect-sync` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

SRC="/usr/share/plasma/plasmoids/org.kde.desktopcontainment"
DST="$HOME/.local/share/plasma/plasmoids/org.kde.desktopcontainment"
TARGET="$DST/contents/ui/FolderView.qml"

mkdir -p "$HOME/.local/share/plasma/plasmoids"
mkdir -p "$HOME/.local/bin"

if [[ ! -f "$SRC/contents/ui/FolderView.qml" ]]; then
    echo "[error] Source file not found: $SRC/contents/ui/FolderView.qml" >&2
    exit 1
fi

# Refresh local shadow copy from the current package.
rsync -a --delete "$SRC/" "$DST/"

python3 - "$TARGET" <<'PY'
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
    print(f"[ok] Patch already present in {path}")
    raise SystemExit(0)

anchor = "dir.run(positioner.map(gridView.currentIndex));"
count = src.count(anchor)

if count != 1:
    print(f"[error] Expected exactly 1 launch anchor, found {count}.", file=sys.stderr)
    print("[error] Your installed FolderView.qml does not match the expected code shape.", file=sys.stderr)
    raise SystemExit(1)

replacement = """dir.run(positioner.map(gridView.currentIndex));
                    Qt.callLater(() => {
                        dir.clearSelection();
                        gridView.currentIndex = -1;
                        main.previouslySelectedItemIndex = -1;
                    });"""

src = src.replace(anchor, replacement, 1)
path.write_text(src, encoding="utf-8")
print(f"[ok] Patched {path}")
PY

echo
echo "[ok] Local override is ready:"
echo "     $DST"
echo
echo "[next] Restart plasmashell or log out/in to load the patched QML."
```

### 3. Make it executable and run it

```bash
chmod +x ~/.local/bin/plasma-folderview-deselect-sync
~/.local/bin/plasma-folderview-deselect-sync
```

### 4. Restart Plasma Shell

```bash
kquitapp6 plasmashell || true
kstart6 plasmashell
```

You can also log out and back in.

### 5. Test

Launch a desktop icon with the mouse. The icon should no longer stay selected after launch.

## Verify

### Confirm the patch is present in the user-local override

```bash
grep -nC2 -F 'Qt.callLater(() => {' \
  ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml
```

### Confirm the override exists

```bash
ls -la ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/
```

### Compare system and local copies

```bash
diff -u \
  /usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml \
  ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml
```

## Optional automatic reapply after updates

Arch supports post-transaction hooks in `/etc/pacman.d/hooks`. Use this only after the manual script works. Change user and such to yours.

### 1. Create `/usr/local/bin/plasma-folderview-deselect-hook`

```bash
#!/usr/bin/env bash
set -euo pipefail

USER_NAME="lars"
USER_HOME="/home/lars"

exec /usr/bin/runuser -u "$USER_NAME" -- \
    "$USER_HOME/.local/bin/plasma-folderview-deselect-sync"
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/plasma-folderview-deselect-hook
```

### 2. Create `/etc/pacman.d/hooks/plasma-folderview-deselect.hook`

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = plasma-desktop

[Action]
Description = Refresh local Folder View deselect-after-launch override
When = PostTransaction
Exec = /usr/local/bin/plasma-folderview-deselect-hook
Depends = python
Depends = rsync
Depends = util-linux
```

This refreshes and re-patches the user-local copy after `plasma-desktop` installs or upgrades. It does not restart Plasma automatically. Pacman hook format and directories are documented by Arch.

## Uninstall

### Remove the local override

```bash
rm -rf ~/.local/share/plasma/plasmoids/org.kde.desktopcontainment
```

### Restart Plasma Shell

```bash
kquitapp6 plasmashell || true
kstart6 plasmashell
```

### Remove the sync script

```bash
rm -f ~/.local/bin/plasma-folderview-deselect-sync
```

### Remove the optional pacman automation

```bash
sudo rm -f /usr/local/bin/plasma-folderview-deselect-hook
sudo rm -f /etc/pacman.d/hooks/plasma-folderview-deselect.hook
```

After that, Plasma falls back to the stock system copy because the user-local override is gone. KPackage documents that the user package path is preferred over the system path when both exist.

## Troubleshooting

### Script says it found 0 or more than 1 anchors

Run:

```bash
FILE=/usr/share/plasma/plasmoids/org.kde.desktopcontainment/contents/ui/FolderView.qml
grep -nF 'dir.run(positioner.map(gridView.currentIndex));' "$FILE"
grep -nF 'dir.runSelected();' "$FILE"
grep -nF 'onReleased:' "$FILE"
```

If the first command does not return exactly one match, your installed `FolderView.qml` differs from the expected code shape and the patcher needs adjustment.

### Patch applies but behavior does not change

Restart `plasmashell` or log out and back in. Plasma may still be using the old loaded QML.

### Hook does not run

Check:

* `/usr/local/bin/plasma-folderview-deselect-hook` exists
* it is executable
* username and home path are correct
* `/etc/pacman.d/hooks/plasma-folderview-deselect.hook` exists
* `python`, `rsync`, and `runuser` are available

## Notes

This method avoids editing package-managed files under `/usr/share/...`. It uses a user-local package override, which is the intended package lookup behavior for Plasma packages. The installer patches a single unique launch anchor instead of replacing a whole formatting-sensitive block. The approach is local and reversible.

## Sources

* Plasma desktop containment source: `FolderView.qml` and related desktop containment code.
* Arch `plasma-desktop` package file list.
* KDE KPackage lookup behavior for system and user package paths.
* Arch pacman hook documentation.



