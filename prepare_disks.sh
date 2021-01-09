#!/usr/bin/env bash

source functions.sh

doCheckInstallDevice() {
	if [ ! -b "$INSTALL_DEVICE" ]; then
		printf "ERROR: INSTALL_DEVICE is not a block device ('%s')\n" "$INSTALL_DEVICE"
		exit 1
	fi
}
doConfirmInstall() {
	lsblk
	doPrint "Installing to '$INSTALL_DEVICE' - ALL DATA ON IT WILL BE LOST!"
	doPrint "Enter 'YES' (in capitals) to confirm and start the installation."

	doPrintPrompt "> "
	read -r i
	if [ "$i" != "YES" ]; then
		doPrint "Aborted."
		exit 0
	fi

	for i in {10..1}; do
		doPrint "Starting in $i - Press CTRL-C to abort..."
		sleep 1
	done
}
doDeactivateAllSwaps() {
	swapoff -a
}
doGetAllPartitions() {
	lsblk -l -n -o NAME -x NAME "$INSTALL_DEVICE" | grep "^$INSTALL_DEVICE_FILE" | grep -v "^$INSTALL_DEVICE_FILE$"
}
doFlush() {
	sync
	sync
	sync
}
doPartProbe() {
	partprobe "$INSTALL_DEVICE"
}
doWipeAllPartitions() {
	for i in $( doGetAllPartitions | sort -r ); do
		umount "$INSTALL_DEVICE_PATH/$i"
		dd if=/dev/zero of="$INSTALL_DEVICE_PATH/$i" bs=1M count=1
	done

	doFlush
}
doWipeDevice() {
	dd if=/dev/zero of="$INSTALL_DEVICE" bs=1M count=1

	doFlush
	doPartProbe
}
doCreateNewPartitionTable() {
	parted -s -a optimal "$INSTALL_DEVICE" mklabel gpt
}

doCreateNewPartitionsLuks() {
	local START="1"; local END="$BOOT_SIZE"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary fat32 "${START}MiB" "${END}MiB"

	START="$END"; END="100%"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary "${START}MiB" "${END}MiB"

	parted -s -a optimal "$INSTALL_DEVICE" set 1 boot on
	parted -s -a optimal "$INSTALL_DEVICE" set 2 lvm on

	doFlush
	doPartProbe
}


eval "$(parse_yaml arch-install.yml)"

doCheckInstallDevice
doConfirmInstall
INSTALL_DEVICE_PATH="$(dirname "$INSTALL_DEVICE")"

doDeactivateAllSwaps
doWipeAllPartitions
doWipeDevice
doCreateNewPartitionTable
doCreateNewPartitionsLuks