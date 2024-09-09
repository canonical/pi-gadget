# The following environment variables may be customized to modify the build.
#
# STAGEDIR is the path under which packages will be unpacked in order to
# extract their content
#
# DESTDIR is the path under which the content of the gadget snap will be
# installed; the gadget snap is ultimately constructed from the contents of
# this path
#
# ARCH is the Debian-style architecture we are building for. This defaults to
# the host architecture but can be overridden for cross-building
#
# SERIES is the release we are building for. This defaults to "jammy" (22.04).

STAGEDIR ?= stage
DESTDIR ?= install
ARCH ?= $(shell dpkg --print-architecture)
SERIES ?= jammy


ifeq ($(ARCH),arm64)
MKIMAGE_ARCH := arm64
else ifeq ($(ARCH),armhf)
MKIMAGE_ARCH := arm
else
$(error Build architecture is not supported)
endif
# This is the host architecture we're building from. There should never be a
# need to override this (hence the := assignment), unlike ARCH above.
HOST_ARCH := $(shell dpkg --print-architecture)
SERIES_RELEASE := $(firstword $(shell ubuntu-distro-info --release --series=$(SERIES)))
STAGEDIR_ABS := $(shell realpath $(STAGEDIR))
DESTDIR_ABS := $(shell realpath $(DESTDIR))

APT_CONF := $(STAGEDIR_ABS)/apt/conf/apt.conf
APT := apt -c $(APT_CONF)

# Some trivial comparator macros; please note that these are very simplistic
# and have some limitations. Specifically, the two parameters are compared as
# *strings*, not numerals. For example, 10 will compare less than 2, but
# greater than 02.
#
# These are primarily intended for comparing $(SERIES_RELEASE) to specific
# values (which works as strings like 18.04 and 21.04 sort correctly for such
# operations). For example, to include a string in focal or later releases:
#
#  $(if $(call ge,$(SERIES_RELEASE),20.04),focal-or-later,before-focal)
#
le = $(findstring $(1),$(firstword $(sort $(1) $(2))))
ge = $(findstring $(2),$(firstword $(sort $(1) $(2))))
eq = $(and $(call le,$(1),$(2)),$(call ge,$(1),$(2)))
ne = $(if $(call eq,$(1),$(2)),,foo)
lt = $(and $(call le,$(1),$(2)),$(call ne,$(1),$(2)))
gt = $(and $(call ge,$(1),$(2)),$(call ne,$(1),$(2)))

KERNEL_FLAVOR := raspi
FIRMWARE_FLAVOR := $(if $(call ge,$(SERIES_RELEASE),22.04),raspi,raspi2)
# This is deliberately lazily evaluated (= not :=); it depends on the
# "device-trees" target to have been executed in order to populate the
# $(STAGEDIR)/lib/modules path
KERNEL_VERSION = $(shell ls $(STAGEDIR)/lib/modules 2>/dev/null)
# All the default components got moved to main or restricted in groovy. Prior
# to this (focal and before) certain bits were (are) in universe or multiverse
RESTRICTED_COMPONENT := $(if $(call le,$(SERIES_RELEASE),20.04),universe multiverse,restricted)


# Download the latest version of package $1 for architecture $(ARCH), unpacking
# it into $(STAGEDIR)/tmp. If you rely on this macro, your recipe must also
# rely on the local-apt target. For example, if $(ARCH) is armhf, the following
# invocation will download the latest version of u-boot-rpi for armhf, and
# unpack it under $(STAGEDIR)/tmp:
#
#  $(call stage_package,u-boot-rpi)
#
# Note that $1 may be an apt-pattern, e.g. linux-modules-[0-9]*-raspi. In this
# case the "latest" (according to a version-number sort) package name will be
# used.
#
define stage_package
	mkdir -p $(STAGEDIR)/tmp
	( \
		cd $(STAGEDIR)/tmp && \
		$(APT) download $$( \
				apt-cache -c $(APT_CONF) \
					showpkg $(1) | \
					sed -n -e 's/^Package: *//p' | \
					sort -V | tail -1 \
			); \
	)
	dpkg-deb --extract $$(ls $(STAGEDIR)/tmp/$(1)_*_*.deb | tail -1) $(STAGEDIR)
endef

# Given a space-separated list of parts in $(2), concatenate them together to
# form the file $(1), making sure there's a blank line between each
# concatenated part:
#
#  $(call make_config,config.txt,piboot common $(ARCH))
#
define make_config
	mkdir -p $(STAGEDIR)/tmp
	echo > $(STAGEDIR)/tmp/newline
	cat $(foreach part,$(2),$(STAGEDIR)/tmp/newline configs/$(1)-$(part)) | \
		tail +2 > $(DESTDIR)/boot-assets/$(1)
endef

# Given a space-separated list of parts in $(2), concatenate them together on
# a single line to form the file $(1), which is usually the kernel command
# line:
#
#  $(call make_cmdline,cmdline.txt,elevator classic)
#
define make_cmdline
	echo $(foreach part,$(2),$$(cat configs/$(1)-$(part))) > \
		$(DESTDIR)/boot-assets/$(1)
endef

# Given an input text file in $(1), containing @@-delimited variables,
# substitute suitable values and write the result to $(2):
#
#  $(call fill_template,gadget.yaml.in,gadget.yaml)
#
# If your source file uses the @@KERNEL_VERSION@@ substitution, your recipe
# must depend on the device-trees target to determine the kernel version that
# will be installed
#
define fill_template
	sed \
		-e "s/@@KERNEL_VERSION@@/$(KERNEL_VERSION)/g" \
		-e "s/@@LINUX_KERNEL_CMDLINE@@/quiet splash/g" \
		-e "s/@@LINUX_KERNEL_CMDLINE_DEFAULTS@@//g" \
		-e "s/@@UBOOT_ENV_EXTRA@@//g" \
		-e "s/@@UBOOT_PREBOOT_EXTRA@@//g" \
		-e "s/@@SERIES@@/$(SERIES)/g" \
		-e "s/@@ARCH@@/$(ARCH)/g" \
		-e "s/@@HOST_ARCH@@/$(HOST_ARCH)/g" \
		-e "s/@@RESTRICTED@@/$(RESTRICTED_COMPONENT)/g" \
		-e "s,@@CURDIR@@,$(CURDIR),g" \
		-e "s,@@STAGEDIR@@,$(STAGEDIR),g" \
		-e "s,@@DESTDIR@@,$(DESTDIR),g" \
		-e "s,@@STAGEDIR_ABS@@,$(STAGEDIR_ABS),g" \
		-e "s,@@DESTDIR_ABS@@,$(DESTDIR_ABS),g" \
		$(1) > $(2)
endef


default: server

server: firmware uboot boot-script config-server device-trees gadget

desktop: firmware uboot boot-script config-desktop device-trees gadget

core: firmware uboot boot-script config-core device-trees gadget


firmware: local-apt $(DESTDIR)/boot-assets
	$(call stage_package,linux-firmware-$(FIRMWARE_FLAVOR))
	for file in fixup start bootcode; do \
		cp -a $(STAGEDIR)/usr/lib/linux-firmware-$(FIRMWARE_FLAVOR)/$${file}* \
			$(DESTDIR)/boot-assets/; \
	done

uboot: local-apt $(DESTDIR)/boot-assets
	$(call stage_package,u-boot-rpi)
	for platform_path in $(STAGEDIR)/usr/lib/u-boot/*; do \
		cp -a $$platform_path/u-boot.bin \
			$(DESTDIR)/boot-assets/uboot_$${platform_path##*/}.bin; \
	done

boot-script: local-apt device-trees
	$(call stage_package,flash-kernel)
	# NOTE: the bootscr.rpi* below is deliberate; older flash-kernels have
	# separate bootscr.rpi[23] files for different pis, while newer have a
	# single generic bootscr.rpi file
	$(call fill_template,$(STAGEDIR)/etc/flash-kernel/bootscript/bootscr.rpi*,$(STAGEDIR)/bootscr.rpi)
	mkimage -A $(MKIMAGE_ARCH) -O linux -T script -C none -n "boot script" \
		-d $(STAGEDIR)/bootscr.rpi $(DESTDIR)/boot-assets/boot.scr

CORE_BOOT_CFG := \
	uboot-$(ARCH) \
	$(if $(call ge,$(SERIES_RELEASE),20.04),uboot-pi0-$(ARCH),) \
	uboot-core \
	common \
	$(if $(call ge,$(SERIES_RELEASE),20.04),cm4-support,) \
	fkms \
	$(if $(call lt,$(SERIES_RELEASE),20.04),heartbeat-active,heartbeat-inactive) \
	$(ARCH)
CORE_KNL_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	serial \
	core
config-core: $(DESTDIR)/boot-assets
	$(call make_config,config.txt,$(CORE_BOOT_CFG))
	$(call make_cmdline,cmdline.txt,$(CORE_KNL_CMD))
	# TODO:UC20: currently we use an empty uboot.conf as a landmark for the new
	#            uboot style where there is no uboot.env installed onto the root
	#            of the partition and instead the boot.scr is used. this may
	#            change for the final release
	touch $(DESTDIR)/uboot.conf
	# the boot.sel file is currently installed onto ubuntu-boot from the gadget
	# but that will probably change soon so that snapd installs it instead
	# it is empty now, but snapd will write vars to it
	mkenvimage -r -s 4096 -o $(DESTDIR)/boot.sel - < /dev/null

SERVER_BOOT_CFG := \
	$(if $(call eq,$(SERIES_RELEASE),20.04),legacy-header,) \
	$(if $(call le,$(SERIES_RELEASE),20.04),uboot-$(ARCH),) \
	$(if $(call eq,$(SERIES_RELEASE),20.04),uboot-pi0-$(ARCH),) \
	$(if $(call le,$(SERIES_RELEASE),20.04),uboot-classic,piboot) \
	common \
	$(if $(call ge,$(SERIES_RELEASE),20.10),serial-console,) \
	$(if $(call ge,$(SERIES_RELEASE),22.04),libcamera,) \
	$(ARCH) \
	$(if $(call ge,$(SERIES_RELEASE),24.04),kms,) \
	$(if $(call ge,$(SERIES_RELEASE),20.04),cm4-support,) \
	$(if $(call eq,$(SERIES_RELEASE),20.04),legacy-includes,)
SERVER_KNL_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	$(if $(call le,$(SERIES_RELEASE),20.04),ifnames,) \
	serial \
	classic
SERVER_NET_CONF := \
	header \
	$(if $(call le,$(SERIES_RELEASE),20.04),noregdom,) \
	common \
	ethernets \
	wifis \
	$(if $(call gt,$(SERIES_RELEASE),20.04),regdom,)
SERVER_USER_DATA := \
	header \
	$(if $(call le,$(SERIES_RELEASE),20.04),passwd-old,passwd) \
	common \
	examples
SERVER_FILES := \
	README \
	meta-data \
	$(if $(call eq,$(SERIES_RELEASE),20.04),syscfg.txt usercfg.txt,)
config-server: $(DESTDIR)/boot-assets
	$(call make_config,config.txt,$(SERVER_BOOT_CFG))
	$(call make_config,network-config,$(SERVER_NET_CONF))
	$(call make_config,user-data,$(SERVER_USER_DATA))
	$(call make_cmdline,cmdline.txt,$(SERVER_KNL_CMD))
	cp -a $(foreach file,$(SERVER_FILES),configs/$(file)) $(DESTDIR)/boot-assets/

DESKTOP_BOOT_CFG := \
	piboot \
	common \
	kms \
	cm4-support \
	$(if $(call ge,$(SERIES_RELEASE),22.04),libcamera,) \
	$(ARCH)
DESKTOP_KNL_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	$(if $(call ge,$(SERIES_RELEASE),22.04),zswap,) \
	classic \
	splash
config-desktop: $(DESTDIR)/boot-assets
	$(call make_config,config.txt,$(DESKTOP_BOOT_CFG))
	$(call make_cmdline,cmdline.txt,$(DESKTOP_KNL_CMD))
	cp -a configs/README $(DESTDIR)/boot-assets/

device-trees: local-apt $(DESTDIR)/boot-assets
	$(call stage_package,linux-modules-[0-9]*-$(KERNEL_FLAVOR))
	mkdir -p $(DESTDIR)/boot-assets
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtb" -a \! -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/
	mkdir -p $(DESTDIR)/boot-assets/overlays
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtbo" -o -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/overlays/

gadget:
	$(call fill_template,gadget.yaml.in,gadget.yaml)
	mkdir -p $(DESTDIR)/meta
	cp gadget.yaml $(DESTDIR)/meta/

clean:
	-rm -rf $(DESTDIR) $(STAGEDIR) gadget.yaml


# This sets up an apt configuration that's more or less separate from the host
# system's, including its own configuration, state, cache, and log directories.
# This way, we can run apt without requiring root privileges, and without
# messing up the host system's apt cache
local-apt:
	for dir in conf/trusted.gpg.d state cache log; do \
		mkdir -p $(STAGEDIR)/apt/$${dir}; \
	done
	touch $(STAGEDIR)/apt/state/status
	cp $$(dpkg -L ubuntu-keyring | grep "^/etc/apt/trusted\.gpg\.d/") \
		$(STAGEDIR)/apt/conf/trusted.gpg.d/
	$(call fill_template,ubuntu-archive.sources.in,$(STAGEDIR)/apt/conf/ubuntu-archive.sources)
	$(call fill_template,apt.conf.in,$(STAGEDIR)/apt/conf/apt.conf)
	$(APT) update

$(DESTDIR)/boot-assets:
	mkdir -p $@

# Some rudimentary tests for the various comparator macros above
test:
	[ $(if $(call gt,1,2),fail,pass) = "pass" ] # 1 > 2
	[ $(if $(call gt,2,1),pass,fail) = "pass" ] # 2 > 1
	[ $(if $(call gt,2,2),fail,pass) = "pass" ] # 2 > 2
	[ $(if $(call ge,1,2),fail,pass) = "pass" ] # 1 >= 2
	[ $(if $(call ge,2,1),pass,fail) = "pass" ] # 2 >= 1
	[ $(if $(call ge,2,2),pass,fail) = "pass" ] # 2 >= 2
	[ $(if $(call lt,1,2),pass,fail) = "pass" ] # 1 < 2
	[ $(if $(call lt,2,1),fail,pass) = "pass" ] # 2 < 1
	[ $(if $(call lt,2,2),fail,pass) = "pass" ] # 2 < 2
	[ $(if $(call le,1,2),pass,fail) = "pass" ] # 1 <= 2
	[ $(if $(call le,2,1),fail,pass) = "pass" ] # 2 <= 1
	[ $(if $(call le,2,2),pass,fail) = "pass" ] # 2 <= 2
	[ $(if $(call ne,1,2),pass,fail) = "pass" ] # 1 != 2
	[ $(if $(call ne,1,1),fail,pass) = "pass" ] # 1 != 1
	[ $(if $(call eq,1,2),fail,pass) = "pass" ] # 1 == 2
	[ $(if $(call eq,1,1),pass,fail) = "pass" ] # 1 == 1
	[ $(if $(call gt,10,02),pass,fail) = "pass" ] # 10 > 02

.PHONY: local-apt
