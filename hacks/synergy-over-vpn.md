# Wrangling multiple machines with Synergy and a VPN

I have quite a few pieces of hardware at my home office, many of which have
some sort of need for a keyboard and mouse interaction to go with the
hardware's own display monitor.

I don't want to use more than a single keyboard and mouse because, well, that's
a pain in the ass.

Traditional approaches to solve this problem of sharing a single keyboard and
mouse with multiple machines involved something called a KVM (for
[keyboard-video-mouse](https://en.wikipedia.org/wiki/KVM_switch) switch. I've used these in the past, and they work OK but
have a number of limitations and drawbacks:

* Typical KVM switches only support a small (2-3) number of machines
* Keyboard, mouse and video cables for all machines need to be connected to the
  KVM switch's "back end" ports, and then the one monitor, keyboard and mouse
  to be used for all machines are connected to the KVM switch's "front end"
* When switching from one machine to another, the KVM switch either has an
  analog button or some magic key incantation that you press to "flip" the
  control elements to the machine you wish to send the keyboard and mouse I/O to
  and the video I/O that should be passed to the one monitor connected to the KVM
  switch's front end

A more modern solution to this problem is to use an application like
[Synergy](https://symless.com/synergy) to share the keyboard and mouse that is
connected to one of your machines with all your other machines and use one
display monitor for each of your pieces of hardware.

A Synergy server daemon runs on one of your machines and the Synergy client
software runs on all your other machines. Synergy works with Windows, Mac and
Linux machines.

All of this works seamlessly... with one exception: when one of the machines
you want to install the Synergy client on needs to connect to a corporate VPN.

This article explains how to set up Synergy to share keyboard and mouse for all
your home office machines -- even when one or more of those machines need to be
connected to a corporate VPN.
