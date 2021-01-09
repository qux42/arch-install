#!/usr/bin/env bash

download_dir="/usr/share/kbd/keymaps/i386/neo"
mkdir -p ${download_dir}

wget -P ${download_dir} https://neo-layout.org/git/linux/console/neo.map
