# Raspberry Pi "Universal" Gadget Snap

This repository contains the source for an [Ubuntu
Core](https://ubuntu.com/core) gadget snap that runs universally on all the
Raspberry Pi boards currently supported by Ubuntu Core (Raspberry Pi 2B, 3B,
3A+, 3B+, 4B, 5, Pi Zero 2 W, Compute Module 3, 3+, 4 and 5)

Building with [snapcraft](https://snapcraft.io/docs/snapcraft-overview)(see
below) will obtain the following component from the noble-updates archive:

* the bootloader firmware from the linux-firmware-raspi package

## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapcraft forum:

https://forum.snapcraft.io/t/the-gadget-snap/

## Reporting Issues

Please report all issues here on the github page via:
https://github.com/snapcore/pi-gadget/issues

## Branding

This gadget snap enables by default the boot splash. To customize it
on Ubuntu Core, you can follow the instructions provided in the UC
[documentation](https://ubuntu.com/core/docs/splash-screen).

To turn off the splash screen please edit `configs/cmdline.txt`
and remove the `splash` and the `vt.handoff=2` keywords from the
default kernel command line.

## Branches

This repository contains the following branches for Ubuntu Core versions and
the two Raspberry Pi architectures(_armhf_ and _arm64_):

* 18-arm64 - the branch for Core 18 on arm64
* 18-armhf - the branch for Core 18 on armhf
* 20-arm64 - the branch for Core 20 on arm64
* 20-armhf - the branch for Core 20 on armhf
* 22-arm64 - the branch for Core 22 on arm64
* 22-armhf - the branch for Core 22 on armhf
* 24 - the branch for Core 24 on arm64 (**default**)
* classic - the branch for Ubuntu Server images (universal gadget)
* desktop - the branch for Ubuntu Desktop images (universal gadget)

## Building

There are two general approaches to building the pi-gadget snap: _managed_ and
_manual managed_.

The easiest managed approach is to simply run `snapcraft` within the root of
this repository on a classic Ubuntu installation, such as an amd64-based Ubuntu
server or desktop, or even an arm64-based Ubuntu running on a Raspberry Pi.
Snapcraft will create either a [Multipass](https://multipass.run/) or
[LXD](https://linuxcontainers.org/lxd/introduction/) build environment and
produce the gadget snap automatically.

Another managed option is to run `snapcraft remote-build`. This command
offloads the snap build process to the [Launchpad build
farm](https://launchpad.net/builders), pushing the potentially foreign
architecture snap back to your machine when the build completes. See [Remote
build](https://snapcraft.io/docs/remote-build) for further details.

Managed build environments will mirror the distro series declared in the `base`
setting of the gadget's snapcraft.yaml, such as _core20_ or _core18_.

Manually managed builds include building the gadget snap on Ubuntu Core running
on a Raspberry Pi, for example, and systems where you want to first manually
isolate a build from the host system. In both cases, you first manually
create an LXD instance from which you can run `snapcraft --destructive-mode` to
use the instance as the build environment.

Examples of both a _managed_ build and a _manually managed_ build are outlined
below.

### Example managed build

This is likely the most convenient build method as the gadget is automatically
built within a container on the host machine.

#### Prerequisites

- An Ubuntu host (20.04 or newer is recommended)
- [Snapcraft](https://snapcraft.io/docs/snapcraft-overview)

#### Method

To build the gadget snap, switch to the appropriate branch and simply
run the `snapcraft` command:

```bash
$ git clone https://github.com/snapcore/pi-gadget
$ cd pi-gadget
$ git checkout 20-armhf
$ snapcraft
[...]
Snapped pi_20-1_armhf.snap
```

By default, _snapcraft_ attempts to build the gadget snap in a
[Multipass](https://multipass.run/) container, isolating the host system from
the build system. [Building on LXD](https://snapcraft.io/docs/build-on-lxd) is
another option that can be faster, especially when iterating over builds.

If Multipass or LXD is not already installed, _Snapcraft_ will install the
appropriate packages and run through their setup before building the gadget.

Both Multipass and LXD allow for the build architecture to differ from the
_run-on_ architecture, as defined by the `architecture` stanza in the
_snapcraft.yaml_ for the gadget snap:

```yaml
architecture
  - build-on: [amd64, armhf]
    run-on: armhf
```

See [Architectures](https://snapcraft.io/docs/architectures) for more details
on defining architectures and [Image
building](https://ubuntu.com/core/docs/board-enablement#heading--image-building)
for instructions on how to build a bootable image that includes the gadget snap.

### Example manually managed build

This method allows for the gadget snap to be built on the same hardware the
gadget is intended for.

#### Prerequisites

- A [supported Raspberry Pi](https://ubuntu.com/core/docs/supported-platforms)
  with [UC20+ installed](https://ubuntu.com/core/docs/uc20/install)
- An SSH connection to the Raspberry Pi
- Raspberry Pi internet access

#### Method

To build the gadget snap:
1. Install and set up [LXD](https://linuxcontainers.org/lxd/introduction/)
1. Launch a fresh instance of Ubuntu 20.04
1. Within the instance:
   - Install snapcraft
   - Clone the repo, switch to the appropriate build and arch branch
   - Build the gadget with snapcraft
1. Exit the instance and obtain the snap from within the container

Running the following commands on the Raspberry Pi will perform the above process:

```no-highlight
$ sudo snap install lxd
$ sudo lxd init --auto
$ sudo lxc launch ubuntu:20.04 focal
$ sudo lxc shell focal
# snap install snapcraft --classic
# git clone https://github.com/snapcore/pi-gadget/
# cd pi-gadget
# snapcraft --destructive-mode
[...]
Snapped pi_20-1_arm64.snap
# exit
$ lxc file pull focal/root/pi-gadget/pi_20-1_arm64.snap .
```

See [Image
building](https://ubuntu.com/core/docs/board-enablement#heading--image-building)
for instructions on how to build a bootable image that includes the gadget
snap.
