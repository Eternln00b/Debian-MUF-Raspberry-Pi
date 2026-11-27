#!/bin/bash

# cleaning the img
echo -en "\nWe are cleaning the img...\n"
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

[[ -d /var/log/journal ]] && rm -rf /var/log/journal/*

if [[ "${img_light}" == "true" ]];then

	for i in $(find /var/lib/apt/lists -type f)
	do

		truncate -s 0 "${i}"
		rm "${i}"		

	done

	rm -rf /var/lib/apt/lists/*

fi

for i in $(find /var/log /lost+found /var/tmp -type f)
do

	truncate -s 0 "${i}"
	rm "${i}" 

done

for i in $(find /var/{lib,cache} -type f -name "*-old")
do

	truncate -s 0 "${i}"
	rm "${i}" 

done

truncate -s 0 /etc/machine-id /usr/sbin/policy-rc.d /root/.bash_history
rm -rf /lost+found /usr/sbin/policy-rc.d /root/.bash_history /var/lib/dbus/machine-id

gpgconf --kill all >/dev/null 2>&1 || true