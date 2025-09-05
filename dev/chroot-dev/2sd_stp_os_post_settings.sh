#!/bin/bash

set -e

M_ARCH=$(uname -m)
VARS_CHROOT=

if [[ "$(id -u)" -ne 0 || "${M_ARCH}" == "x86_64" && "$(stat -c %d:%i /)" == "$(stat -c %d:%i /proc/1/root/.)" ]]; then

	echo "you are not in the chroot !"
	exit

fi

if [[ ! -f ${VARS_CHROOT} ]];then

	echo -en "[!] The variables aren't set. We have to stop.\n"
	exit

fi

source ${VARS_CHROOT}
export -p LANG="${LANG_CODE}.UTF-8"
export -p LANGUAGE="${LANG}"
export -p LC_ADDRESS="${LANG_CODE}.UTF-8"
export -p LC_IDENTIFICATION="${LANG_CODE}.UTF-8"
export -p LC_MEASUREMENT="${LANG_CODE}.UTF-8"
export -p LC_MONETARY="${LANG_CODE}.UTF-8"
export -p LC_NAME="${LANG_CODE}.UTF-8"
export -p LC_PAPER="${LANG_CODE}.UTF-8"
export -p LC_TELEPHONE="${LANG_CODE}.UTF-8"
export -p LC_NUMERIC="${LANG_CODE}.UTF-8"
export -p LC_MESSAGES="${LANG_CODE}.UTF-8"
export -p LC_TIME="${LANG_CODE}.UTF-8"

# /etc/hosts
/bin/cat /dev/null > /etc/hosts
/bin/cat <<hosts >> /etc/hosts
::1 		localhost localhost.localdomain ${hostname}.localdomain
127.0.0.1 	localhost localhost.localdomain ${hostname}.localdomain
127.0.1.1	${hostname}

# The following lines are desirable for IPv6 capable hosts
::1			ip6-localhost ip6-loopback
fe00::0		ip6-localnet
ff00::0		ip6-mcastprefix
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

hosts

# /etc/interfaces 
/bin/cat /dev/null > /etc/network/interfaces
/bin/cat <<etc_network_interfaces >> /etc/network/interfaces
source-directory /etc/network/interfaces.d

etc_network_interfaces
chmod 0600 /etc/network/interfaces

# Don't wait forever and a day for the network to come online
if [ -s /lib/systemd/system/networking.service ]; then

	sed -i -e "s/TimeoutStartSec=5min/TimeoutStartSec=5sec/" /lib/systemd/system/networking.service

fi

if [ -s /lib/systemd/system/ifup@.service ]; then

	echo "TimeoutStopSec=5s" >> /lib/systemd/system/ifup@.service

fi

# cleaning the img

echo -en "\nWe are cleaning the img...\n"
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

[[ -d /var/log/journal ]] && rm -rf /var/log/journal/*

tos=$(find /var/log -type f)
for i in $tos
do

	shred -v -n 1 -z "${i}" >/dev/null 2>&1
	truncate -s 0 "${i}" >/dev/null 2>&1

done

dmesg -C
