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

echo -en "\nWe are in the chroot...\n"

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

echo -en "/etc/apt/sources.list init...\n\n" 		
apt -y update -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1     	

sed -e "s|# ${LANG} UTF-8|${LANG} UTF-8|" -i /etc/locale.gen
locale-gen
update-locale LANGUAGE=${LANG_CODE} LANG=${LANG} LC_ALL=${LANG}

/bin/cat /dev/null > /etc/default/keyboard
/bin/cat <<keyboarconf >> /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="${keyb_variant}"
XKBLAYOUT="${keyb_layout}"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"

keyboarconf
dpkg-reconfigure --frontend noninteractive keyboard-configuration

echo -en "\nTimezone reconfiguration...\n"
[[ -f /etc/timezone ]] && rm /etc/timezone
echo "${timezone}" | dd conv=notrunc oflag=append of=/etc/timezone >/dev/null 2>&1
[[ -f /etc/localtime ]] && rm /etc/localtime 
ln -sf /usr/share/zoneinfo/"${timezone}" /etc/localtime

dpkg-reconfigure --frontend=noninteractive tzdata >/dev/null 2>&1

# OS update
echo -en "We are updating the OS...\n"
apt -y install --no-install-recommends -qq -o=Dpkg::Use-Pty=0 "bash-completion" >/dev/null 2>&1
apt -y update -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
apt -y upgrade -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1

# User settings 
echo -en "adding the sudo user : ${user}\n"
useradd -s /bin/bash -G sudo,adm,netdev,www-data -m "${user}"
echo "${user}:${password}" | chpasswd
sed -e 's/#force_color_prompt=yes/force_color_prompt=yes/g' -i "${bashrc_usr}"

/bin/cat /dev/null > /boot/cmdline.txt
/bin/cat <<bootcmdtxt >> /boot/cmdline.txt
dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=PARTUUID=$(blkid -s PARTUUID -o value ${devrootfs}) rootfstype=ext4 fsck.repair=yes cgroup_enable=memory elevator=deadline rootwait

bootcmdtxt

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

mkdir -p /etc/network
rm -rf /etc/{hostname,hosts} /lost+found

# /etc/hostname
echo "${hostname}" | dd conv=notrunc oflag=append of=/etc/hostname >/dev/null 2>&1
