#!/bin/bash

# cleaning the img
echo -en "\nWe are cleaning the img...\n"
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

[[ -d /var/log/journal ]] && rm -rf /var/log/journal/*

tos=$(find /var/log /lost+found -type f)
for i in $tos
do

	shred -v -n 1 -z "${i}" >/dev/null 2>&1
	truncate -s 0 "${i}" >/dev/null 2>&1
	unlink "${i}"

done

rm -rf /lost+found
dmesg -C
