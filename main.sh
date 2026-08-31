#!/bin/bash

############################################
## Author : https://github.com/Eternln00b ##
############################################

export BUILD_AREA=$(dirname $(readlink -f "$0"))
WORKS="${BUILD_AREA}/dockyard"
ITEMS="${BUILD_AREA}/stock"
called_by="${SUDO_USER:-$(whoami)}"
project_itmd="${BUILD_AREA}/.project-items"
repos_dir="${project_itmd}/git"
csv_fd="${ITEMS}/csv"

source $WORKS/sh/distro-fs/rootfs.sh
source $WORKS/sh/distro-fs/distro_keyring.sh
source $WORKS/sh/host-setup/debian_img.sh
source $WORKS/sh/host-setup/py_scripts_init.sh
source $WORKS/sh/host-setup/rpi_selection.sh
source $WORKS/sh/host-tools/host_pkgs.sh
source $WORKS/sh/host-tools/kernel_comp.sh
source $WORKS/sh/host-tools/chroot_scripts_init.sh
source $ITEMS/distro/tmp_items

usage() {

    local rpiml="(RPi5|500|500+|cm5|RPi4|400|cm4|cm4s|RPi3|RPi3+|cm3|cm3+|zero2w|RPi2|RPi1|cm1|zero|zerow)"
    
    echo -en "\n[-R] Raspberry pi models : ${rpiml}\n\n"
    echo -en "[-c] item(s) to remove : all -> Deletes the root file system image and the repos.\n"
    echo -en "                         rootfs -> Deletes only the root file system image.\n"
    echo -en "                         repos -> Deletes the directory where the repository are cloned.\n\n"
    echo -en "[-a] cpu architecture : armhf -> 32-bit architecture\n"
    echo -en "                        aarch64 -> 64-bit architecture\n\n"
    echo -en "[-k] this switch allows the kernel configuration.\n\n"
    echo -en "[-x] this switch compress the image file.\n\n"
    echo -en "usage: $(basename "$0") -R <RPi model> [del][-c (all|rootfs|repos)] [opt][-a (cpu) -k -x]\n"
    echo
    exit

}

usage_clear_m() {
	
    echo "You are not supposed to use the switch '-c' as sudo."
    exit

}


finish() {
	
    sync
    local usr_id=$(id -u ${called_by})
    local mnt_dirs=("proc" "dev" "sys" "tmp")
        
    for os_dir in "${mnt_dirs[@]}"
    do
        
        umount -l "${chrootfs}/${os_dir}" || true
        
    done
    
    umount -l "${chrootfs}" || true
    kpartx -dvs ${img_name} >/dev/null 2>&1
    rm -rf "${chrootfs}"
    py_scripts_clr
    [[ "$(stat -c "%U:%G" ${project_itmd})" == "root:root" ]] && chown -R ${usr_id}:${usr_id} ${project_itmd}	
        
    if [[ ${os_build_exec} -ne 0 || ${kernel_install_exec} -ne 0 ]];then 
        
        rm ${img_name}
    
    else
        
        final_debian_img
    
    fi
    
}

declare rpi_model
declare arch
declare Kernel_Ver 
declare Kernel_cfg

while getopts ":R:a:c:kx" opt; do
    case ${opt} in
        R)
            rpi_model="$OPTARG"
            ;;
            
        a)
            arch="$OPTARG"
            ;;
        
        c)
            to_rm="$OPTARG"
            ;;
            
        k)
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

if [[ $(id -u) -ne 0 ]]; then

    if [[ -n "${to_rm}" && -d "${project_itmd}" ]];then
     
        case "${to_rm}" in
               
            "all")
                
                rm -rf "${project_itmd}"
                ;;
            
            "rootfs")
            
                for del in $(find "${project_itmd}" -maxdepth 1 -type f -name '*.tar.gz')
                do
                
                    rm "${del}"
                    
                done
                ;;
            
            "repos")

               rm -rf "${repos_dir}"
               ;;
            
            *)
               
               rm -rf "${project_itmd}"
               ;;
        
        esac
    
    else
        
        echo '[!] You can only build an image as sudo.'    
        exit
        
    fi
         
elif [[ ! -x $(command -v curl) || $(curl -Lfs guthib.com -o /dev/null; echo $?) -ne 0 ]];then
    
    echo '[!] curl is not installed or your are not connected to internet.'
    exit
    
elif [[ ! -x $(command -v lsb_release) || ! $(lsb_release -i | grep -E '(Debian|Ubuntu)') ]];then
    
    echo '[!] This script was written only for Debian or Ubuntu.'
    exit
        
elif [[ ! -x $(command -v dpkg-query) || ! -x $(command -v apt) ]];then
    
    echo '[!] There is an issue with your packages manager.'
    exit
    
elif [[ -z "${rpi_model}" ]];then
    
    if [[ -n "${to_rm}" ]];then

        usage_clear_m
            
    else
        
        usage
    
    fi

else
    
    [[ -n "${to_rm}" ]] && usage_clear_m
    [[ -z ${Kernel_cfg} ]] && Kernel_cfg=false
    
    apt_pkgs_chck
    py_mod_chck

    py_funct_init "${WORKS}/py"
    
    rpi_selected "${rpi_model}" "${arch}"
    
    distro_validation.py --distrov "${csv_fd}/distro_ver.csv" --dsetup "${dist_setup}"
    source "${dist_setup}"
    
    repos_harvest.py --repolst "${csv_fd}/repos_lst.csv" --clonedrdir "${repos_dir}" --listdrf "${tmp_lst_cr}"
    works_layout.py --buildcfg "${csv_fd}/construction_cfg.csv" --raspberry "${rpi_model}" --architecture "${arch}" --chrootsd "${WORKS}/sh/scripts" \
                    --usrchroots "${ITEMS}/distro/usr_settings" --targzrootfs "${project_itmd}/${DIST}-${ID}_${arch}.tar.gz" \
                    --imgfile "/tmp/${DIST}-${RELEASE}-${rpi_model}-${arch}.img" --tmpclonedrlf "${tmp_lst_cr}" --shellvarsf "${works_lfh}"
    
    sed -e 's|[\x2B]|_Plus|g' -i "${works_lfh}"
    source "${works_lfh}"
    
    works_chroot_layout.py --usrchroots "${chroot_usr}" --shellvarsf "${works_lfc}" --apturl "${APT_URL}" --urlsec "${APT_URL_SEC}" \
                           --release "${RELEASE}" --kerneln "${KERNEL}"

    chroot_scripts_cfg "${chroot_scripts}" "${chroot_sdir}" "${works_lfc}"
    chroot_cfg_check=$?
    [[ ${chroot_cfg_check} -ne 0 ]] && exit
    
    distro_import_key "${DIST}" "${KEY_FILE}" "${ARCHIVE_KEY}"
    keyring_check=$?
    [[ ${keyring_check} -ne 0 ]] && exit
        
    trap finish EXIT	
		
    kernel_comp "${linux_crep}" "${KDEV_ARCH}" "${KERNEL_IMG}" "${CC_COMPILER}" "${DEFCONFIG}" "${Kernel_cfg}"
    distro_rootfs "${APT_URL}" "${RELEASE}" "${KEY_FILE}" "${DIST}" "${ID}" "${KDEV_ARCH}" "${rootfs_targz}"
    
    os_pre_build '70M' '970M' "${chrootfs}" "${img_name}" "${rootfs_targz}"
    
    os_build "${arch}" "${chrootfs}" "${firmware_crep}" "${chroot_sdir}" "${works_lfc}"
    os_build_exec=$?
    
    if [[ ${os_build_exec} -eq 0 ]];then
        
        kernel_install "${linux_crep}" "${KDEV_ARCH}" "${KERNEL}" "${KERNEL_IMG}" "${CC_COMPILER}" "${DEFCONFIG}" "${chrootfs}"
        kernel_install_exec=$?
        
    else
        
        echo -en "We can't build the image... \n"
    
    fi

fi 
