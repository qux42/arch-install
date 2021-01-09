#!/usr/bin/env bash


mapfile -t wifi_devices < <(ls /sys/class/ieee80211/*/device/net/)


len=${#wifi_devices[@]}

if (( $len < 1 ))
then
  echo "no wifi devices found"
  exit
elif [ $len -eq 1 ]
then
  wifi_device=${wifi_devices[0]}
elif (( $len > 1))
then
  echo "select wifi device"
  select tmp_wifi_device in "${wifi_devices[@]}"
  do
    wifi_device=$tmp_wifi_device
    break
  done
fi


echo -e "Connecting with ${wifi_device}\n"
read -p "SSID: " ssid

read -s -p "Password: " password

iwctl --passphrase ${password} station ${wifi_device} connect ${ssid}

if [ $? -eq 0 ]
then
  echo "Connected to ${ssid}"
else
  echo "Error connecting to ${ssid}"
  ./setup-wifi.sh

fi