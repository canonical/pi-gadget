STAGEDIR ?= "$(CURDIR)/stage"
DESTDIR ?= "$(CURDIR)/install"
ARCH ?= $(shell dpkg --print-architecture)
SERIES ?= focal

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
SOURCES_RESTRICTED := "$(STAGEDIR)/apt/restricted.sources.list"

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
			-o Dir::Etc::sourcelist=$(SOURCES_RESTRICTED) $$( \
				apt-cache \
					-o APT::Architecture=$(ARCH) \
					-o Dir::Etc::sourcelist=$(SOURCES_RESTRICTED) \
					showpkg $(1) | \
					sed -n -e 's/^Package: *//p' | \
					sort -V | tail -1 \
			); \
	)
	dpkg-deb --extract $$(ls $(STAGEDIR)/tmp/$(1)*.deb | tail -1) $(STAGEDIR)
endef


classic: firmware uboot boot-script config-classic device-trees gadget

core: firmware uboot boot-script config-core device-trees gadget

firmware: restricted $(DESTDIR)/boot-assets
	# XXX: This deliberately does NOT use $(KERNEL_FLAVOR); not until we've
	# renamed linux-firmware-raspi2 anyway!
	$(call stage_package,linux-firmware-raspi2)
	for file in fixup start bootcode; do \
		cp -a $(STAGEDIR)/usr/lib/linux-firmware-raspi2/$${file}* \
			$(DESTDIR)/boot-assets/; \
	done

# XXX: This is a hack that we can hopefully get rid of eventually. At this
# moment livecd-rootfs doesn't enable restricted at this stage, so we need to
# hack around it to pull in linux-firmware-raspi2 properly.
restricted:
	mkdir -p $(STAGEDIR)/apt
	cp $(SOURCES_HOST) $(SOURCES_RESTRICTED)
	sed -i "/^deb/ s/\b$(SERIES_HOST)/$(SERIES)/" $(SOURCES_RESTRICTED)
	sed -i "/^deb/ s/$$/ restricted/" $(SOURCES_RESTRICTED)
	apt-get update \
		-o Dir::Etc::sourcelist=$(SOURCES_RESTRICTED) \
		-o APT::Architecture=$(ARCH) 2>/dev/null

# XXX: This should be removed (along with the dependencies in classic/core)
# when uboot is removed entirely from the boot partition. At present, it is
# included on the boot partition but not in the configuration just in case
# anyone requires an easy path to switch back to it
uboot: $(DESTDIR)/boot-assets
	$(call stage_package,u-boot-rpi)
	for platform_path in $(STAGEDIR)/usr/lib/u-boot/*; do \
		cp -a $$platform_path/u-boot.bin \
			$(DESTDIR)/boot-assets/uboot_$${platform_path##*/}.bin; \
	done

boot-script: device-trees $(DESTDIR)/boot-assets
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

config-core: $(DESTDIR)/boot-assets
	# TODO:UC20: currently we use an empty uboot.conf as a landmark for the new
	#            uboot style where there is no uboot.env installed onto the root
	#            of the partition and instead the boot.scr is used. this may 
	#            change for the final release
	touch $(DESTDIR)/uboot.conf
	# the boot.sel file is currently installed onto ubuntu-boot from the gadget
	# but that will probably change soon so that snapd installs it instead
	# it is empty now, but snapd will write vars to it
	mkenvimage -r -s 4096 -o $(DESTDIR)/boot.sel - < /dev/null
	cp -a configs/core/config.txt.$(ARCH) $(DESTDIR)/boot-assets/config.txt
	cp -a configs/core/cmdline.txt $(DESTDIR)/boot-assets/cmdline.txt

config-classic: $(DESTDIR)/boot-assets
	cp -a configs/classic/*.txt $(DESTDIR)/boot-assets/
	cat configs/classic/config.txt-$(ARCH) >> $(DESTDIR)/boot-assets/config.txt
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

gadget:
	mkdir -p $(DESTDIR)/meta
	cp gadget.yaml $(DESTDIR)/meta/

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(STAGEDIR)

$(DESTDIR)/boot-assets:
	mkdir -p $(DESTDIR)/boot-assets
