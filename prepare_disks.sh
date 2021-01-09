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

doWipeAllPartitions() {
	for i in $( doGetAllPartitions | sort -r ); do
		umount "$INSTALL_DEVICE_PATH/$i"
		dd if=/dev/zero of="$INSTALL_DEVICE_PATH/$i" bs=1M count=1
	done

	doFlush
}

eval "$(parse_yaml arch-install.yml)"

doCheckInstallDevice
doConfirmInstall
INSTALL_DEVICE_PATH="$(dirname "$INSTALL_DEVICE")"

doDeactivateAllSwaps
doWipeAllPartitions