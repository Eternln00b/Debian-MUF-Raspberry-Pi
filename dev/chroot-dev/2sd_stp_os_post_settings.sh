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
if [[ -s /lib/systemd/system/networking.service ]]; then

	sed -e 's/TimeoutStartSec=5min/TimeoutStartSec=5sec/' -i /lib/systemd/system/networking.service

fi

if [[ -s /lib/systemd/system/ifup@.service ]]; then

	sed -e '$aTimeoutStopSec=5s' -i /lib/systemd/system/ifup@.service

fi

# /etc/journald.conf 
/bin/cat /dev/null > /etc/systemd/journald.conf
/bin/cat <<journald_conf >> /etc/systemd/journald.conf
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it under the
#  terms of the GNU Lesser General Public License as published by the Free
#  Software Foundation; either version 2.1 of the License, or (at your option)
#  any later version.
#
# Entries in this file show the compile time defaults. Local configuration
# should be created by either modifying this file, or by creating "drop-ins" in
# the journald.conf.d/ subdirectory. The latter is generally recommended.
# Defaults can be restored by simply deleting this file and all drop-ins.
#
# Use 'systemd-analyze cat-config systemd/journald.conf' to display the full config.
#
# See journald.conf(5) for details.

[Journal]
Storage=volatile
Compress=yes
#Seal=yes
#SplitMode=uid
#SyncIntervalSec=5m
#RateLimitIntervalSec=30s
#RateLimitBurst=10000
#SystemMaxUse=
#SystemKeepFree=
#SystemMaxFileSize=
#SystemMaxFiles=100
#RuntimeMaxUse=
#RuntimeKeepFree=
#RuntimeMaxFileSize=
#RuntimeMaxFiles=100
#MaxRetentionSec=
#MaxFileSec=1month
#ForwardToSyslog=yes
#ForwardToKMsg=no
#ForwardToConsole=no
#ForwardToWall=yes
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
#MaxLevelKMsg=notice
#MaxLevelConsole=info
#MaxLevelWall=emerg
#LineMax=48K
#ReadKMsg=yes
#Audit=no

journald_conf

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
