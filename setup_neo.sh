#!/usr/bin/env bash

download_dir="/usr/share/kbd/keymaps/i386/neo"
mkdir -p ${download_dir}

#curl -Lo ${download_dir}/neo.map https://git.neo-layout.org/neo/neo-layout/raw/branch/master/linux/console/neo.map
wget -P ${download_dir} https://neo-layout.org/git/linux/console/neo.map

localectl --no-convert set-keymap neo
