## REISUB - WHAT? HOW? WHY?

* REISUB is an emergency restart procedure for Linux. You use it when the computer appears completely frozen and normal options, such as closing programs, switching terminals, or choosing Restart, no longer work.

---

* REISUB is activated by holding Alt + SysRq/Print Screen, then pressing R E I S U B one at a time, allowing a moment between S, U, and B. The kernel documents R as restoring keyboard mode, E and I as terminating processes, S as syncing filesystems, U as remounting read-only, and B as rebooting immediately.

* This can be a bit tough to remember since you won't use this much or ever hopefully, so the best way to remember it is to write a text file called REISUB in your home folder and just have it there so you are reminded of it. After you reboot into your system you can go on my repo and simply download this file `REISUB.md` and put it in your user folder/home manually, that way you have the reminder *and* a guide.
  
* You can also visualize Rei from Neon Genesis Evangelion eating a vegan subway sandwich.

---

* On Arch REISUB is not enabled by default due to upstream security considerations. Arch inherits the systemd default of `16`. Because Magic SysRq is handled directly by the kernel a malicious actor can use it to really mess with your day if they want to troll you. With what I enable they can remount file systems, & reboot your system without a security prompt.

* REISUB is a *last resort* fail safe to reboot a Linux system without using the power button if the system is completely unresponsive. If your system is ever frozen on Linux **YOU MUST NEVER EVER *EVER* use the power button on your comp to forcibly shut it down,** I am not joking when I say that literally every single file system issue I have ever had on Linux was the result of me doing that. Now the problem is that without REISUB the rare times that your system is completely unresponsive you have no choice but to risk your filesystem health by using the power button. Enabling REISUB solves that by giving you  one last escape hatch.

* The risks may sound scary, but for a single user desktop computer it's not really a big deal, for a laptop that you will carry around you might want to evaluate if the risk is worth it, but for the most part even there the risk is minimal. The worst case scenario is that some Linux nerd wants to be a dick for no reason and reboot your system via the keyboard. Worth noting they can literally do that via the power button anyways. TL;DR I think it is well worth the risk when you compare it to the risk of corrupting your file system via a power shutdown which mind you **is high**. However as always: [**Caveat Utilitor.**](https://legal-resources.uslegalforms.com/c/caveat-utilitor)
