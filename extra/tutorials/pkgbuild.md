# How to read a PKGBUILD

[Return to the post-install guide](../../arch_kde_post_tutorial.md#review-aur-packages).

Read the `PKGBUILD` before installing an AUR package. It is a Bash script that tells `makepkg` where to get the source and how to turn it into a package. Reading one gets easier if you follow three things: what it downloads, what commands it runs, and what files it packages.

On an AUR package page, such as the [neofetch page](https://aur.archlinux.org/packages/neofetch), follow the **PKGBUILD** link. If you have cloned the AUR repository, you can read the file from that directory. Press Q to leave:

```zsh
# Read the recipe without running it
less PKGBUILD
```

Read it as text before running `makepkg` or letting an AUR helper build it. `makepkg` loads the file as shell code, so commands outside its functions can run immediately. Do not use `source PKGBUILD` or `bash PKGBUILD` just to inspect it.

## Example: neofetch

This is the complete recipe for neofetch **7.1.0-2** at [AUR commit f6044eb](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=neofetch&id=f6044ebf112b4ebd433764e6510f8fec68e75e5e). It is an example to read, not a block to paste into your terminal. The live package may change, so review the version you are actually installing.

```bash
# Maintainer: Morten Linderud <foxboron@archlinux.org>
# Maintainer: T.J. Townsend <blakkheim@archlinux.org>
# Contributor: Dylan Araps <dylan.araps@gmail.com>

pkgname=neofetch
pkgver=7.1.0
pkgrel=2
pkgdesc="A CLI system information tool written in BASH that supports displaying images."
arch=('any')
url="https://github.com/dylanaraps/neofetch"
license=('MIT')
depends=('bash')
makedepends=('git')
backup=('etc/neofetch/config.conf')
optdepends=(
  'catimg: Display Images'
  'chafa: Image to text support'
  'feh: Wallpaper Display'
  'imagemagick: Image cropping / Thumbnail creation / Take a screenshot'
  'jp2a: Display Images'
  'libcaca: Display Images'
  'nitrogen: Wallpaper Display'
  'w3m: Display Images'
  'xdotool: See https://github.com/dylanaraps/neofetch/wiki/Images-in-the-terminal'
  'xorg-xdpyinfo: Resolution detection (Single Monitor)'
  'xorg-xprop: Desktop Environment and Window Manager'
  'xorg-xrandr: Resolution detection (Multi Monitor + Refresh rates)'
  'xorg-xwininfo: See https://github.com/dylanaraps/neofetch/wiki/Images-in-the-terminal'
)
_commit="60d07dee6b76769d8c487a40639fb7b5a1a7bc85"
source=("git+https://github.com/dylanaraps/neofetch.git#commit=${_commit}?signed")
validpgpkeys=("7C20ADCD35D9797789B6BCC046D62DD9F1DE636E") # Dylan Araps
sha256sums=('SKIP')

package() {
  cd "${pkgname}"
  make DESTDIR="$pkgdir" install
  install -Dm644 LICENSE.md "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE.md"
}
```

## Read the package details

Start with the Bash syntax. `pkgname=neofetch` assigns a value, with no spaces around `=`. Parentheses make a list, so `depends=('bash')` contains one dependency. `$pkgname` and `${pkgname}` insert that variable's value. Double quotes allow these substitutions while keeping a path with spaces together. The opening `#` lines are comments identifying the maintainers and contributor.

The first group of fields describes the package:

| Field | What it tells you here |
| --- | --- |
| `pkgname` | The package is named `neofetch`. |
| `pkgver` and `pkgrel` | Upstream version `7.1.0`, packaging revision `2`: together, `7.1.0-2`. A packaging revision can change without a new upstream release. |
| `pkgdesc` | A short description of what the program does. |
| `arch=('any')` | The packaged files are independent of CPU architecture. Neofetch is a Bash script. |
| `url` and `license` | The project's homepage and declared license. Check these against the actual source. |
| `depends` | Packages needed to run it: Bash. |
| `makedepends` | Additional packages needed to build it: Git, used to fetch its source. |
| `optdepends` | Optional features and their dependencies. For example, `chafa: Image to text support` names a package and explains its purpose. These are not automatically required. |
| `backup` | Configuration paths for pacman's special handling during upgrades or removal. This does not create the file or back up your home directory. |

Ask whether the dependencies fit the program. Bash and optional image tools make sense for a system-information script that can display images. An unfamiliar dependency is a reason to look it up.

## Follow the source and verification

`url` is the homepage. **`source` is what makepkg actually downloads.** Check the exact host, repository owner, and project name there, even if the homepage looks correct.

In this recipe:

- `_commit` is a custom variable holding a Git commit ID. The underscore is a naming convention for a helper variable.
- `git+https://...` tells makepkg to fetch a Git repository. `#commit=${_commit}` selects that exact revision instead of following the latest branch contents.
- `?signed` requests verification of the Git revision's PGP signature.
- `validpgpkeys` restricts the accepted signing key to the listed fingerprint. Confirm the full fingerprint through a trusted source from the upstream project. A name in a comment does not establish who owns a key.
- `sha256sums=('SKIP')` skips the SHA-256 checksum for this source entry. It does **not** disable the signature check requested by `?signed`.

Other recipes often download release archives and list their checksums in the same order as `source`. A matching checksum shows that the download matches the expected bytes. A valid signature ties it to a signing key. Neither tells you whether the code is safe, and both depend on whether you trust the expected hash or key.

## Trace what the commands do

`package() { ... }` defines a function that makepkg calls to assemble the package. It starts in `$srcdir`, the directory containing the prepared sources. `$pkgdir` is a temporary staging directory whose contents become the package's filesystem layout.

Read its three commands in order:

1. `cd "${pkgname}"` enters the downloaded `neofetch` source directory.
2. `make DESTDIR="$pkgdir" install` runs the upstream Makefile's `install` target, passing the staging directory as its destination prefix. Follow that call into the [Makefile at the selected commit](https://github.com/dylanaraps/neofetch/blob/60d07dee6b76769d8c487a40639fb7b5a1a7bc85/Makefile). It copies the script to `$pkgdir/usr/bin/neofetch` and its manual to `$pkgdir/usr/share/man/man1/neofetch.1`, then makes the script executable.
3. `install -Dm644 ...` copies the license into `$pkgdir/usr/share/licenses/neofetch/LICENSE.md`. `-D` creates missing parent directories and `-m644` makes the file readable by everyone and writable by its owner.

These commands stage files for the package. Pacman installs the resulting package into the real filesystem later. `DESTDIR` works because this Makefile uses it in its paths; passing it to an unfamiliar build script is not a guarantee that the script respects it.

Notice that `backup` lists `etc/neofetch/config.conf`, but neither this function nor its Makefile installs that file. A declaration alone does not prove that a file is included. Compare the metadata with what the commands actually do.

There is no `build()` here because the Bash script does not need compilation. In other recipes, follow `prepare()` for patches and source changes, `build()` for compilation, and `check()` for tests before `package()` assembles the files. Read any other functions and top-level commands too.

## Apply the same review to other packages

Follow any patches, helper scripts, or build files the recipe uses. If it has an `install=...` field, read that file as well: it can contain commands that pacman runs during installation, upgrades, or removal.

For each command, ask what it reads, writes, downloads, or executes, and why the package needs it. Unexpected access to SSH keys or browser data, downloads from unrelated sites, hidden commands, or `sudo` inside a build function deserve investigation. Building as your normal user still gives the code access to that user's files.

Review changes when updating, especially new sources, signing keys, dependencies, or commands. An LLM can help explain an unfamiliar line, but check its explanation against the code and documentation. Reading the recipe is a starting point; you also need to trust the software it fetches.

For the full field definitions, use `man 5 PKGBUILD` or the [PKGBUILD manual](https://man.archlinux.org/man/PKGBUILD.5.en). The [makepkg manual](https://man.archlinux.org/man/makepkg.8.en) explains the build tool and its options.
