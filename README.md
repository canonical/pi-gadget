# Raspberry Pi "Universal" Gadget Snap

This repository contains the source for an [Ubuntu
Core](https://ubuntu.com/core) gadget snap that runs universally on all the
Raspberry Pi boards currently supported by Ubuntu Core (Raspberry Pi 2B, 3B,
3A+, 3B+, 4B, Compute Module 3, and Compute Module 3+).

Building with [snapcraft](https://snapcraft.io/docs/snapcraft-overview)(see
below) will obtain various components from the bionic-updates archive,
including:

* the bootloader firmware from the linux-firmware-raspi2 package
* the device-tree(s) from the linux-modules-\<ver\>-raspi2 package
* u-boot binaries (for various models) from the u-boot-rpi package
* u-boot boot script from the flash-kernel package (classic gadgets only)

On core builds, a silent boot with a splash screen is included. The splash
screen binary comes from
[git://git.yoctoproject.org/psplash](http://git.yoctoproject.org/cgit/cgit.cgi/psplash/).
Please see the `psplash/` sub directory for patches and adjustments in use.

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
command line.

## Building

This repository contains the following branches for Ubuntu Core versions and
the two Raspberry Pi architectures:

* 18-arm64 - the branch for Core 18 on arm64
* 18-armhf - the branch for Core 18 on armhf
* 20-arm64 - the branch for Core 20 on arm64 (**default**)
* 20-armhf - the branch for Core 20 on armhf
* 22-arm64 - the branch for Core 22 on arm64
* 22-armhf - the branch for Core 22 on armhf
* classic - the branch for Ubuntu Server images (universal gadget)
* desktop - the branch for Ubuntu Desktop images (universal gadget)

To build the gadget snap, switch to the appropriate branch and
run the [snapcraft](https://snapcraft.io/docs/snapcraft-overview) command:

```bash
$ git clone https://github.com/snapcore/pi-gadget
$ cd pi-gadget
$ git checkout 20-armhf
Branch '20-armhf' set up to track remote branch '20-armhf' from 'origin'.
Switched to a new branch '20-armhf'
$ snapcraft
Launching a VM.
Launched: snapcraft-pi
[...]
Snapped pi_20-1_armhf.snap
```

By default, _snapcraft_ attempts to build the gadget snap in a
[Multipass](https://multipass.run/) container, isolating the host system from
the build system. [Building on LXD](https://snapcraft.io/docs/build-on-lxd) is
another option that can be faster, especially when iterating over builds. Both
allow for the build architecture to differ from the _run-on_ architecture, as
defined by the `architecture` stanza in the _snapcraft.yaml_ for the gadget
snap:

```yaml
architecture
  - build-on: [amd64, arm64]
    run-on: arm64
```

See [Architectures](https://snapcraft.io/docs/architectures) for more details
on defining architectures and [Image
building](https://ubuntu.com/core/docs/board-enablement#heading--image-building) 
for instructions on how to build a bootable image that includes the gadget snap.
