# Raspberry Pi "Universal" Gadget Snap

This repository contains the source for an Ubuntu Core gadget snap that runs
universally on all Raspberry Pi 3 boards currently supported by Ubuntu Core
(the Raspberry Pi 2B, 3B, 3A+, 3B+, 4B, Compute Module 3, and Compute Module
3+).

Building it with snapcraft will obtain various components from the
bionic-updates archive, including:

* the bootloader firmware from the linux-firmware-raspi2 package
* the device-tree(s) from the linux-modules-<ver>-raspi2 package
* u-boot binaries (for various models) from the u-boot-rpi package
* u-boot boot script from the flash-kernel package (classic gadgets only)

On core builds, a silent boot with a splash screen is included. The splash
screen binary comes from git://git.yoctoproject.org/psplash. Please see the
`psplash/` sub directory for patches and adjustments in use.


## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapcraft forum:
https://forum.snapcraft.io/t/the-gadget-snap/


## Reporting Issues

Please report all issues here on the github page via:
https://github.com/snapcore/pi-gadget/issues


## Branding

This gadget snap comes with a boot splash. To change the logo you can add a new
png file to the psplash subdirectory of this tree, adjust the "SPLASH=" option
in `psplash/config` to point to this file and rebuild the gadget.

To turn off the splash screen completely please edit `configs/core/cmdline.txt`
and remove the `splash` and the `vt.handoff=2` keywords from the default kernel
commandline.


## Building

This gadget snap can optionally be cross built on an amd64 machine. To do so,
just run `snapcraft` with an appropriate `--target-arch` switch, and
`--destructive-mode` in the top level of the source tree after cloning it and
selecting the appropriate branch:

    $ sudo snap install snapcraft --classic
    $ git clone https://github.com/snapcore/pi-gadget
    $ cd pi-gadget
    $ git checkout 18-arm64
    $ sudo snapcraft clean --destructive-mode
    $ sudo snapcraft snap --target-arch=arm64 --destructive-mode

The branches included are:

* 18-arm64 - the branch for Core 18 on arm64
* 18-armhf - the branch for Core 18 on armhf
* classic - the branch for Ubuntu (universal gadget)
