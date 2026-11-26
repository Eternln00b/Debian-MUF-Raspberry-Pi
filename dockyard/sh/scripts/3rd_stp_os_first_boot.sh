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
