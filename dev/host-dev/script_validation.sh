#!/bin/bash

pre_cfg_chroot() {

	local apt_url=$1
	local sec_url=$2
	local dist_rel=$3
	local rpi_kernel=$4
	local chroot_env=$5
	local dir_cscripts=$6
	local devdir_scripts="/tmp/dev-scripts"
	local dev_vars="/tmp/dev-scripts/src_vars"
	local dist_arr=("APT_URL=${apt_url}" "APT_URL_SEC=${sec_url}" "RELEASE=${dist_rel}" "RPi_kernel=${rpi_kernel}")
		
	if [[ $(find "${dir_cscripts}" -maxdepth 1 -name "*.sh" | wc -l) -eq 0 || ! -d "${dir_cscripts}" || ! -f "${chroot_env}" ]];then
	
		echo -en "[!] There's an issue with your chroot configuration...\n"
		exit
	
	else
	
		[[ ! -d "${devdir_scripts}" ]] && mkdir -p "${devdir_scripts}"
		[[ ! -d "${dev_vars}" ]] && touch "${dev_vars}"
	
		for value_chck in "${values_arr[@]}"
		do
		
			if [[ -z "${value_chck}" ]];then
				
				echo -en "[!] a mandatory variable has been not set...\n" 
				exit
				
			fi
		
		done
	
		while read var_chroot
		do
	
			echo -en "$var_chroot\n" | dd conv=notrunc oflag=append of=${dev_vars} >/dev/null 2>&1
		
		done < "${chroot_env}"
		
		for var_param in ${dist_arr[@]}
		do 

			echo -en "$var_param\n" | dd conv=notrunc oflag=append of=${dev_vars} >/dev/null 2>&1

		done

		sed -e '/^[[:space:]]*$/d' -i "${dev_vars}"

		for dev_script in $(find "${dir_cscripts}" -maxdepth 1 -name "*.sh")
		do
		
			cp -p "${dev_script}" "${devdir_scripts}"/"${dev_script##*/}"
			sed -e "s|VARS_CHROOT=|VARS_CHROOT=${dev_vars}|" -i "${devdir_scripts}"/"${dev_script##*/}"
		
		done
		
	fi

}
