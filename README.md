# Raspberry Pi Gadget Snap

This repository contains the official gadget snap for the Raspberry Pi 2

## Gadget Snaps

Gadget snaps are a special type of snaps that contain device specific support
code and data. You can read more about them in the snapd wiki
https://github.com/snapcore/snapd/wiki/Gadget-snap

## Reporting Issues

Please report all issues on the Launchpad project page
https://bugs.launchpad.net/snap-pi2/+filebug

We use Launchpad to track issues as this allows us to coordinate multiple
projects better than what is available with Github issues.

## Building

To build the gadget snap locally please use `snapcraft`. This repository will
be soon updated to support snapcraft natively, via a `snapcraft.yaml` file,
stay tuned!

## Launchpad Mirror and Automatic Builds.

All commits from the master branch of github.com/snapcore/pi2 are automatically
mirrored by Launchpad to the https://launchpad.net/snap-pi2 project.

The master branch is automatically built from the launchpad mirror and
published into the snap store to the edge channel.

## Old content

This used to be in the old README file, it will be phased out over time

```
mkenvimage -r -s 131072  -o uboot.env uboot.env.in
```
