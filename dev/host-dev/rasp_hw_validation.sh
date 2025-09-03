#!/bin/bash

rpihw_valid() {

	local hw=$1
	local err_msg="Unknown hardware: ${hw}"

	if [[ -z "${arch}" ]];then 

		case "${hw}" in
	
			"RPi5"|"RPi4"|"RPi3")
			arch="aarch64"
			;;
	
			"RPi2"|"RPi1")
			arch="armhf"
			;;
        
			*)
			echo -en "\n${err_msg}\n\n"
			exit 
			;;
		
		esac

	else

		case "${hw}" in
			
			"RPi1")
			if [[ "${arch}" != "armhf" ]]; then
                
				echo -en "\n${hw} only supports armhf architecture ! (requested: ${arch})\n\n"
				exit
			
			fi
			;;
        
			"RPi5")
			if [[ "${arch}" != "aarch64" ]]; then
         
				echo -en "\n${hw} only supports aarch64 architecture ! (requested: ${arch})\n\n"
				exit
			
			fi
			;;
        
			"RPi4"|"RPi3"|"RPi2")
			if [[ "${arch}" != "aarch64" && "${arch}" != "armhf" ]]; then
        
				echo -en "\n${hw} only supports aarch64 or armhf ! (requested: ${arch})\n\n"
				exit
				
			fi
			;;
        
			*)
			echo -en "\n${err_msg}\n\n"
			exit
			;;
			
		esac
	
	fi

}

rpidev_vars() {

	local rpihw=$1
	local rpi_arch=$2
	
	RASP=${rpihw}
	
	if [[ "${rpi_arch}" == "aarch64" ]];then
	
		KDEV_ARCH="arm64"
		KERNEL_IMG="Image"
		CC_COMPILER=aarch64-linux-gnu-
			
		if [[ ${rpihw} == "RPi5" ]];then
	
			KERNEL="kernel_2712"
			DEFCONFIG="bcm2712_defconfig"
			
		else
		
			KERNEL="kernel8"
			DEFCONFIG="bcm2711_defconfig"
		
		fi
				
	elif [[ "${rpi_arch}" == "armhf" ]];then
	
		KDEV_ARCH="arm"
		KERNEL_IMG="zImage"
		CC_COMPILER=arm-linux-gnueabihf-
		
		if [[ ${rpihw} == "RPi4" ]];then 
	
			KERNEL="kernel7l"
			DEFCONFIG="bcm2711_defconfig"
	
		elif [[ ${rpihw} == "RPi3" || ${rpihw} == "RPi2" ]];then
		
			KERNEL="kernel7"
			DEFCONFIG="bcm2709_defconfig"
		
	
		else
	
			KERNEL="kernel"
			DEFCONFIG="bcmrpi_defconfig"
	
		fi
			
	else
	
		echo -en "There's maybe an issue with your configuration...\n"
		exit
	
	fi

}
