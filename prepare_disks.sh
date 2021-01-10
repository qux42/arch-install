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

doCreateNewPartitionsLvm() {
	local START="1"; local END="$BOOT_SIZE"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary fat32 "${START}MiB" "${END}GiB"

	START="$END"; END="100%"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary "${START}GiB" "${END}"

	parted -s -a optimal "$INSTALL_DEVICE" set 1 boot on
	parted -s -a optimal "$INSTALL_DEVICE" set 2 lvm on

	doFlush
	doPartProbe
}
doDetectDevicesLvm() {
	local ALL_PARTITIONS
	mapfile -t ALL_PARTITIONS < <(doGetAllPartitions)

	BOOT_DEVICE="$INSTALL_DEVICE_PATH/${ALL_PARTITIONS[0]}"
	LVM_DEVICE="$INSTALL_DEVICE_PATH/${ALL_PARTITIONS[1]}"
}
doCreateLuks() {
	doPrint "Formatting LUKS device"
	local EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup -q -y -c aes-xts-plain64 -s 512 -h sha512 luksFormat "$LUKS_DEVICE"
		EXIT="$?"
	done

	local SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" --allow-discards"
	fi

	doPrint "Opening LUKS device"
	EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup$SSD_DISCARD luksOpen "$LUKS_DEVICE" "$LUKS_NAME"
		EXIT="$?"
	done
}
#todo we don't need anymore
#doCreateLuksLvm() {
#	local LUKS_LVM_DEVICE="$LVM_DEVICE_PATH/$LUKS_NAME"
#
#	pvcreate "$LUKS_LVM_DEVICE"
#	vgcreate "$LUKS_LVM_NAME" "$LUKS_LVM_DEVICE"
#	lvcreate -l 100%FREE -n "$ROOT_LABEL" "$LUKS_LVM_NAME"
#}

doDetectDevicesLuksLvm() {
	ROOT_DEVICE="$LVM_DEVICE_PATH/$LUKS_LVM_NAME-$ROOT_LABEL"
}




doCreateLvmLuks() {
	local LUKS_LVM_DEVICE="$LVM_DEVICE_PATH/$LUKS_NAME"
	pvcreate "$LUKS_LVM_DEVICE"
	vgcreate "$LUKS_LVM_NAME" "$LUKS_LVM_DEVICE"

  if [ "$HOME_SIZE" != "0" ]
  then
  	lvcreate -L "$HOME_SIZE" -n "$HOME_LABEL" "$LUKS_LVM_NAME"
  fi

  if [ "$ROOT_SIZE" != "0" ]
  then
  	lvcreate -L "$ROOT_SIZE" -n "$ROOT_LABEL" "$LUKS_LVM_NAME"
  elif [ "$ROOT_SIZE" == "max" ]
  then
  	lvcreate -l 100%FREE -n "$ROOT_LABEL" "$LUKS_LVM_NAME"
  fi

  if [ "$HOME_SIZE" == "max" ]
  then
  	lvcreate -l 100%FREE -n "$HOME_LABEL" "$LUKS_LVM_NAME"
  fi
}

doCreateLuks2() {
	doPrint "Formatting LUKS-ROOT device"
	local EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup -q -y -c aes-xts-plain64 -s 512 -h sha512 luksFormat "$LUKS_DEVICE"
		EXIT="$?"
	done

	local SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" --allow-discards"
	fi

	doPrint "Opening LUKS device"
	EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup$SSD_DISCARD luksOpen "$LUKS_DEVICE" "$LUKS_NAME"
		EXIT="$?"
	done
}




doCheckInstallDevice
doConfirmInstall


doDeactivateAllSwaps
doWipeAllPartitions
doWipeDevice
doCreateNewPartitionTable

# luks
doCreateNewPartitionsLvm
doDetectDevicesLvm

#isDeviceSsd
#doCreateLvmLuks
#
#doCreateLuks2
#
#
#doDetectDevicesLuksLvm
#
#echo $ROOT_DEVICE