#!/bin/bash

# cleaning the img
echo -en "\nWe are cleaning the img...\n"
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

[[ -d /var/log/journal ]] && rm -rf /var/log/journal/*

tos=$(find /var/log /lost+found /tmp -type f)
for i in $tos
do

	rm "${i}" 

done

truncate -s 0 /etc/machine-id /var/lib/dbus/machine-id
rm -rf /lost+found /var/lib/dbus/machine-id
