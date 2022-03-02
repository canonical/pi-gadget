STAGEDIR ?= "$(CURDIR)/stage"
DESTDIR ?= "$(CURDIR)/install"
ARCH ?= $(shell dpkg --print-architecture)
SERIES ?= jammy

ifeq ($(ARCH),arm64)
	MKIMAGE_ARCH := arm64
else ifeq ($(ARCH),armhf)
	MKIMAGE_ARCH := arm
else
	$(error Build architecture is not supported)
endif
ifeq ($(SERIES),bionic)
	KERNEL_FLAVOR := raspi2
else
	KERNEL_FLAVOR := raspi
endif

SERIES_HOST ?= $(shell lsb_release --codename --short)
SOURCES_HOST ?= "/etc/apt/sources.list"
SOURCES_D_HOST ?= "/etc/apt/sources.list.d"
SOURCES_MULTIVERSE := "$(STAGEDIR)/apt/multiverse.sources.list"
SOURCES_D_MULTIVERSE := "$(STAGEDIR)/apt/multiverse.sources.list.d"

# Download the latest version of package $1 for architecture $(ARCH), unpacking
# it into $(STAGEDIR). For example, the following invocation will download the
# latest version of u-boot-rpi for armhf, and unpack it under STAGEDIR:
#
#  $(call stage_package,u-boot-rpi)
#
define stage_package
	mkdir -p $(STAGEDIR)/tmp
	( \
		cd $(STAGEDIR)/tmp && \
		apt-get download \
			-o APT::Architecture=$(ARCH) \
			-o Dir::Etc::sourcelist=$(SOURCES_MULTIVERSE) \
			-o Dir::Etc::sourceparts=$(SOURCES_D_MULTIVERSE) $$( \
				apt-cache \
					-o APT::Architecture=$(ARCH) \
					-o Dir::Etc::sourcelist=$(SOURCES_MULTIVERSE) \
					-o Dir::Etc::sourceparts=$(SOURCES_D_MULTIVERSE) \
					showpkg $(1) | \
					sed -n -e 's/^Package: *//p' | \
					sort -V | tail -1 \
			); \
	)
	dpkg-deb --extract $$(ls $(STAGEDIR)/tmp/$(1)*.deb | tail -1) $(STAGEDIR)
endef

# XXX: move classic to use new "$kernel:ref" syntax too and remove the "device-trees" rule
classic: firmware device-trees config-classic no-kernel-refs-gadget

core: firmware config-core gadget

firmware: multiverse $(DESTDIR)/boot-assets
	# XXX: This deliberately does NOT use $(KERNEL_FLAVOR); not until we've
	# renamed linux-firmware-raspi2 anyway!
	$(call stage_package,linux-firmware-raspi)
	for file in fixup start bootcode; do \
		cp -a $(STAGEDIR)/usr/lib/linux-firmware-raspi/$${file}* \
			$(DESTDIR)/boot-assets/; \
	done

# XXX: This is a hack that we can hopefully get rid of eventually. Currently,
# the livefs Launchpad builders don't have multiverse enabled. We want to
# work-around that by actually enabling multiverse just for this one build here
# as we need it for linux-firmware-raspi.
multiverse:
	mkdir -p $(STAGEDIR)/apt
	cp $(SOURCES_HOST) $(SOURCES_MULTIVERSE)
	# we only copy the sources.list.d, we don't replace it to enable multiverse
	# because atm, we reallly only want to copy these files to pick up the 
	# snappy-dev image PPA if the host has it installed and we are building a
	# native build, and the snappy-dev image 
	cp -r $(SOURCES_D_HOST) $(SOURCES_D_MULTIVERSE)
	sed -i "/^deb/ s/\b$(SERIES_HOST)/$(SERIES)/" $(SOURCES_MULTIVERSE)
	sed -i "/^deb/ s/$$/ multiverse/" $(SOURCES_MULTIVERSE)
	apt-get update \
		-o Dir::Etc::sourcelist=$(SOURCES_MULTIVERSE) \
		-o Dir::Etc::sourceparts=$(SOURCES_D_MULTIVERSE) \
		-o APT::Architecture=$(ARCH) 2>/dev/null

config-core: $(DESTDIR)/boot-assets
	# The empty piboot.conf tells snapd this to use the piboot bootloader
	touch $(DESTDIR)/piboot.conf
	cp -a configs/core/config.txt.$(ARCH) $(DESTDIR)/config.txt
	sed -i 's/^kernel=.*/kernel=kernel.img/' $(DESTDIR)/config.txt
	printf '\ninitramfs initrd.img followkernel\nos_prefix=\n' >> $(DESTDIR)/config.txt
	cp -a configs/core/cmdline.txt $(DESTDIR)/cmdline.txt

config-classic: $(DESTDIR)/boot-assets
	cp -a configs/classic/*.txt $(DESTDIR)/boot-assets/
	cp -a configs/classic/config.txt.$(ARCH) $(DESTDIR)/boot-assets/config.txt
	cp -a configs/classic/user-data $(DESTDIR)/boot-assets/
	cp -a configs/classic/meta-data $(DESTDIR)/boot-assets/
	cp -a configs/classic/network-config $(DESTDIR)/boot-assets/
	cp -a configs/classic/README $(DESTDIR)/boot-assets/

device-trees: $(DESTDIR)/boot-assets
	$(call stage_package,linux-modules-[0-9]*-$(KERNEL_FLAVOR))
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtb" -a \! -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/
	mkdir -p $(DESTDIR)/boot-assets/overlays
	cp -a $$(find $(STAGEDIR)/lib/firmware/*/device-tree \
		-name "*.dtbo" -o -name "overlay_map.dtb") \
		$(DESTDIR)/boot-assets/overlays/

# ubuntu-image on classic does not understand the "$kernel:ref" syntax
# yet and will most likely only do so once it is ported to golang. Use
# the old syntax for now
no-kernel-refs-gadget: gadget.yaml
	mkdir -p $(DESTDIR)/meta
	sed -e '/source: $$kernel:/,+1d' gadget.yaml > $(DESTDIR)/meta/gadget.yaml

gadget:
	mkdir -p $(DESTDIR)/meta
	cp gadget.yaml $(DESTDIR)/meta/

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(STAGEDIR)

$(DESTDIR)/boot-assets:
	mkdir -p $(DESTDIR)/boot-assets
