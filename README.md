# Raspberry Pi "Universal" Gadget Snap

This repository contains the source for an Ubuntu Classic gadget snap that runs
universally on all currently supported Raspberry Pi boards (the Raspberry Pi
Zero 2W, 2B, 3B, 3A+, 3B+, 4B, 400, Compute Module 3, Compute Module 3+,
Compute Module 4, and 5).

Building it with `make` will obtain various components from the Ubuntu archive,
including:

* the bootloader firmware from the linux-firmware-raspi package
* the device-tree(s) from the linux-modules-<ver>-raspi package
* u-boot binaries (for various models) from the u-boot-rpi package
* u-boot boot script from the flash-kernel package


## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapcraft forum:
https://forum.snapcraft.io/t/the-gadget-snap/


## Reporting Issues

Please report all issues here on the github page via:
https://github.com/snapcore/pi-gadget/issues


## Building

Building natively on an armhf or arm64 system is as simple as installing the
dependencies and running "make":

```console
$ sudo apt install make devscripts u-boot-tools
$ ARCH=arm64 SERIES=jammy make
```

You can set `SERIES` to the required distro-series (e.g. focal, jammy), and
`ARCH` to the target architecture (only armhf and arm64 are accepted) if you
wish to cross-build the gadget. Two targets are defined:

* server -- this is the default target and is intended for Ubuntu Server for
  Raspberry Pi images
* desktop -- this is intended for Ubuntu Desktop for Raspberry Pi images; the
  only supported architecture for desktop images is "arm64"
