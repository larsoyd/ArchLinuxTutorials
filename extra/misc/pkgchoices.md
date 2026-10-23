# Package choices

[Return to the installation guide](../../arch_kde_tutorial.md#47-install-the-desktop-packages).

These are the reasons behind the package lists. Keep the packages that suit your hardware and intended use. The main guide provides separate NVIDIA, AMD, and Intel commands.

## Optional packages included

| Package | Why I include it |
|---|---|
| `pkgstats` | Sends package usage information to Arch developers to help prioritize work. This is telemetry, so omit it if you do not want to participate. |
| `kitty` | My preferred terminal: GPU-accelerated, configurable, and easy to zoom with Ctrl+Shift+Plus or Ctrl+Shift+Minus. Konsole remains available as a backup. |
| `ark` | KDE's graphical archive manager. Tools such as `7zip`, `unrar`, and `unarchiver` extend its format support. |
| `cuda` | NVIDIA's GPU computing toolkit, useful for workloads such as rendering, scientific computing, and video processing. It is not required for ordinary desktop use or gaming. |

## Optional additions

These are not in the main desktop package lists.

| Use | Packages and setup |
|---|---|
| Audio CDs | `audiocd-kio` adds the `audiocd:/` KIO worker for reading and ripping CDs through KDE applications. |
| DVDs | `libdvdread`, `libdvdnav`, and `libdvdcss` provide DVD support. |
| Blu-ray | `libbluray` and `libaacs`; BD+ support may also need `libbdplus` from the AUR and key configuration described by the Arch Wiki. |
| Bluetooth | `bluez` and `bluez-utils`, then enable `bluetooth.service`. |
| Printing | `cups` and `cups-pdf`, then enable `cups.service`. Add `bluez-cups` for Bluetooth printers, `system-config-printer` and `cups-pk-helper` for graphical setup, `python-pysmbc` for SMB browsing, and `cups-browsed` for remote CUPS/IPP queue discovery. |

## Essential packages included

These packages appear in the desktop installation commands. Some provide the desktop itself; others supply hardware support, compatibility, or tools I expect on a general-purpose system.

### Networking and mirrors

| Package | Purpose |
|---|---|
| `networkmanager` | Manages Ethernet, Wi-Fi, and VPN connections. Plasma's network applet comes through `plasma-meta`; NetworkManager supplies the service underneath. |
| `reflector` | Filters and ranks Arch mirrors. The guide enables its timer to refresh the mirror list periodically. |

### Audio

| Package | Purpose |
|---|---|
| `pipewire` | Routes audio and multimedia streams, including video and screen sharing on Wayland. |
| `pipewire-alsa` | Connects ALSA applications to PipeWire. |
| `pipewire-pulse` | Provides the PulseAudio-compatible server interface expected by many applications. |
| `pipewire-jack` | Provides JACK compatibility for professional and low-latency audio applications. |
| `wireplumber` | Manages PipeWire sessions, device profiles, default outputs, and routing policy. |

The compatibility packages pull in `pipewire-audio`, so the guide does not list it separately.

### KDE desktop and applications

| Package | Purpose |
|---|---|
| `plasma-meta` | Installs the Plasma desktop components, including KWin, System Settings, power management, portals, and applets. Individual KDE applications are still listed separately. |
| `dolphin` | KDE's file manager, with tabs, split views, previews, network locations, and a terminal panel. |
| `dolphin-plugins` | Adds actions and integrations, including version-control support and ISO mounting. |
| `konsole` | KDE's terminal, also used by Dolphin's terminal panel. I keep it as a backup to Kitty. |
| `kamera` | Integrates digital cameras supported by gphoto2. This is for cameras, rather than ordinary USB webcams. |
| `kio-admin` | Adds authenticated administrator access through `admin://`, avoiding the need to run the entire file manager as root. |
| `plasma-login-manager` | Provides the graphical login screen. It is listed explicitly so the intended login manager is clear, even when pulled in by `plasma-meta`. |
| `kdegraphics-thumbnailers` | Adds previews for graphics and document formats, including PDF and PostScript. |
| `ffmpegthumbs` | Generates video thumbnails for Dolphin and other KDE applications. |
| `kdialog` | Lets scripts display KDE dialogs, file pickers, prompts, and progress indicators. |
| `tesseract` | Optical character recognition: extracts text from images and screenshots. |
| `tesseract-data-eng` | English recognition data for Tesseract. Other languages have separate data packages. |

### Graphics and video acceleration

| Package | Hardware and purpose |
|---|---|
| `nvidia-open-dkms` | NVIDIA open kernel modules, built by DKMS for the installed kernels. Requires matching kernel headers and supported hardware. |
| `nvidia-utils` | NVIDIA's userspace libraries for OpenGL and Vulkan, plus utilities such as `nvidia-smi`. |
| `mesa` | AMD and Intel userspace graphics support, including OpenGL and AMD's VA-API backend. |
| `vulkan-radeon` | AMD's Mesa RADV Vulkan driver. |
| `vulkan-intel` | Intel's Mesa Vulkan driver. NVIDIA gets Vulkan support through `nvidia-utils`. |
| `vulkan-headers` | Headers and API definitions for building Vulkan software. This package is not a graphics driver. |
| `libva` | The common VA-API library used by video applications. It still needs a hardware-specific backend. |
| `libva-nvidia-driver` | VA-API decoding through NVIDIA's NVDEC hardware. |
| `intel-media-driver` | Intel's `iHD` VA-API backend for supported Broadwell and newer GPUs. Older hardware may need another backend. |
| `libva-utils` | Inspection tools, particularly `vainfo`, for checking exposed video-acceleration capabilities. |

Installing a driver package does not by itself prove that an application is using hardware acceleration. Check the relevant application and `vainfo` output.

### System and development tools

| Package | Purpose |
|---|---|
| `pacman-contrib` | Tools such as `paccache`, `checkupdates`, and `pacdiff` for package and configuration maintenance. |
| `git` | Version control, also used to obtain AUR build files and source code. |
| `wget` | Downloads files from the command line. |
| [`man-db`](https://archlinux.org/packages/core/x86_64/man-db/) | Provides `man` for reading installed manuals and `apropos` for finding them by topic. |
| [`less`](https://archlinux.org/packages/core/x86_64/less/) | Scrolls and searches text in the terminal, including manuals opened with `man`. Press `/` to search and `q` to quit. |
| [`man-pages`](https://archlinux.org/packages/core/any/man-pages/) | Adds Linux system and programming manuals. Applications also ship their own manual pages with their packages. |
| `hunspell` | Spell-checking engine used by many applications. |
| `hunspell-en_us` | US English dictionary for Hunspell. Add another dictionary if needed. |
| `quota-tools` | Manages filesystem quotas for users and groups. |
| `usbutils` | USB inspection tools, especially `lsusb` for identifying connected devices. |
| `zsh-completions` | Additional command and option completions for Zsh. |
| `base-devel` | The compiler and build-tool collection expected by `makepkg` and AUR package builds. Install it if you intend to use the AUR. |

Read local documentation with commands such as `man pacman` or `man 5 PKGBUILD`. The `5` selects the manual section for file formats. These manuals remain available without an internet connection.

### Fonts

| Package | Purpose |
|---|---|
| `noto-fonts` | Broad Unicode coverage and general fallback fonts. |
| `noto-fonts-cjk` | Chinese, Japanese, and Korean fonts. |
| `noto-fonts-extra` | Additional Noto families and variants. |
| `noto-fonts-emoji` | Noto Color Emoji. |
| `terminus-font` | Readable bitmap fonts, including Linux console fonts. |
| `ttf-dejavu` | General-purpose fonts with broad character coverage, useful for older applications. |
| `ttf-liberation` | Metric-compatible alternatives to common Microsoft fonts, helping preserve document layout. |
| `ttf-nerd-fonts-symbols` | Icon glyphs for terminal prompts, status bars, and command-line applications. |
