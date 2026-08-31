#!/bin/bash

rpi_selected() {

	local hw=$1
	local err_msg="Unknown hardware: ${hw}"
	arch=$2

	if [[ -z "${arch}" ]];then 

		case "${hw}" in
	
			"RPi5"|"500"|"500+"|"cm5"|"RPi4"|"400"|"cm4"|"cm4s"|"RPi3"|"RPi3+"|"cm3"|"cm3+"|"zero2w")
			arch="aarch64"
			;;
	
			"RPi4"|"400"|"cm4"|"cm4s"|"RPi3"|"RPi3+"|"cm3"|"cm3+"|"RPi2"|"zero2w"|"RPi1"|"cm1"|"zero"|"zerow")
			arch="armhf"
			;;
        
			*)
			echo -en "\n${err_msg}\n\n"
			exit 
			;;
		
		esac

	else

		case "${hw}" in
			
			"RPi2"|"RPi1"|"cm1"|"zero"|"zerow")
			if [[ "${arch}" != "armhf" ]]; then
                
				echo -en "\nThe model ${hw} only supports armhf architecture ! (requested: ${arch})\n\n"
				exit
			
			fi
			;;
        
			"RPi5"|"500"|"500+")
			if [[ "${arch}" != "aarch64" ]]; then
         
				echo -en "\nThe model ${hw} only supports aarch64 architecture ! (requested: ${arch})\n\n"
				exit
			
			fi
			;;
        
			"RPi4"|"400"|"cm4"|"cm4s"|"RPi3"|"RPi3+"|"cm3"|"cm3+"|"zero2w")
			if [[ "${arch}" != "aarch64" && "${arch}" != "armhf" ]]; then
        
				echo -en "\nThe model ${hw} only supports aarch64 or armhf ! (requested: ${arch})\n\n"
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
