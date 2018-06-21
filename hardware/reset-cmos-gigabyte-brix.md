# How to reset the CMOS battery on a Gigabyte BRIX

## Or, how to break the ultra-fast boot prison

The Gigabyte BRIX is a nice little Intel NUC-like tiny form-factor piece of
hardware. The one I have has an AMD A8-5557M integrated CPU and graphics
processor with 4 cores and 8GB RAM. It looks like this:

![My little Gigabyte BRIX](images/gigabyte-brix.jpg)

Recently, I wanted to re-image a Gigabyte BRIX machine for use as a MaaS rack
controller. The OS I had on there was Xubuntu 15.10 and I wanted to lay down a
brand new Ubuntu Desktop 18.04 image on it and start fresh.

The process of doing this is quite simple: burn the new operating system image
to a USB drive, place the USB drive in one of the USB ports on the BRIX, and
power-cycle. You should be able to hit the `Delete` key on power cycle to tell
the BRIX to enter the BIOS, at which point you can change the boot order and
set the USB drive to boot first.

In fact, this is how I remembered doing things the first time I set up the
BRIX. However, this time when I went to power cycle the hardware, the machine
would boot so quickly that it was impossible for me to enter the BIOS in order
to set the USB drive as the first boot (and therefore get to my new Ubuntu
install ISO).

Well, it turns out that at some point in the past couple years, I had (for some
unknown reason) toggled the ultra-fast boot option for the BRIX. I'm not sure
how or when I did this, and apparently it is a UEFI feature, not a BIOS
feature, but either way, the ultra-fast boot option essentially disabled my
ability to get to the BIOS at all and change the boot order. Consequently,
after about fifteen different frustrating attempts to hit the `Delete` key fast
enough on power cycle, I gave up and hit the Internets looking for a solution
to the "Can't get Gigabyte BRIX to display BIOS menu" problem.

Turns out that it's not possible to disable the ultra-fast boot option (in
Linux at least). You have to physically reset the [non-volatile BIOS
memory](https://en.wikipedia.org/wiki/Nonvolatile_BIOS_memory).

The BIOS memory is typically stored in something called "complementary
metal–oxide–semiconductor", or [CMOS](https://en.wikipedia.org/wiki/CMOS). The
CMOS allows a (very) small amount of data to be persisted even when power is
pulled from the circuitboard. However, in order to preserve this persistent
data, the CMOS uses a battery. In order to "reset the CMOS", you need to locate
this battery and remove it temporarily, which will cause the persistent data to
be reset to factory defaults.

This is a lot more involved than I had hoped, but I accomplished it and am
happy to report that my Gigabyte BRIX is now running on Ubuntu 18.04 after I
was able to get into the BIOS and change the boot order after resetting the
CMOS battery.

Since I was pretty frustrated at the lack of documentation (on both the
Gigabyte website as well as the Internet at large), I decided to write an
article about how to reset the CMOS battery on this particular hardware. Here
are the steps to take, along with pictures showing the actions to take and the
location of important bits.
