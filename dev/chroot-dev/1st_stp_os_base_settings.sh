#!/bin/bash

set -e 

easy_append() {

	local txt=$1
	local filetp=$2
	echo "${txt}" | dd conv=notrunc oflag=append of=${filetp} >/dev/null 2>&1

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

echo -en "\nWe are in the chroot...\n\n"

source ${VARS_CHROOT}
export -p LANG="${LANG_CODE}.UTF-8" >/dev/null 2>&1  
export -p LANGUAGE="${LANG}" >/dev/null 2>&1  
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

devbootfs=$(blkid --label ${pboot} -o value)
devrootfs=$(blkid --label ${prootfs} -o value)
bootcmd="dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=PARTUUID=$(blkid -s PARTUUID -o value ${devrootfs}) rootfstype=ext4 fsck.repair=yes cgroup_enable=memory elevator=deadline rootwait"

os_sysfilest=('/boot/cmdline.txt' '/boot/config.txt' '/etc/apt/sources.list' '/etc/default/keyboard' '/etc/hostname' '/etc/hosts' '/etc/fstab' '/etc/systemd/journald.conf')
os_sysfilestxt=('/boot/cmdline.txt' '/etc/hostname' '/etc/timezone')
os_txt_append=("${bootcmd}" "${hostname}" "${timezone}")

for filep in "${os_sysfilest[@]}"
do

	[[ -f ${filep} ]] && truncate -s 0 ${filep} >/dev/null 2>&1
	
done

while read -r txt_apnd <&3 && read -r files_to_apnd <&4
do

	easy_append "${txt_apnd}" "${files_to_apnd}"

done 3< <(printf "%s\n" "${os_txt_append[@]}") 4< <(printf "%s\n" "${os_sysfilestxt[@]}")

sed -e "s|# ${LANG} UTF-8|${LANG} UTF-8|" -i /etc/locale.gen
locale-gen
update-locale LANGUAGE=${LANG_CODE} LANG=${LANG} LC_ALL=${LANG}

ln -sf /usr/share/zoneinfo/"${timezone}" /etc/localtime
dpkg-reconfigure --frontend=noninteractive tzdata >/dev/null 2>&1
echo -en "\nThe Timezone has been set...\n"

echo -en "\nadding the sudo user : ${user}\n"
useradd -s /bin/bash -G sudo,adm,netdev,www-data -m "${user}"
echo "${user}:${password}" | chpasswd
sed -e 's|#force_color_prompt=yes|force_color_prompt=yes|g' -i "${bashrc_usr}"

/bin/cat /dev/null > /boot/config.txt
/bin/cat <<bootconfigtxt >> /boot/config.txt
# For more options and information see
# http://rptl.io/configtxt
# Some settings may impact device functionality. See link above for details

kernel=/boot/${RPi_kernel}.img

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Enable audio (loads snd_bcm2835)
dtparam=audio=on

# Automatically load overlays for detected cameras
camera_auto_detect=1

# Automatically load overlays for detected DSI displays
display_auto_detect=1

# Enable DRM VC4 V3D driver
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Don't have the firmware create an initial video= setting in cmdline.txt.
# Use the kernel's default instead.
disable_fw_kms_setup=1

# Run in 64-bit mode
# arm_64bit=1

# Disable compensation for displays with overscan
disable_overscan=1

# Run as fast as firmware / board allows
arm_boost=1

bootconfigtxt

if [[ "${M_ARCH}" == "aarch64" ]];then

	sed -e 's|# arm_64bit=1|arm_64bit=1|' -i /boot/config.txt

else

	sed -e '29d;30d;31d' -i /boot/config.txt

fi

/bin/cat /dev/null > /etc/fstab
/bin/cat <<os_mnts >> /etc/fstab
proc            /proc           proc    defaults          0       0
PARTUUID=$(blkid -s PARTUUID -o value ${devbootfs})  /boot/firmware  vfat    defaults          0       2
PARTUUID=$(blkid -s PARTUUID -o value ${devrootfs})  /               ext4    defaults,noatime  0       1

os_mnts

/bin/cat /dev/null > /etc/apt/sources.list
/bin/cat <<etc_apt_sources_list >> /etc/apt/sources.list
# See https://wiki.debian.org/SourcesList for more information.
deb ${APT_URL} ${RELEASE} main non-free-firmware
deb-src ${APT_URL} ${RELEASE} main non-free-firmware

deb ${APT_URL} ${RELEASE}-updates main non-free-firmware
deb-src ${APT_URL} ${RELEASE}-updates main non-free-firmware

deb ${APT_URL_SEC} ${RELEASE}-security main non-free-firmware
deb-src ${APT_URL_SEC} ${RELEASE}-security main non-free-firmware

# Backports allow you to install newer versions of software made available for this release
deb ${APT_URL} ${RELEASE}-backports main non-free-firmware
deb-src ${APT_URL} ${RELEASE}-backports main non-free-firmware

etc_apt_sources_list

echo -en "\nWe are installing the /etc/apt/sources.list...\n" 		

apt update -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt clean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoclean -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt autoremove -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

tmpfsch=$(find /var/log -type f)
for i in $tmpfsch
do

	shred -v -n 1 -z "${i}" >/dev/null 2>&1
	truncate -s 0 "${i}" >/dev/null 2>&1

done

apt upgrade -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
