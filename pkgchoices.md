
> Click [HERE](https://github.com/larsoyd/ArchLinuxTutorials/blob/main/arch_kde_tutorial.md#46-install-the-system) to go back to the tutorial.

## **OPTIONAL PACKAGES INCLUDED:**

### pkgstats 
**This** is the most "controversial" one, but here is why it shouldn't be: pkgstats is a super harmless way to help out the Arch developers that work hard and mostly for free to make our wonderful distro.
It basically just advertises a list of your core and extra packages that you use to them  so they can know what packages to 
prioritize in testing and for other things. It does not send anything else anywhere or to anyone else, but it is technically "telemetry". If you are extremely paranoid then you can leave it out.

### kitty 
kitty is a terminal that I think is the best sort of default terminal on Linux. It's easy to use, GPU accelerated, fast enough and hassle free.
It allows you to zoom in by pressing `CTRL + SHIFT and +` and zoom out by `CTRL + SHIFT and -` It doesn't look terrible like some terminals do.
konsole is included as a backup. If you want to use another terminal as your main, replace it.

### ark
ark is a KDE developed GUI software to unzip archive files on your computer, basically WinRAR for KDE Plasma. "Optional" but you are going to want this. It supports various additions, some already included like `7zip` and `unrar` .7Z and .RAR format support respectively and more. 

### cuda
**NVIDIA only.**

CUDA is NVIDIA's GPU computing and programming toolkit.

This is what software uses when it wants to run general-purpose calculations on an NVIDIA GPU rather than just draw graphics. AI/ML software, Blender rendering, scientific computing, video processing and various other programs can make use of CUDA.

It is **not required for a normal NVIDIA desktop or normal gaming**. It is also gigantic. I include it because having CUDA available is very useful on a powerful NVIDIA desktop, but if you know you will never run CUDA software you can absolutely leave this one out.



## **NOT INCLUDED IN THE STEP BUT YOU MAY WANT TO INCLUDE:**

### audiocd-kio
This adds the audiocd:/ KIO worker so Dolphin and other KDE apps can read and rip audio CDs. Not needed on non-KDE Plasma systems, but KDE has their own thing for this. If you are on a laptop with a CD player and/or ever need to play audio CDs on your PC then you are going to want this.

### libdvdread, libdvdnav, and libdvdcss
This is the same as above but for DVD playback. 

### libbluray and libaacs
Same for Blu-Rays. After you have installed the system and configured an AUR helper you may also wish to install **libbdplus** from the AUR if you want for BD+ playback. From there you will have to set it up with KEYS which is shown on the Arch Wiki about Blu-Ray.

### bluez and bluez-utils
For Bluetooth support if you use Bluetooth. You will also need to enable `bluetooth.service` then at the end of the tutorial.

### cups & cups-pdf (Optional: bluez-cups for Bluetooth printers)
If you need printer support. You will also need to enable `cups.service` at the end of the tutorial. For GUI support you need to also install `system-config-printer` & `cups-pk-helper`. For SMB browser support you need `python-pysmbc` and to be able to browse the network for remote CUPS queues and IPP network printers you also probably need `cups-browsed`

## **ESSENTIAL PACKAGES INCLUDED**

These are the packages installed in the big `pacman -S --needed` command. Most of them are identical no matter what GPU you use. Where NVIDIA, AMD and Intel need different packages that fill basically the same role I have put them together as `NVIDIA / AMD / Intel`.

### networkmanager
**This** is the actual networking service that manages Ethernet, Wi-Fi, VPN connections and basically everything else related to connecting your computer to a network.

KDE Plasma gets the nice network icon and GUI from `plasma-nm`, which is already pulled in by `plasma-meta`, but `networkmanager` is the thing underneath actually doing the work. You will enable `NetworkManager.service` later.

### reflector
This automatically retrieves the current Arch mirror list and can filter and sort mirrors so Pacman is not downloading everything from some terrible mirror on the other side of the planet.

It can also be used with `reflector.timer` to periodically refresh your mirror list.


### pipewire
This is the main modern Linux audio and multimedia routing system. Basically this is what handles your audio devices, applications, streams and connections between them.

PipeWire can also deal with video streams and screen sharing, which is particularly important on Wayland.

### pipewire-alsa
This makes normal ALSA applications work through PipeWire.

ALSA is the low-level Linux audio system and a lot of programs still talk to it directly, so this makes those programs nicely go through your PipeWire setup instead.

### pipewire-pulse
This makes PipeWire act as a replacement for a PulseAudio server.

A ridiculous amount of Linux software still expects PulseAudio, so this lets those programs work normally without actually needing to run the old PulseAudio sound server.

### pipewire-jack
This makes PipeWire act as a replacement for JACK.

JACK is mainly used by professional and low-latency audio software. You may never directly use JACK yourself, but installing this means programs expecting JACK should just work without having to maintain a completely separate JACK setup.

### wireplumber
PipeWire itself handles the streams, but something still has to decide what should connect to what.

That is basically WirePlumber. It is PipeWire's session and policy manager and handles things like which output becomes the default, device profiles, automatic routing and how newly connected audio devices should behave.

`pipewire-alsa`, `pipewire-pulse` and `pipewire-jack` also pull in the required `pipewire-audio` package automatically, so you do not have to manually put `pipewire-audio` in the command.

### plasma-meta
This is the meta package that installs KDE Plasma itself.

A meta package does not really contain the desktop. It depends on all of the packages that make up Plasma, meaning Pacman installs things like KWin, Plasma Workspace, System Settings, PowerDevil, the KDE Wayland portal, network and audio applets and the other parts expected in a normal Plasma installation.

It does **not** mean you automatically get every KDE application ever made, which is why things like Dolphin, Konsole and Ark are still explicitly installed.

### dolphin
Dolphin is KDE's default file manager and basically KDE's equivalent of Windows File Explorer.

It integrates extremely well with Plasma and supports KIO, network locations, file previews, tabs, split views, an integrated terminal and a pile of optional plugins.

### dolphin-plugins
This adds extra plugins and actions to Dolphin.

Among other things it adds integration for Git and some other version control systems along with extra actions such as mounting ISO files. It is one of those tiny packages where there is not much reason not to have it if Dolphin is your file manager.

### konsole
Konsole is KDE's terminal emulator.

I include it even though kitty is also installed because Konsole has very good KDE integration and Dolphin can use it for its built-in terminal panel. It is also a nice backup terminal to have if you somehow completely destroy your kitty configuration.

### kamera
This adds KDE integration for digital cameras supported by `gphoto2`.

This is mainly for actual cameras, not your normal USB webcam. It allows KDE applications to access photos from supported cameras more naturally.

### kio-admin
This adds the `admin://` KIO protocol.

In normal human terms, it lets Dolphin and other KDE programs manage files as administrator using a proper Polkit authentication prompt instead of encouraging you to do insane things like running the entire Dolphin file manager as root.

Very useful when you occasionally need to edit or move files somewhere your normal user cannot write to.

### plasma-login-manager
This is KDE Plasma's own graphical login manager.

It provides the login screen you see before entering your Plasma desktop and is the newer Plasma-native alternative to setups that used SDDM.

As of the current Plasma packages, `plasma-meta` already depends on `plasma-login-manager`, so explicitly writing it in the command is technically redundant. I still do not hate having it written there because it makes it extremely obvious which login manager the tutorial expects to be installed.

### kdegraphics-thumbnailers
This adds KDE thumbnail generators for additional graphics and document formats.

For Dolphin this notably adds previews for things such as PDF and PostScript files along with several other graphics formats, so your folders actually show useful thumbnails instead of generic file icons.

### ffmpegthumbs
This adds FFmpeg-based video thumbnails to Dolphin and other KDE software.

Without it a folder full of videos can just look like a folder full of identical video icons. With it KDE can grab frames from the videos and use those as proper previews.

### kdialog
This is a little KDE utility that allows shell scripts and command-line programs to display native graphical dialog boxes.

For example a script can use it to show a file picker, password prompt, confirmation box, progress bar or normal message without having to build an entire GUI application.

### tesseract
Tesseract is an OCR engine.

OCR means Optical Character Recognition, so basically it can look at text inside an image or screenshot and turn that into actual selectable text instead of just pixels.

Other applications can use Tesseract as their OCR backend, and you can also use the `tesseract` command yourself.

### tesseract-data-eng
This is the English recognition data for Tesseract.

The Tesseract program is the OCR engine itself, but it needs trained language data to actually understand a language. This package gives it English.

If you want OCR for other languages later there are equivalent packages such as `tesseract-data-nor`, `tesseract-data-deu` and so on.

### nvidia-open-dkms
**NVIDIA only.**

This installs the source for NVIDIA's open kernel modules and uses DKMS to build the NVIDIA kernel driver for your installed kernel.

The nice thing about the DKMS version is that it is not tied to one specific Arch kernel package. DKMS rebuilds the NVIDIA modules whenever the relevant kernel gets updated.

For current NVIDIA hardware from Turing through Blackwell and newer, Arch currently lists the open NVIDIA modules as the supported driver path. You still need the matching kernel headers for whatever kernel you are using.

### nvidia-utils
**NVIDIA only.**

This is the enormous NVIDIA userspace driver package.

It contains the proprietary userspace libraries that applications actually use for things like OpenGL and Vulkan and also includes NVIDIA utilities such as `nvidia-smi`.

So `nvidia-open-dkms` is basically the kernel-facing half of the driver while `nvidia-utils` supplies the userspace half.

### mesa
**AMD and Intel.**

Mesa is the main open-source userspace graphics stack used by AMD and Intel GPUs.

It provides their OpenGL implementation and a bunch of other graphics infrastructure. On AMD it also contains the Mesa VA-API video acceleration backend.

Mesa does **not** replace the vendor-specific Vulkan package below, which is why `vulkan-radeon` or `vulkan-intel` is also installed.

### vulkan-radeon / vulkan-intel
`vulkan-radeon` is the Mesa RADV Vulkan driver for AMD Radeon GPUs.

`vulkan-intel` is the Mesa Vulkan driver for Intel GPUs.

These are basically the AMD and Intel equivalents for the Vulkan part of the graphics stack. NVIDIA gets its Vulkan driver through `nvidia-utils` instead.

### vulkan-headers
This contains the Vulkan C/C++ header files and Vulkan API registry used when **building software that uses Vulkan**.

Important difference: this is not your Vulkan graphics driver.

`nvidia-utils`, `vulkan-radeon` or `vulkan-intel` is what actually makes Vulkan applications run on your GPU. `vulkan-headers` is mainly useful for development and compiling software from source.


### libva
**AMD and Intel explicitly, NVIDIA gets it pulled in through the VA-API packages here anyway.** VA-API is an interface applications can use for hardware accelerated video decoding and encoding instead of making your CPU do all of the work.


`libva` is the common Linux VA-API library.

`libva` itself is the common API. You still need a GPU-specific backend to actually talk to the hardware.

### libva-nvidia-driver / mesa / intel-media-driver
These are basically the GPU-specific VA-API backends.

For **NVIDIA**, `libva-nvidia-driver` implements VA-API using NVIDIA's NVDEC video decoding hardware.

For **AMD**, the VA-API Radeon driver is included with `mesa`.

For modern **Intel** GPUs, `intel-media-driver` provides Intel's VA-API backend.

So `libva` is the common language applications speak, while one of these packages is what translates that into something your particular GPU can actually do.

### intel-media-driver
**Intel only.**

This is Intel's modern VA-API media driver for Broadwell and newer Intel GPUs.

It provides hardware accelerated video decoding and encoding through the `iHD` VA-API driver.

Older Intel hardware may use a different VA-API driver, but for a modern Intel system this is the one you normally want.

### libva-utils
This installs utilities for testing and inspecting VA-API.

The important one is `vainfo`, which lets you see whether hardware video acceleration is actually working and which codecs your GPU/driver exposes.

Very useful because "I installed the video acceleration packages" and "video acceleration is actually working" are unfortunately not always the same sentence on Linux.


### pacman-contrib
This is a collection of useful extra tools made for Pacman systems.

It includes things such as `paccache` for cleaning old packages from the Pacman cache, `checkupdates` for safely checking for available updates and `pacdiff` for dealing with `.pacnew` configuration files.

You may not use these every day, but they are exactly the sort of utilities you eventually end up wanting on an Arch installation.

### git
Git is the version control system basically the entire software development world has collectively decided to use.

Besides using it for your own projects, it is extremely important on Arch because AUR packages, source builds and a ridiculous number of installation instructions expect `git` to exist.

If you intend to use the AUR at all, install Git.

### wget
This is a simple command-line program for downloading files from the web.

You will constantly run into commands, scripts and tutorials that use either `wget` or `curl`, so having it installed saves you from discovering it is missing at exactly the most annoying possible moment.

### hunspell
Hunspell is a spell checking engine and library.

A lot of Linux applications can use it for their spell checker instead of every application shipping a completely separate spelling system.

### hunspell-en_us
This installs the US English dictionary for Hunspell.

`hunspell` gives you the spell-checking engine, while `hunspell-en_us` gives that engine an actual English dictionary to check words against.

If you prefer another language you can install its Hunspell dictionary as well.

### quota-tools
This contains the Linux utilities for configuring and managing filesystem disk quotas.

Quotas allow you to limit how much disk space or how many files particular users or groups are allowed to consume.


### usbutils
This installs basic USB inspection utilities.

Most importantly it gives you `lsusb`, which shows all USB devices currently detected by the system.

That command is ridiculously useful whenever a controller, phone, USB adapter, capture card, DAC, keyboard or some random piece of hardware refuses to behave and you need to figure out whether Linux can even see it.

### noto-fonts
This installs Google's main Noto font collection.

Noto exists largely to stop you from getting those horrible empty square "missing character" boxes everywhere. It gives the system very broad Unicode coverage and makes a fantastic general-purpose fallback font collection.

### noto-fonts-cjk
This adds the huge Noto CJK font collection.

CJK means Chinese, Japanese and Korean. Those writing systems contain a gigantic number of characters, so they are split into their own package instead of making the normal Noto package absurdly huge.

Even if you do not speak any of those languages, you will eventually encounter those characters on websites, in filenames, games or messages.

### noto-fonts-extra
This installs additional Noto font variants not contained in the normal `noto-fonts` package.

It is fairly large, but together with the rest of Noto it gives you extremely broad font coverage and makes it much less likely that some application or website suddenly decides to display garbage because a particular font or character is unavailable.

### noto-fonts-emoji
This installs Google's Noto Color Emoji font.

In other words, this is what stops emoji from appearing as empty rectangles, weird monochrome fallback characters or not appearing at all.

### terminus-font
Terminus is a very readable monospace bitmap font designed for terminals and the Linux console.

Unlike most of the other fonts here it also includes actual console fonts, so it is useful for TTYs and not just graphical applications.

### ttf-dejavu
DejaVu is a classic general-purpose Linux font family based on Bitstream Vera but with much broader character coverage.

A ridiculous number of Linux applications have historically expected DejaVu to exist, and it makes a good fallback font for documents and older applications.

### ttf-liberation
Liberation Fonts are designed to be metrically compatible with common Microsoft fonts.

Liberation Sans is basically intended as an Arial-compatible replacement, Liberation Serif corresponds to Times New Roman and Liberation Mono corresponds to Courier New.

That makes documents and websites designed around those Microsoft fonts much less likely to have completely screwed up spacing and formatting.

### ttf-nerd-fonts-symbols
This installs the extra Nerd Font icon glyphs.

These are the little folder icons, Git symbols, arrows, operating system logos and other fancy symbols used by things like terminal prompts, status bars and CLI applications.

Instead of installing a gigantic collection of patched Nerd Fonts just to get those symbols, this gives Fontconfig a dedicated symbol font that programs can fall back to.


### zsh-completions
This adds a large collection of additional tab-completion definitions for Zsh.

Zsh already has an extremely powerful completion system. This package simply teaches it about even more commands and their options, so pressing `TAB` works properly in more programs.

If Zsh is your normal shell there is basically no reason not to install this.

### base-devel
This is the standard Arch meta package containing the basic development tools required to build Arch packages.

It pulls in things like `gcc`, `make`, `binutils`, `fakeroot`, `pkgconf`, `patch`, `autoconf`, `automake` and the other boring but absolutely necessary tools used by `makepkg`.

**If you intend to use the AUR, you want `base-devel`.** AUR package build instructions generally assume that the `base-devel` group is already installed and do not bother declaring every one of these tools as dependencies.

That is also why this is the final item in the command. Once you press Enter on this line, Pacman gets the whole list and installs the actual desktop plus all of these supporting packages.

