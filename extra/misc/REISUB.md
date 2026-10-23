# REISUB: restart a frozen system

[Return to the installation guide](../../arch_kde_tutorial.md#enable-reisub-via-sysctl).

REISUB is an emergency restart sequence for Linux. Use it as a last resort when the desktop is frozen and normal recovery, such as switching to a virtual terminal with Ctrl+Alt+F4, no longer works. It gives the kernel a chance to sync and remount filesystems before rebooting, reducing the risk associated with abruptly cutting power.

## How to use it

Hold **Alt+SysRq/Print Screen** and press **R E I S U B**, one key at a time. Allow time between the sync, remount, and reboot steps.

| Key | Action |
|---|---|
| R | Restore keyboard mode |
| E | Ask processes to terminate |
| I | Kill remaining processes |
| S | Sync filesystems |
| U | Remount filesystems read-only |
| B | Reboot immediately |

Keep a copy of this guide somewhere you can consult it when the computer is unresponsive. I remember the name by picturing Rei from *Neon Genesis Evangelion* eating a Subway sandwich. Silly, but it sticks.

## Why it is optional

The installation guide enables the required functions with `kernel.sysrq = 244`. The default described by this guide is `16`, which enables sync alone.

Magic SysRq is handled by the kernel and does not ask for a desktop password. Enabling these functions lets someone with keyboard access terminate processes, remount filesystems, or reboot the machine. Consider that tradeoff, especially for a laptop used in public.

I enable it on my desktop because I want another recovery option before resorting to the power button. It is an emergency tool, not a replacement for normal shutdown.
