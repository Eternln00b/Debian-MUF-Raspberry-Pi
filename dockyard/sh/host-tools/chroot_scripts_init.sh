#!/bin/bash

chroot_scripts_cfg() {

    local dir_scripts=$1
    local scriptw_mv=$2
    local var_shellf=$3
               
    if [[ $(find "${dir_scripts}" -maxdepth 1 -name "*.sh" | wc -l) -eq 0 || ! -d "${dir_scripts}" || -z "${dir_scripts}" ]];then
         
        echo -en "[!] The scripts in the directory ${dir_scripts} are maybe missing...\n"
        return 1
		
    elif [[ ! -f "${var_shellf}" || -z "${var_shellf}" ]];then
        
        echo -en "[!] The file ${var_shellf} is maybe missing...\n"
        return 1
        
    else
        
        [[ ! -d "${scriptw_mv}" ]] && mkdir -p "${scriptw_mv}"
        for scrpt in $(find "${dir_scripts}" -maxdepth 1 -name "*.sh")
        do
            
            cp -p "${scrpt}" "${scriptw_mv}"/"${scrpt##*/}"
            sed -e "s|VARS_CHROOT=|VARS_CHROOT=${var_shellf}|" -i "${scriptw_mv}"/"${scrpt##*/}"
            chmod +x "${scriptw_mv}"/"${scrpt##*/}"
            
        done
    
    fi

}
