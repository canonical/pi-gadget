#!/bin/sh

set -eu
set -x

STAGEDIR="${CRAFT_PART_BUILD:-stage}"
DESTDIR="${CRAFT_PART_INSTALL:-install}"
SERIES="${SERIES:-jammy}"

APT_CONF_DIR="$STAGEDIR"/apt/conf
APT_CONF="$APT_CONF_DIR"/apt.conf

main() {
	mkdir -p "$DESTDIR"/boot-assets/
	local_apt

	make_piboot
	make_firmware
	make_config
	make_device_trees
}

make_piboot() {
	touch "$DESTDIR"/piboot.conf
}

make_firmware() {
	stage_package "linux-firmware-raspi"
	for file in fixup start bootcode; do
		cp -a "$STAGEDIR"/usr/lib/linux-firmware-raspi/"$file"* \
			"$DESTDIR"/boot-assets/
	done
}

make_config() {
	cp -a config.txt "$DESTDIR"/boot-assets/
	cp -a cmdline.txt "$DESTDIR"/boot-assets/
}

make_device_trees() {
	stage_package "linux-modules-[0-9]*-raspi"
	find "$STAGEDIR"/lib/firmware/*/device-tree \
		-name "*.dtb" -a \! -name "overlay_map.dtb" | while read -r file
	do
		cp "$file" "$DESTDIR"/boot-assets/
	done
	mkdir -p "$DESTDIR"/boot-assets/overlays
	find "$STAGEDIR"/lib/firmware/*/device-tree \
		-name "*.dtbo" -o -name "overlay_map.dtb" | while read -r file
	do
		cp "$file" "$DESTDIR"/boot-assets/overlays/
	done
}

stage_package() {
	package="$1"
	apt_conf="$(realpath "$APT_CONF")"

	mkdir -p "$STAGEDIR"/tmp
	cd "$STAGEDIR"/tmp
	apt -c "$apt_conf" download "$(
		apt-cache -c "$apt_conf" showpkg "$package" |
			sed -n -e 's/^Package: *//p' |
			sort -V | tail -1
	)"
	cd "$OLDPWD"
	dpkg-deb --extract "$(
		find "$STAGEDIR/tmp" -name "${package}_*_*.deb" | tail -1
	)" "$STAGEDIR"
}

local_apt() {
	for dir in conf/trusted.gpg.d state cache log; do
		mkdir -p "$STAGEDIR"/apt/"$dir"
	done
	touch "$STAGEDIR"/apt/state/status
	dpkg -L ubuntu-keyring | grep "^/etc/apt/trusted\.gpg\.d/" | while read -r key; do
		cp "$key" "$STAGEDIR"/apt/conf/trusted.gpg.d/
	done
	fill_template ubuntu-archive.sources.in "$APT_CONF_DIR"/ubuntu-archive.sources
	fill_template apt.conf.in "$APT_CONF"
	apt -c "$APT_CONF" update
}

fill_template() {
	template="$1"
	outfile="$2"

	sed \
		-e "s/@@LINUX_KERNEL_CMDLINE@@/quiet splash/g" \
		-e "s/@@LINUX_KERNEL_CMDLINE_DEFAULTS@@//g" \
		-e "s/@@SERIES@@/$SERIES/g" \
		-e "s,@@STAGEDIR@@,$STAGEDIR,g" \
		-e "s,@@STAGEDIR_ABS@@,$(realpath "$STAGEDIR"),g" \
		-e "s,@@DESTDIR@@,$DESTDIR,g" \
		-e "s,@@DESTDIR_ABS@@,$(realpath "$DESTDIR"),g" \
		"$template" > "$outfile"
}

main "$@"
