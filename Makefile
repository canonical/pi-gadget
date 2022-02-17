STAGEDIR ?= "$(CURDIR)/stage"
DESTDIR ?= "$(CURDIR)/install"
ARCH ?= $(shell dpkg --print-architecture)
SERIES ?= jammy

SOURCES_RESTRICTED := "$(STAGEDIR)/apt/restricted.sources.list"
SERIES_RELEASE := $(firstword $(shell ubuntu-distro-info --release --series=$(SERIES)))
APT_OPTIONS := \
	-o APT::Architecture=$(ARCH) \
	-o Dir::Etc::sourcelist=$(SOURCES_RESTRICTED) \
	-o Dir::State::status=$(STAGEDIR)/tmp/status

ifeq ($(ARCH),arm64)
MKIMAGE_ARCH := arm64
else ifeq ($(ARCH),armhf)
MKIMAGE_ARCH := arm
else
$(error Build architecture is not supported)
endif

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

KERNEL_FLAVOR := $(if $(call gt,$(SERIES_RELEASE),18.04),raspi,raspi2)
FIRMWARE_FLAVOR := $(if $(call ge,$(SERIES_RELEASE),22.04),raspi,raspi2)

# Download the latest version of package $1 for architecture $(ARCH), unpacking
# it into $(STAGEDIR). If you rely on this macro, your recipe must also rely on
# the $(SOURCES_RESTRICTED) target. For example, the following invocation will
# download the latest version of u-boot-rpi for armhf, and unpack it under
# STAGEDIR:
#
#  $(call stage_package,u-boot-rpi)
#
define stage_package
	( \
		cd $(STAGEDIR)/tmp && \
		apt-get download $(APT_OPTIONS) $$( \
				apt-cache $(APT_OPTIONS) \
					showpkg $(1) | \
					sed -n -e 's/^Package: *//p' | \
					sort -V | tail -1 \
			); \
	)
	dpkg-deb --extract $$(ls $(STAGEDIR)/tmp/$(1)*.deb | tail -1) $(STAGEDIR)
endef

# Given a space-separated list of parts in $(1), concatenate them together to
# form the boot config.txt, making sure there's a blank line between each
# concatenated part:
#
#  $(call make_boot_config,piboot common $(ARCH))
#
define make_boot_config
	mkdir -p $(STAGEDIR)/tmp
	echo > $(STAGEDIR)/tmp/newline
	cat $(foreach part,$(1),$(STAGEDIR)/tmp/newline configs/config.txt-$(part)) | \
		tail +2 > $(DESTDIR)/boot-assets/config.txt
endef

# Given a space-separated list of parts in $(1), concatenate them together on
# a single line to form the kernel cmdline.txt:
#
#  $(call make_boot_cmdline,elevator classic)
#
define make_boot_cmdline
	echo $(foreach part,$(1),$$(cat configs/cmdline.txt-$(part))) > \
		$(DESTDIR)/boot-assets/cmdline.txt
endef

server: firmware uboot boot-script config-server device-trees gadget

desktop: firmware uboot boot-script config-desktop device-trees gadget

core: firmware uboot boot-script config-core device-trees gadget

firmware: $(SOURCES_RESTRICTED) $(DESTDIR)/boot-assets
	$(call stage_package,linux-firmware-$(FIRMWARE_FLAVOR))
	for file in fixup start bootcode; do \
		cp -a $(STAGEDIR)/usr/lib/linux-firmware-$(FIRMWARE_FLAVOR)/$${file}* \
			$(DESTDIR)/boot-assets/; \
	done

# All the default components got moved to main or restricted in groovy. Prior
# to this (focal and before) certain bits were (are) in universe or multiverse
RESTRICTED_COMPONENT := $(if $(call le,$(SERIES_RELEASE),20.04),universe multiverse,restricted)
$(SOURCES_RESTRICTED):
	mkdir -p $(STAGEDIR)/apt
	mkdir -p $(STAGEDIR)/tmp
	touch $(STAGEDIR)/tmp/status
	sed -e "/^deb/ s/\bSERIES/$(SERIES)/" \
		-e "/^deb/ s/\bARCH\b/$(ARCH)/" \
		-e "/^deb/ s/\brestricted\b/$(RESTRICTED_COMPONENT)/" \
		sources.list > $(SOURCES_RESTRICTED)
	apt-get update $(APT_OPTIONS)

# XXX: This should be removed (along with the dependencies in classic/core)
# when uboot is removed entirely from the boot partition. At present, it is
# included on the boot partition but not in the configuration just in case
# anyone requires an easy path to switch back to it
uboot: $(SOURCES_RESTRICTED) $(DESTDIR)/boot-assets
	$(call stage_package,u-boot-rpi)
	for platform_path in $(STAGEDIR)/usr/lib/u-boot/*; do \
		cp -a $$platform_path/u-boot.bin \
			$(DESTDIR)/boot-assets/uboot_$${platform_path##*/}.bin; \
	done

boot-script: $(SOURCES_RESTRICTED) device-trees $(DESTDIR)/boot-assets
	$(call stage_package,flash-kernel)
	# NOTE: the bootscr.rpi* below is deliberate; older flash-kernels have
	# separate bootscr.rpi? files for different pis, while newer have a
	# single generic bootscr.rpi file
	for kvers in $(STAGEDIR)/lib/modules/*; do \
		sed \
			-e "s/@@KERNEL_VERSION@@/$${kvers##*/}/g" \
			-e "s/@@LINUX_KERNEL_CMDLINE@@/quiet splash/g" \
			-e "s/@@LINUX_KERNEL_CMDLINE_DEFAULTS@@//g" \
			-e "s/@@UBOOT_ENV_EXTRA@@//g" \
			-e "s/@@UBOOT_PREBOOT_EXTRA@@//g" \
			$(STAGEDIR)/etc/flash-kernel/bootscript/bootscr.rpi* \
			> $(STAGEDIR)/bootscr.rpi; \
	done
	mkimage -A $(MKIMAGE_ARCH) -O linux -T script -C none -n "boot script" \
		-d $(STAGEDIR)/bootscr.rpi $(DESTDIR)/boot-assets/boot.scr

CORE_CFG := \
	uboot-$(ARCH) \
	$(if $(call ge,$(SERIES_RELEASE),20.04),uboot-pi0-$(ARCH),) \
	uboot-core \
	$(if $(call ge,$(SERIES_RELEASE),20.04),cm4-support,) \
	common \
	fkms \
	$(if $(call lt,$(SERIES_RELEASE),20.04),heartbeat-active,heartbeat-inactive) \
	$(ARCH)
CORE_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	serial \
	core
config-core: $(DESTDIR)/boot-assets
	$(call make_boot_config,$(CORE_CFG))
	$(call make_boot_cmdline,$(CORE_CMD))
	# TODO:UC20: currently we use an empty uboot.conf as a landmark for the new
	#            uboot style where there is no uboot.env installed onto the root
	#            of the partition and instead the boot.scr is used. this may
	#            change for the final release
	touch $(DESTDIR)/uboot.conf
	# the boot.sel file is currently installed onto ubuntu-boot from the gadget
	# but that will probably change soon so that snapd installs it instead
	# it is empty now, but snapd will write vars to it
	mkenvimage -r -s 4096 -o $(DESTDIR)/boot.sel - < /dev/null

SERVER_CFG := \
	$(if $(call eq,$(SERIES_RELEASE),20.04),legacy-header,) \
	$(if $(call le,$(SERIES_RELEASE),20.04),uboot-$(ARCH),) \
	$(if $(call eq,$(SERIES_RELEASE),20.04),uboot-pi0-$(ARCH),) \
	$(if $(call le,$(SERIES_RELEASE),20.04),uboot-classic,piboot) \
	common \
	$(if $(call ge,$(SERIES_RELEASE),20.10),serial-console,) \
	$(if $(call ge,$(SERIES_RELEASE),22.04),libcamera,) \
	$(ARCH) \
	$(if $(call ge,$(SERIES_RELEASE),20.04),cm4-support,) \
	$(if $(call eq,$(SERIES_RELEASE),20.04),legacy-includes,)
SERVER_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	$(if $(call le,$(SERIES_RELEASE),20.04),ifnames,) \
	serial \
	classic
SERVER_FILES := \
	README \
	user-data \
	meta-data \
	network-config \
	$(if $(call eq,$(SERIES_RELEASE),20.04), syscfg.txt usercfg.txt,)
config-server: $(DESTDIR)/boot-assets
	$(call make_boot_config,$(SERVER_CFG))
	$(call make_boot_cmdline,$(SERVER_CMD))
	cp -a $(foreach file,$(SERVER_FILES),configs/$(file)) $(DESTDIR)/boot-assets/

DESKTOP_CFG := \
	piboot \
	cm4-support \
	common \
	kms \
	$(if $(call ge,$(SERIES_RELEASE),22.04),libcamera,) \
	$(ARCH)
DESKTOP_CMD := \
	$(if $(call lt,$(SERIES_RELEASE),22.04),elevator,) \
	$(if $(call ge,$(SERIES_RELEASE),22.04),zswap,) \
	classic
config-desktop: $(DESTDIR)/boot-assets
	$(call make_boot_config,$(DESKTOP_CFG))
	$(call make_boot_cmdline,$(DESKTOP_CMD))
	cp -a configs/README $(DESTDIR)/boot-assets/

device-trees: $(SOURCES_RESTRICTED) $(DESTDIR)/boot-assets
	$(call stage_package,linux-modules-[0-9]*-$(KERNEL_FLAVOR))
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtb" -a \! -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/
	mkdir -p $(DESTDIR)/boot-assets/overlays
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtbo" -o -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/overlays/

gadget:
	mkdir -p $(DESTDIR)/meta
	cp gadget.yaml $(DESTDIR)/meta/

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(STAGEDIR)

$(DESTDIR)/boot-assets:
	mkdir -p $(DESTDIR)/boot-assets

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
