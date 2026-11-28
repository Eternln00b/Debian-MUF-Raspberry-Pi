#!/bin/bash

set -e

f_eraser() {

	local f_td=$1
	shred -v -n 1 -z "${f_td}" >/dev/null 2>&1
	truncate -s 0 "${f_td}"
	rm "${f_td}"

}

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

# cleaning the img
echo -en "\nWe are cleaning the img...\n"
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

[[ -d /var/log/journal ]] && rm -rf /var/log/journal/*

if [[ "${img_light}" == "true" ]];then

	for i in $(find /var/lib/apt/lists -type f)
	do

		f_eraser "${i}"

	done

	rm -rf /var/lib/apt/lists/*

fi

for i in $(find /var/{tmp,log} /lost+found -type f)
do

	f_eraser "${i}"

done

for i in $(find /var/{lib,cache} -type f -name "*-old")
do

	f_eraser "${i}" 

done

# the SSH host keys made during the build are removed : each Raspberry Pi generates its own keys at the first boot
for i in $(find /etc/{dropbear,ssh} -type f \( -name "ssh_host_*" -o -name "dropbear_*_host_key" \) 2>/dev/null)
do

	f_eraser "${i}"

done

truncate -s 0 /etc/machine-id /usr/sbin/policy-rc.d /root/.bash_history
rm -rf /lost+found /usr/sbin/policy-rc.d /root/.bash_history /var/lib/dbus/machine-id

gpgconf --kill all >/dev/null 2>&1 || true