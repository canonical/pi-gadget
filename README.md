# Raspberry Pi 2 Gadget Snap

This repository contains the source for an Ubuntu Core gadget snap for the Raspberry Pi 2.

Building it with snapcraft will automatically pull, configure, patch and build
the git.denx.de/u-boot.git upstream source for rpi_2_defconfig at release v2017.05,
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

Please report all issues on the Launchpad project page
https://bugs.launchpad.net/snap-pi2/+filebug

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

## Launchpad Mirror and Automatic Builds.

All commits from the master branch of https://github.com/snapcore/pi2-gadget are
automatically mirrored by Launchpad to the https://launchpad.net/snap-pi2
project.

The master branch is automatically built from the launchpad mirror and
published into the snap store to the edge channel.

You can find build history and other controls here:
https://code.launchpad.net/~canonical-foundations/+snap/pi2
