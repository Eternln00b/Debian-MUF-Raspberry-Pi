#!/bin/bash

kernel_comp() {

	local kernel_src_dir=$1
	local K_ARCH=$2
	local K_IMG=$3
	local CC_COMP=$4
	local DEF_CFG=$5
	local K_CFG=$6
	local dtb_srch_dir="${kernel_src_dir}/arch/${K_ARCH}/boot/dts/broadcom"
	local K_IMG_PATH="${kernel_src_dir}/arch/${K_ARCH}/boot/${K_IMG}"
	local PROC=$(nproc)
			
	if [[ ${DEF_CFG} == "bcmrpi_defconfig" ]];then
	
		local dtb_srch={bcm2708,bcm2835}
	
	else
	
		local dtb_srch=${DEF_CFG%"_defconfig"}
	
	fi
			
	dtb_comp=$(find ${dtb_srch_dir}/${dtb_srch}*.dtb -type f 2>/dev/null | wc -l)
		
	if [[ ! -f "${K_IMG_PATH}" && "${dtb_comp}" -eq 0 ]];then
		
		echo -en "We are going to Build the kernel. It's going to take a while...\n\n"
		cd "${kernel_src_dir}"
		
		make ARCH="${K_ARCH}" CROSS_COMPILE="${CC_COMP}" "${DEF_CFG}" -j"${PROC}" &> /dev/null
		local exit_code_defcg=$?
		
		if [[ ${exit_code_defcg} -ne 0 ]]; then
		
			echo -en "The kernel configuration ${DEF_CFG} has been not found...\n"
			echo -en "You are maybe better off to change the branch...\n\n"
			exit
		
		else
		
			[[ "${K_CFG}" = true ]] && make ARCH="${K_ARCH}" CROSS_COMPILE="${CC_COMP}" -j"${PROC}" menuconfig
			make ARCH="${K_ARCH}" CROSS_COMPILE="${CC_COMP}" "${K_IMG}" modules dtbs -j"${PROC}"
			echo -en "\n"
		
		fi
		
	fi
		
}

kernel_install() {

	local kernel_src_dir=$1
	local K_ARCH=$2
	local K_BOOT=$3
	local K_IMG=$4
	local CC_COMP=$5
	local DEF_CFG=$6
	local ROOT_PART=$7
	local BOOT_PART=${ROOT_PART}/boot
	local dtb_srch_dir="${kernel_src_dir}/arch/${K_ARCH}/boot/dts/broadcom"
	local K_IMG_PATH="${kernel_src_dir}/arch/${K_ARCH}/boot/${K_IMG}"
	local PROC=$(nproc)
	
	if [[ ${DEF_CFG} == "bcmrpi_defconfig" ]];then
	
		local dtb_srch={bcm2708,bcm2835}
	
	else
	
		local dtb_srch=${DEF_CFG%"_defconfig"}
	
	fi
	
	dtb_comp=$(find ${dtb_srch_dir}/${dtb_srch}*.dtb -type f 2>/dev/null | wc -l)
	
	if [[ -f "${K_IMG_PATH}" && "${dtb_comp}" -gt 0 ]];then
	
		cp "${K_IMG_PATH}" ${BOOT_PART}/${K_BOOT}.img
						
		cd "${kernel_src_dir}"
		make ARCH="${K_ARCH}" CROSS_COMPILE="${CC_COMP}" INSTALL_MOD_PATH="${ROOT_PART}" modules_install -j "${PROC}" &> /dev/null
		make ARCH="${K_ARCH}" CROSS_COMPILE="${CC_COMP}" INSTALL_DTBS_PATH="${BOOT_PART}" dtbs_install -j "${PROC}" &> /dev/null
		
		# I don't know, I'm bored with this....
		if [[ "${K_ARCH}" == "arm64" ]];then 
		
			for dtb_comp in $(find "${BOOT_PART}/broadcom" -maxdepth 1 -name "*.dtb")
			do
			
				mv ${dtb_comp} ${BOOT_PART}
			
			done
			
			rm -rf "${BOOT_PART}/broadcom"
		
		fi
		
		echo -en "\nKernel has been installed !\n\n"
	
	else
	
		echo -en "The kernel looks gone.. ?\n"
		return 1
	
	fi
	
}
