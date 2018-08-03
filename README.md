# Universal Raspberry Pi Gadget Snap

This repository contains the source for an Ubuntu Core gadget snap that runs
universally on all Raspberry Pi boards currently supported by Ubuntu Core (Pi2,
Pi3, Compute Module 3).

It comes with a splash screen by default and produces a completely

silent boot.
Building it with snapcraft will automatically pull, configure, patch and build
the git.denx.de/u-boot.git upstream source for the pi2 at release tag v2017.05
(for pi3/cm3 at tag v2018.07), produce a u-boot.bin binary and put it inside the gadget.

It will then download the stable binary boot firmware with tag 20180619
from https://github.com/raspberrypi/firmware/tree/stable/boot and add it to the gadget.

Last it will pull the latest linux-image-raspi2 from the bionic-updates archive, extract the
devicetree and overlay files from it and add them to the gadget as well.

The splash screen included comes from git://git.yoctoproject.org/psplash. Please see the
psplash/ sub directory for patches and adjustments in use.

## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapcraft forum:
https://forum.snapcraft.io/t/the-gadget-snap/

## Reporting Issues

Please report all issues here on the github page via:
https://github.com/ogra1/pi-kiosk-gadget/issues

## Branding

This gadget snap comes with a boot splash. To change the logo you can add a new png file to
the psplash subdirectory of this tree, adjust the "SPLASH=" option in psplash/config to
point to this file and rebuild the gadget.

To turn off the splash screen completely please edit configs/cmdline.txt and remove
the `splash` and the `vt.handoff=2` keywords from the default kernel commandline.

By default all tty's on HDMI are disabled (you can still configure the system via serial console).
To turn this feature off, remove the keyword `nogetty` from configs/cmdline.txt, this will bring back a
text console on the HDMI screen.

## Building

This gadget snap can only be cross built on an amd64 machine. To do so, just run `snapcraft`
in the top level of the source tree after cloning it to a PC.
