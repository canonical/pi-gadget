# Raspberry Pi "Universal" Gadget Snap

This repository contains the source for an Ubuntu Classic gadget snap that runs
universally on all Raspberry Pi 3 boards currently supported by Ubuntu Core
(the Raspberry Pi 2B, 3B, 3A+, 3B+, 4B, 400, Compute Module 3, Compute Module
3+, and Compute Module 4).

Building it with make will obtain various components from the archive,
including:

* the bootloader firmware from the linux-firmware-raspi2 package
* the device-tree(s) from the linux-modules-<ver>-raspi2 package
* u-boot binaries (for various models) from the u-boot-rpi package
* u-boot boot script from the flash-kernel package (classic gadgets only)

## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapcraft forum:
https://forum.snapcraft.io/t/the-gadget-snap/


## Reporting Issues

Please report all issues here on the github page via:
https://github.com/snapcore/pi-gadget/issues


## Building

Building natively on an armhf or arm64 system is as simple as running
`sudo SERIES=<series> make`. For example, `sudo SERIES=jammy make`.

This gadget snap can optionally be cross built on an amd64 machine.
Just add the environment variable `ARCH` to the make command. For
example, `sudo SERIES=jammy ARCH=arm64 make`.
