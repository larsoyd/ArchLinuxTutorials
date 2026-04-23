# Plasma Kickoff footer patch for Arch Linux

## Problem

In Plasma 6 on Arch, the Kickoff launcher footer still anchors the power buttons to the right edge of the footer. If you want the power buttons to sit immediately to the right of the tab bar instead, this is not exposed as a user setting.

The current upstream `Footer.qml` uses this anchor block:

```qml
LeaveButtons {
    id: leaveButtons

    anchors {
        top: parent.top
        right: parent.right
        bottom: parent.bottom
    }

    maximumWidth: root.availableWidth - tabBar.width - root.spacing
}
```

## What this does

This guide rebuilds Arch's `plasma-desktop` package with one tiny source edit in Kickoff's `Footer.qml`:

- remove `right: parent.right`
- add `left: tabBar.right`
- add `leftMargin: root.spacing`

That makes the leave / power buttons start immediately after the tab bar instead of being anchored to the far right.

## Why this is a package rebuild and not a user-local plasmoid override

For regular user-installed Plasma widgets, Plasma uses `~/.local/share/plasma/plasmoids/...`.
That is why your desktop-containment override worked for `org.kde.desktopcontainment`.

Kickoff is different on current Arch Plasma 6.
Arch currently ships:

- the desktop containment as files under `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/...`
- Kickoff as the plugin `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.kickoff.so`

There is no installed `/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/.../Footer.qml` to shadow with a user-local copy.

So the practical route here is to patch the source and rebuild `plasma-desktop`.

## Files involved

### Installed package files you can verify

- `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.kickoff.so`
- `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/...`

### Working files created by this tutorial

- `~/Code/arch-packages/plasma-desktop/`
- `~/Code/arch-packages/plasma-desktop/src/.../applets/kickoff/Footer.qml`
- `~/.local/bin/plasma-kickoff-footer-patch`

## Patch logic

### Original block

```qml
anchors {
    top: parent.top
    right: parent.right
    bottom: parent.bottom
}
```

### Patched block

```qml
anchors {
    top: parent.top
    left: tabBar.right
    leftMargin: root.spacing
    bottom: parent.bottom
}
```

This leaves the existing `maximumWidth` calculation in place.

## Install

### 1. Verify the package layout on your machine

Run:

```zsh
pacman -Ql plasma-desktop | rg 'org\.kde\.plasma\.kickoff|org\.kde\.desktopcontainment|Footer\.qml'
```

You should see:

- `org.kde.plasma.kickoff.so`
- the desktop containment files under `/usr/share/plasma/plasmoids/org.kde.desktopcontainment/...`
- no installed Kickoff `Footer.qml`

### 2. Install the build tools

Run:

```zsh
sudo pacman -S --needed base-devel devtools git python
```

`base-devel` and `makepkg` handle package builds. `devtools` provides `pkgctl`, `mkarchroot`, and `makechrootpkg`.

### 3. Clone Arch's packaging repository for plasma-desktop

Run:

```zsh
mkdir -p ~/Code/arch-packages
cd ~/Code/arch-packages
pkgctl repo clone --protocol=https plasma-desktop
cd plasma-desktop
```

This clones the official packaging repo using read-only HTTPS.

### 4. Download and extract the sources without building yet

Run:

```zsh
makepkg -s -o
```

That downloads and extracts the sources and runs `prepare()`, but does not compile them yet.

### 5. Create the patch script

Create `~/.local/bin/plasma-kickoff-footer-patch` with this exact content:

```zsh
#!/usr/bin/env zsh
set -euo pipefail

repo=${1:-$HOME/Code/arch-packages/plasma-desktop}
cd "$repo"

typeset -a matches
matches=(src/plasma-desktop-*/applets/kickoff/Footer.qml(N))

if (( ${#matches} != 1 )); then
    print -u2 -- "[error] Expected exactly 1 Kickoff Footer.qml in src/, found ${#matches}."
    print -u2 -- "[error] Run 'makepkg -s -o' first, then re-run this script."
    exit 1
fi

target=${matches[1]}

python3 - "$target" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
src = path.read_text(encoding='utf-8')

original = """anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }"""

replacement = """anchors {
            top: parent.top
            left: tabBar.right
            leftMargin: root.spacing
            bottom: parent.bottom
        }"""

already = """anchors {
            top: parent.top
            left: tabBar.right
            leftMargin: root.spacing
            bottom: parent.bottom
        }"""

if already in src:
    print(f"[ok] Patch already present in {path}")
    raise SystemExit(0)

count = src.count(original)
if count != 1:
    print(f"[error] Expected exactly 1 original anchor block, found {count}.", file=sys.stderr)
    raise SystemExit(1)

src = src.replace(original, replacement, 1)
path.write_text(src, encoding='utf-8')
print(f"[ok] Patched {path}")
PY
```

Make it executable:

```zsh
chmod +x ~/.local/bin/plasma-kickoff-footer-patch
```

### 6. Apply the patch

Run:

```zsh
~/.local/bin/plasma-kickoff-footer-patch
```

### 7. Verify the source really changed

Run:

```zsh
FILE=(~/Code/arch-packages/plasma-desktop/src/plasma-desktop-*/applets/kickoff/Footer.qml(N))
rg -n -C 3 'left: tabBar\.right|leftMargin: root\.spacing|right: parent\.right' -- "$FILE[1]"
```

You want to see:

- `left: tabBar.right`
- `leftMargin: root.spacing`
- no remaining `right: parent.right` inside that `LeaveButtons` anchor block

### 8. Build the package

#### Simple local build

Run:

```zsh
cd ~/Code/arch-packages/plasma-desktop
makepkg -s -e -f
```

Notes:

- `-e` tells `makepkg` to reuse the already-extracted `src/` tree and skip re-extracting it
- `-f` allows overwriting any previously built package archives

#### Optional cleaner build in a chroot

If you prefer a cleaner build environment:

```zsh
mkdir -p ~/chroots/extra-x86_64
sudo mkarchroot ~/chroots/extra-x86_64/root base-devel
cd ~/Code/arch-packages/plasma-desktop
makechrootpkg -r ~/chroots/extra-x86_64 -- -e
```

This is more in line with Arch packaging practice, but the simple local build is fine for a personal one-off patch.

### 9. Install the built package

List the produced packages:

```zsh
cd ~/Code/arch-packages/plasma-desktop
packages=("${(@f)$(makepkg --packagelist)}")
printf '%s\n' "$packages[@]"
```

Then install them:

```zsh
sudo pacman -U -- "$packages[@]"
```

### 10. Reload Plasma

Log out and back in.

That is the safest way to guarantee the updated plugin gets reloaded.

### 11. Test

Open Kickoff.
The power buttons should now begin directly after the tab bar instead of being anchored against the far-right edge.

## Verify

### Confirm the installed package still only ships the plugin

```zsh
pacman -Ql plasma-desktop | rg 'org\.kde\.plasma\.kickoff|Footer\.qml'
```

### Confirm your patched extracted source still contains the new anchors

```zsh
FILE=(~/Code/arch-packages/plasma-desktop/src/plasma-desktop-*/applets/kickoff/Footer.qml(N))
sed -n '/LeaveButtons {/,/Behavior on height {/p' "$FILE[1]"
```

### See which package files were built

```zsh
cd ~/Code/arch-packages/plasma-desktop
makepkg --packagelist
```

## Rebuild after future plasma-desktop updates

When Arch updates `plasma-desktop`, your rebuilt package will eventually be replaced by the repo package unless you rebuild your patched copy again.

The normal refresh flow is:

```zsh
cd ~/Code/arch-packages/plasma-desktop
git pull
makepkg -C -s -o
~/.local/bin/plasma-kickoff-footer-patch
makepkg -s -e -f
packages=("${(@f)$(makepkg --packagelist)}")
sudo pacman -U -- "$packages[@]"
```

### Optional: temporarily stop pacman from replacing it

You can temporarily add this to `/etc/pacman.conf`:

```ini
IgnorePkg = plasma-desktop
```

That prevents `pacman -Syu` from upgrading `plasma-desktop` until you remove the line.

Use this carefully, because it also means you will not get normal upstream updates for that package while it is ignored.

## Uninstall / revert

To go back to Arch's stock package, reinstall the repo version:

```zsh
sudo pacman -S plasma-desktop
```

If you added `IgnorePkg = plasma-desktop`, remove or comment it out first.

You can also remove the helper script and build tree if you do not want to keep them:

```zsh
rm -f ~/.local/bin/plasma-kickoff-footer-patch
rm -rf ~/Code/arch-packages/plasma-desktop
```

Log out and back in again after reinstalling the stock package.

## Troubleshooting

### `makepkg -s -o` did not create `src/plasma-desktop-*/applets/kickoff/Footer.qml`

Run:

```zsh
cd ~/Code/arch-packages/plasma-desktop
find src -path '*applets/kickoff/Footer.qml' -print
```

If that returns nothing, the packaging layout or upstream source layout changed and the patch script needs to be adjusted.

### The patch script says it found 0 or more than 1 matching file

Run:

```zsh
cd ~/Code/arch-packages/plasma-desktop
find src -path '*kickoff/Footer.qml' -print
```

The script expects exactly one extracted Kickoff footer source file.

### The patch applies but nothing changes in Plasma

Log out completely and back in.
Do not rely on hot-reloading here.

### `pacman -U` wants to replace packages you were not expecting

Check the package list first:

```zsh
cd ~/Code/arch-packages/plasma-desktop
makepkg --packagelist
```

Install only the files you actually want.

## Notes

This approach avoids editing files directly under `/usr/lib` or `/usr/share`.
It also matches the current Arch packaging reality better than the old user-overlay trick, because Kickoff is shipped as a plugin rather than as an installed plasmoid package tree.

The patch itself is tiny and easy to reapply. The awkward part is only the build/install cycle.

## Sources

- Arch `plasma-desktop` package file list
- current upstream Kickoff `Footer.qml`
- KDE Plasma widget documentation for user-installed plasmoids
- Arch `pkgctl`, `makepkg`, `mkarchroot`, `makechrootpkg`, and pacman manual pages
