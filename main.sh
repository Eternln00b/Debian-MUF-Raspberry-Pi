#!/bin/bash

############################################
## Author : https://github.com/Eternln00b ##
############################################

export DEV_ENV=$(dirname $(readlink -f "$0"))
DEV_FNCS="${DEV_ENV}/dev"
DEV_VARS="${DEV_ENV}/vars"

source $DEV_FNCS/host-dev/host_pkgs.sh
source $DEV_FNCS/host-dev/rasp_hw_validation.sh
source $DEV_FNCS/host-dev/kernel_comp.sh
source $DEV_FNCS/host-dev/script_validation.sh
source $DEV_FNCS/distro-fs/rootfs.sh
source $DEV_VARS/distribution/release
source $DEV_VARS/repositories/git-repos

usage() {

    echo
    echo -en "usage: $(basename "$0") -R <Raspberry pi Hardware (RPi5|RPi4|RPi3|RPi2|RPi1)> [opt][-a <arch (aarch64|armhf)> -c <enable kernel conf> -x <enable img compression>]\n"
    echo
    exit

}

finish () {
	
	sync
	local mnt_dirs=("proc" "dev" "sys" "tmp")
	
	for os_dir in "${mnt_dirs[@]}"
	do

		umount -l "${chrootfs}/${os_dir}" || true
	
	done
		
	umount -l "${chrootfs}" || true
	kpartx -dvs ${img_name} >/dev/null 2>&1
	rm -rf "${chrootfs}" "/tmp/dev-scripts"
		
	if [[ ${img_comp} = true ]];then

		echo -en "The file ${img_name} is gonna be compressed !\n\n"
		xz -k --best ${img_name}

	fi

}

declare rpi_model
declare arch
declare Kernel_Ver 
declare Kernel_cfg

while getopts ":R:a:k:cx" opt; do
    case ${opt} in
        R)
            rpi_model="$OPTARG"
            ;;
            
        a)
            arch="$OPTARG"
            ;;

        k)
            Kernel_Ver="$OPTARG"
            ;;
            
        c)
            Kernel_cfg=true
            ;;
            
        x)
            img_comp=true
            ;;
       
        \?)
            echo "unrecognized switch: -$OPTARG" 1>&2
            usage
            ;;
        :)
            echo "The switch -$OPTARG needs an argument." 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

if [[ $(id -u) -ne 0 || ! -x $(command -v curl) || $(curl -A 'Mozilla/5.0' -Lfs https://www.google.com -o /dev/null; echo $?) -ne 0 ]]; then

	echo '[!] This script is meant to be run as root with curl.'
	exit 
	
elif [[ ! -x $(command -v lsb_release) || ! $(lsb_release -i | grep -E '(Debian|Ubuntu)') ]];then

	echo '[!] This script was written only for Debian or Ubuntu.'
	exit

elif [[ ! -x $(command -v dpkg-query) || ! -x $(command -v apt) ]];then

	echo '[!] There is an issue with your packages manager.'
	exit

elif [[ -z "${rpi_model}" ]];then

	usage

else

	called_by="${SUDO_USER:-$(whoami)}"
	usr_id=$(id -u ${called_by})

	rpihw_valid "${rpi_model}" 
	rpidev_vars "${rpi_model}" "${arch}"

	chrootfs="/mnt/alt-raspbian"
	dev_code="${DEV_ENV}/os-items/git"
	img_name="${DEV_ENV}/${DIST}-${RELEASE}-${RASP}-${arch}.img"
	rootfs_targz="${dev_code%'/git'}/${DIST}-${ID}_${KDEV_ARCH}.tar.gz"
		
	chroot_scripts="${DEV_FNCS}/chroot-dev"
	chroot_usr="${DEV_VARS}/distribution/usr_settings"
	
	[[ -z ${Kernel_cfg} ]] && Kernel_cfg=false
	[[ -z ${img_comp} ]] && img_comp=false
	[[ -f ${img_name} ]] && rm -rf ${img_name}
	[[ ! -d ${chrootfs} ]] && mkdir -p ${chrootfs}
	
	dev_pkgs
	clonedgit_repo "${dev_code}" "${kernel_rep}" "${firmw_rep}" "${kernel_branch}" "${firmw_branch}" "${arch}" "${usr_id}"
	
	kernel_crep=$(find ${dev_code} -maxdepth 1 -type d -name "linux-*")	
	firmw_crep=$(find ${dev_code} -maxdepth 1 -type d -name "firmware-*")
	
	kernel_comp "${kernel_crep}" "${KDEV_ARCH}" "${KERNEL_IMG}" "${CC_COMPILER}" "${DEFCONFIG}" "${Kernel_cfg}"
	
	distro_keyring "${APT_URL}" "${APT_URL_SEC}" "${ARCHIVE_KEY}" "${RELEASE}" "${KEY_FILE}"
	distro_rootfs "${APT_URL}" "${RELEASE}" "${KEY_FILE}" "${DIST}" "${ID}" "${KDEV_ARCH}" "${rootfs_targz}" "${usr_id}"
	pre_cfg_chroot "${APT_URL}" "${APT_URL_SEC}" "${RELEASE}" "${KERNEL}" "${chroot_usr}" "${chroot_scripts}"
		
	trap finish EXIT
	
	os_pre_build '80M' '1200M' "${chrootfs}" "${img_name}" "${rootfs_targz}" 
	os_build "${arch}" "${chrootfs}" "${img_name}" "${firmw_crep}"
	kernel_install "${kernel_crep}" "${KDEV_ARCH}" "${KERNEL}" "${KERNEL_IMG}" "${CC_COMPILER}" "${DEFCONFIG}" "${chrootfs}"

fi 
