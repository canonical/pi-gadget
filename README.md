# Universal Raspberry Pi Kiosk Gadget Snap

This repository contains the source for an Ubuntu Core gadget snap that runs
on all Raspberry Pi boards.

It comes with a splash screen by default and produces a completely
silent boot to be used in Kiosk setups (there is no login prompt and it is expected
that a graphical kiosk app starts on screen after booting. Any low level interaction
with the system needs to happen through a serial console).

Building it with snapcraft will automatically pull, configure, patch and build
the git.denx.de/u-boot.git upstream source for the pi2 and 3 at release v2017.05,
produce a u-boot.bin binary and put it inside the gadget.

It will then download the latest stable binary boot firmware
from https://github.com/raspberrypi/firmware/tree/stable/boot and add it to the gadget.

Last it will pull the latest linux-image-raspi2 from the xenial-updates archive, extract the
devicetree and overlay files from it and add them to the gadget as well.


## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapd wiki
https://github.com/snapcore/snapd/wiki/Gadget-snap

## Reporting Issues

Please report all issues here on the github page via:
https://github.com/ogra1/pi-kiosk-gadget/issues

We use Launchpad to track issues as this allows us to coordinate multiple
projects better than what is available with Github issues.

## Branding

This gadget snap comes with a boot splash, to change the logo you can add a new png file to
the psplash subdirectory of this tree, adjust the "SPLASH=" option in psplash/config to
point to this file and rebuild the gadget.

To turn off the splash screen completely please edit config/cmdline.txt and remove
the "splash" and the "vt.handoff=2" keywords from the default kernel commandline.

## Building

To build the gadget snap locally on an armhf system please use `snapcraft`.

To cross build this gadget snap on a PC please run `snapcraft --target-arch=armhf`
