==================
The Boot Partition
==================

This file belongs to the boot partition of the Ubuntu Server for Raspberry Pi.
This partition is usually mounted at /boot/firmware at runtime (in contrast to
RaspiOS where it is typically mounted on /boot).

The files on this partition are described in the following sections, firstly
the user-editable files, followed by non-user-editable.


config.txt
==========

Contains the bootloader configuration. This is primarily of interest for
adding device-tree overlays and parameters to describe any hardware attached
to the system which cannot be auto-detected. Most official HATs should be
automatically recognized, but some third-party devices may need a "dtoverlay"
line added to the end of this file.

This file also tells the bootloader the location of the kernel (vmlinuz; see
below), and initial ramdisk (initrd; see below) but, in general, there is no
need to modify these settings.

The format of the file is roughly ini-like and is described fully at:

https://www.raspberrypi.com/documentation/computers/config_txt.html


cmdline.txt
===========

The Linux kernel command line. This typically defines the location of the root
partition; you may need to edit this if you are using alternate media for your
root storage. It also specifies the available login consoles including any
serial consoles. On Ubuntu Server, it is also useful for specifying remote
seeds for cloud-init by appending something like:

ds=nocloud-net;seedfrom=http://10.0.0.2:8000/

Where 10.0.0.2:8000 is an HTTP server serving alternative meta-data, user-data,
and (optionally) vendor-data files. Please note network-config is *not* sourced
from remote seeds.

It is worth noting that the command line specified here is further augmented by
the bootloader (start*.elf; see below) before it is passed to the Linux kernel.
To see the "final" command line at runtime, query /proc/cmdline.

The format of the file is a single line (or more precisely anything beyond the
first line is ignored), and is described fully at:

https://docs.kernel.org/admin-guide/kernel-parameters.html


network-config
==============

The initial netplan configuration for the network.

The format of this file is YAML, in the form expected by netplan which is
documented at:

https://netplan.io/

Examples for wifi and ethernet are included, but you may also configure bonds,
bridges, etc. in this file.


meta-data
=========

The meta-data of the cloud-init seed. This mostly exists to define the
identifier of the instance, but also to specify that the data-source in this
case is entirely local (the user-data file; see below). If you wish to use a
remote data-source with cloud-init, you can override this and specify that
source by appending something like the following to cmdline.txt:

ds=nocloud-net;seedfrom=http://10.0.0.2:8000/

Where 10.0.0.2:8000 is an HTTP server serving alternate meta-data, user-data,
and (optionally) vendor-data files. Please note that network-config will *not*
be read from remote data-sources; only the local one will be applied.

The format of this file is YAML, and is documented at:

https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html


user-data
=========

The user-data of the cloud-init seed. This can be used to customize numerous
aspects of the system upon first boot, from the default user, the default
password, whether or not SSH permits password authentication, import of SSH
keys, the keyboard layout, the system hostname, package installation, creation
of arbitrary files, etc. Numerous examples are included (mostly commented) in
the default user-data.

The format of this file is YAML, and is documented at:

https://cloudinit.readthedocs.io/en/latest/topics/modules.html
https://cloudinit.readthedocs.io/en/latest/topics/examples.html


bootcode.bin (non-editable)
===========================

This is the second stage bootloader used on all models of Pi prior to the Pi 4
(i.e. the 2B, 3B, 3B+, 3A+, Zero 2W, CM3, and CM3+). On the Pi 4 (and later)
this is replaced by the onboard boot EEPROM.

This file is sourced from the linux-firmware-raspi package and written to the
boot partition by the flash-kernel process.


start*.elf, fixup*.dat (non-editable)
=====================================

This is the tertiary bootloader used on all models of Pi. This is the
executable that loads the Linux kernel (see vmlinuz below) and initramfs (see
initrd.img below), and then launches the Linux kernel passing it the address of
the initramfs. The bootloader is (mostly) configured by the config.txt (see
above) which specifies the location of the kernel and initramfs to load.

These files are sourced from the linux-firmware-raspi package and written to
the boot partition by the flash-kernel process.


vmlinuz (non-editable)
======================

This is the compressed Linux kernel which is loaded, unpacked, and executed
by the start*.elf bootloader.

This file is sourced from some variant of the linux-image-*VERSION*-raspi
package and written to the boot partition by the flash-kernel process.


initrd.img (non-editable)
=========================

This is the "initial ramdisk" which the Linux kernel executes first. It
contains all modules and utilities necessary to find and mount to the "real"
root partition. Its content can be inspected with the "unmkinitramfs" tool, and
its generation can be influenced by the configuration files under
/etc/initramfs-tools/.

This file is generated by the utilities in the initramfs-tools package (in
particular mkinitramfs), and written to the boot partition by the flash-kernel
process.


bcm*.dtb (non-editable)
=======================

These are the "device-tree" files which describe the hardware of a particular
model of Raspberry Pi. The device-tree to load is automatically determined by
the bootloader (start*.elf), which also modifies the device-tree (e.g. fixing
up the amount of memory on the Pi 4) before passing it to the Linux kernel.


overlays/*.dtbo (non-editable)
==============================

This directory contains "device-tree overlays" which supplement the "base"
device-tree passed to the Linux kernel. Some overlays are loaded automatically
(e.g. via the HAT specification). Others must be specified manually with
"dtoverlay=" lines in config.txt (see above). Device trees may also be
customized with parameters which may be specified as "dtparam=" lines in
config.txt.
