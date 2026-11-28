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

# LANG ( usr_settings ) is the language of the messages, LANG_CODE is the locale
usr_lang="${LANG}"
lang_short="${LANG_CODE%%_*}"

if [[ -z "${usr_lang}" ]];then

	usr_lang="${lang_short}"

elif [[ "${usr_lang%%[_:.]*}" != "${lang_short}" ]];then

	echo -en "[!] LANG='${usr_lang}' doesn't match LANG_CODE='${LANG_CODE}'.\n"
	echo -en "    The messages will be in '${usr_lang}' and the formats ( dates, currency... ) in '${LANG_CODE}'.\n\n"

fi

export -p LANG="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LANGUAGE="${usr_lang}" >/dev/null 2>&1
export -p LC_ADDRESS="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_IDENTIFICATION="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_MEASUREMENT="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_MONETARY="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_NAME="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_PAPER="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_TELEPHONE="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_NUMERIC="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_MESSAGES="${LANG_CODE}.UTF-8" >/dev/null 2>&1
export -p LC_TIME="${LANG_CODE}.UTF-8" >/dev/null 2>&1

expand_script="/usr/local/sbin/expand_rootfs.sh"
expand_service="/etc/systemd/system/expand_rootfs.service"

echo -en "\nThe root file system will be expanded at the first boot...\n"

# the delimiter is quoted : the variables are written as they are, they will be read on the Raspberry Pi
/bin/cat /dev/null > ${expand_script}
/bin/cat <<'expand_rootfs' >> ${expand_script}
#!/bin/bash

# if a step fails, the script stops and the service stays enabled : it will try again at the next boot
set -e

root_mnt=${1:-/}
root_part=$(lsblk -lnpo NAME,MOUNTPOINT | awk -v mnt="${root_mnt}" '$2 == mnt {print $1}')

if [[ -z "${root_part}" ]];then

	echo -en "I can't find the partition mounted on ${root_mnt}...\n"
	exit 1

fi

root_disk="/dev/$(lsblk -no PKNAME "${root_part}")"
part_num=$(cat /sys/class/block/${root_part##*/}/partition 2>/dev/null)

if [[ "${root_disk}" == "/dev/" || -z "${part_num}" ]];then

	echo -en "I can't find the disk of the partition ${root_part}...\n"
	exit 1

fi

echo -en "Expanding the partition ${root_part} to the end of ${root_disk}...\n"

# the partition table is changed, then the kernel is informed of the new size, then the file system is expanded
echo ", +" | sfdisk --no-reread --force -N "${part_num}" "${root_disk}" >/dev/null
partx -u -n "${part_num}" "${root_disk}"
resize2fs "${root_part}"

echo -en "The root file system has been expanded !\n"

# the job is done : the service and this script are removed
systemctl disable expand_rootfs.service
rm -f /etc/systemd/system/expand_rootfs.service /usr/local/sbin/expand_rootfs.sh
systemctl daemon-reload
expand_rootfs

chmod +x ${expand_script}

/bin/cat /dev/null > ${expand_service}
/bin/cat <<expand_unit >> ${expand_service}
[Unit]
Description=Expand the root file system to the whole SD card
After=systemd-remount-fs.service

[Service]
Type=oneshot
ExecStart=${expand_script}

[Install]
WantedBy=multi-user.target
expand_unit

systemctl enable expand_rootfs.service >/dev/null 2>&1
sshkeys_script="/usr/local/sbin/ssh_host_keys.sh"
sshkeys_service="/etc/systemd/system/ssh_host_keys.service"

echo -en "\nThe SSH host keys will be generated at the first boot...\n"

# the delimiter is quoted : the variables are written as they are, they will be read on the Raspberry Pi
/bin/cat /dev/null > ${sshkeys_script}
/bin/cat <<'ssh_host_keys' >> ${sshkeys_script}
#!/bin/bash

# if a step fails, the script stops and the service stays enabled : it will try again at the next boot
set -e

# OpenSSH ( full image ) : the missing host keys are created
if [[ -x /usr/sbin/sshd ]];then

	echo -en "Generating the OpenSSH host keys...\n"
	ssh-keygen -A

fi

# dropbear ( light image ) : one host key per type
if [[ -n "$(command -v dropbearkey)" ]];then

	mkdir -p /etc/dropbear

	for key_type in ed25519 ecdsa rsa
	do

		key_file="/etc/dropbear/dropbear_${key_type}_host_key"

		if [[ ! -f "${key_file}" ]];then

			echo -en "Generating the dropbear ${key_type} host key...\n"
			dropbearkey -t "${key_type}" -f "${key_file}" >/dev/null

		fi

	done

fi

echo -en "The SSH host keys have been generated !\n"

# the job is done : the service and this script are removed
systemctl disable ssh_host_keys.service
rm -f /etc/systemd/system/ssh_host_keys.service /usr/local/sbin/ssh_host_keys.sh
systemctl daemon-reload
ssh_host_keys

chmod +x ${sshkeys_script}

/bin/cat /dev/null > ${sshkeys_service}
/bin/cat <<sshkeys_unit >> ${sshkeys_service}
[Unit]
Description=Generate the SSH host keys of this Raspberry Pi
After=systemd-remount-fs.service
Before=ssh.service ssh.socket dropbear.service

[Service]
Type=oneshot
ExecStart=${sshkeys_script}

[Install]
WantedBy=multi-user.target
sshkeys_unit

systemctl enable ssh_host_keys.service >/dev/null 2>&1
