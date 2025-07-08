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

default: core

core: firmware config-core gadget

firmware: $(SOURCES_RESTRICTED) $(DESTDIR)/boot-assets
	$(call stage_package,linux-firmware-$(FIRMWARE_FLAVOR))
	for file in fixup start bootcode; do \
		cp -a $(STAGEDIR)/usr/lib/linux-firmware-$(FIRMWARE_FLAVOR)/$${file}* \
			$(DESTDIR)/boot-assets/; \
	done

# All the default components got moved to main or restricted in groovy. Prior
# to this (focal and before) certain bits were (are) in universe or multiverse
# TODO: remove the '|| true' once noble 24.04 is stable
RESTRICTED_COMPONENT := $(if $(call le,$(SERIES_RELEASE),20.04),universe multiverse,restricted)
$(SOURCES_RESTRICTED):
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv C176CB99A28EA6D8 # TODO: remove this
	mkdir -p $(STAGEDIR)/apt
	mkdir -p $(STAGEDIR)/tmp
	touch $(STAGEDIR)/tmp/status
	sed -e "/^deb/ s/\bSERIES/$(SERIES)/" \
		-e "/^deb/ s/\bARCH\b/$(ARCH)/" \
		-e "/^deb/ s/\brestricted\b/$(RESTRICTED_COMPONENT)/" \
		sources.list > $(SOURCES_RESTRICTED)
	apt-get update $(APT_OPTIONS) || true

CORE_CFG := \
	piboot-core \
	common \
	$(if $(call ge,$(SERIES_RELEASE),22.04),serial-console,) \
	$(if $(call ge,$(SERIES_RELEASE),20.04),cm4-support,) \
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
	touch $(DESTDIR)/piboot.conf

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
