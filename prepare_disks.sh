#!/usr/bin/env bash
set -x
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
#todo remove
#doCreateLuks() {
#	doPrint "Formatting LUKS device"
#	local EXIT="1"
#	while [ "$EXIT" != "0" ]; do
#		cryptsetup -q -y -c aes-xts-plain64 -s 512 -h sha512 luksFormat "$LUKS_DEVICE"
#		EXIT="$?"
#	done
#
#	local SSD_DISCARD=""
#	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
#		SSD_DISCARD=" --allow-discards"
#	fi
#
#	doPrint "Opening LUKS device"
#	EXIT="1"
#	while [ "$EXIT" != "0" ]; do
#		cryptsetup$SSD_DISCARD luksOpen "$LUKS_DEVICE" "$LUKS_NAME"
#		EXIT="$?"
#	done
#}
#todo we don't need anymore
#doCreateLuksLvm() {
#	local LUKS_LVM_DEVICE="$LVM_DEVICE_PATH/$LUKS_NAME"
#
#	pvcreate "$LUKS_LVM_DEVICE"
#	vgcreate "$LUKS_LVM_NAME" "$LUKS_LVM_DEVICE"
#	lvcreate -l 100%FREE -n "$ROOT_LABEL" "$LUKS_LVM_NAME"
#}

doDetectDevicesLuksLvm() {
	LVM_ROOT_DEVICE="$LVM_DEVICE_PATH/$LVM_NAME-$ROOT_LABEL"
	LVM_HOME_DEVICE="$LVM_DEVICE_PATH/$LVM_NAME-$HOME_LABEL"
}




doCreateLvmLuks() {
#	local LUKS_LVM_DEVICE="$LVM_DEVICE_PATH/$LUKS_NAME"
	pvcreate "$LVM_DEVICE" # pvcreate /dev/sda2
	vgcreate "$LVM_NAME" "$LVM_DEVICE" # vgcreate lvm /dev/sda2

 	lvcreate -L "$ROOT_SIZE"GiB -n "$ROOT_LABEL" "$LVM_NAME"
 	lvcreate -l 100%FREE -n "$HOME_LABEL" "$LVM_NAME"
}

doCreateLuks2() {

	doPrint "Formatting LUKS-ROOT device"
	local EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup -q -y -c aes-xts-plain64 -s 512 -h sha512 luksFormat "$LVM_ROOT_DEVICE"
		EXIT="$?"
	done

	local SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" --allow-discards"
	fi

	doPrint "Opening LUKS device"
	EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup$SSD_DISCARD luksOpen "$LVM_ROOT_DEVICE" "$LUKS_ROOT_NAME"
		EXIT="$?"
	done


}
doFormat() {
  mkfs.ext4 -L "$LUKS_ROOT_NAME" "$LVM_DEVICE_PATH/$LUKS_ROOT_NAME"
  mkfs -t fat -F 32 -n "$BOOT_LABEL" "$BOOT_DEVICE"
}

doMount() {
	local SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" -o discard"
	fi

	mount$SSD_DISCARD "$LVM_DEVICE_PATH/$LUKS_ROOT_NAME" /mnt
	mkdir /mnt/boot
	mount$SSD_DISCARD "$BOOT_DEVICE" /mnt/boot

}

setupHome(){
  mkdir -pm 700 /mnt/etc/luks-keys
  dd if=/dev/random of=/mnt/etc/luks-keys/home bs=1 count=256 status=progress

 	while [ "$EXIT" != "0" ]; do
    cryptsetup luksFormat -v "$LVM_HOME_DEVICE" /mnt/etc/luks-keys/home
		EXIT="$?"
	done

	local SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" --allow-discards"
	fi

	doPrint "Opening LUKS device"
	EXIT="1"
	while [ "$EXIT" != "0" ]; do
		cryptsetup$SSD_DISCARD -d /mnt/etc/luks-keys/home open "$LVM_HOME_DEVICE" "$LUKS_HOME_NAME"
		EXIT="$?"
	done
	mkfs.ext4 -L "$LUKS_HOME_NAME" "$LVM_DEVICE_PATH/$LUKS_HOME_NAME"

	SSD_DISCARD=""
	if [ "$INSTALL_DEVICE_IS_SSD" == "yes" ] && [ "$INSTALL_DEVICE_SSD_DISCARD" == "yes" ]; then
		SSD_DISCARD=" -o discard"
	fi
	mount$SSD_DISCARD "$LVM_DEVICE_PATH/$LUKS_HOME_NAME" /mnt/home
}

doCheckInstallDevice
#doConfirmInstall


doDeactivateAllSwaps
doWipeAllPartitions
doWipeDevice
doCreateNewPartitionTable

# luks


doCreateNewPartitionsLvm
doDetectDevicesLvm
isDeviceSsd

doCreateLvmLuks
doDetectDevicesLuksLvm
#
doCreateLuks2
doFormat
doMount
setupHome
#
#
#doDetectDevicesLuksLvm
#
#echo $ROOT_DEVICE