#!/bin/bash

apt_pkgs_chck() {

		local update_r=$1
        local apt_pkgs=('g++-arm-linux-gnueabi' 'gcc-aarch64-linux-gnu' 'g++-aarch64-linux-gnu' 'gcc-arm-linux-gnueabihf'
                        'bison' 'bc' 'g++-arm-linux-gnueabihf' 'qemu-utils' 'qemu-user-static' 'gcc-arm-linux-gnueabi'
                        'flex' 'binfmt-support' 'libssl-dev' 'device-tree-compiler' 'squashfs-tools' 'build-essential'
                        'parallel' 'parted' 'debootstrap' 'debian-archive-keyring' 'ubuntu-keyring' 'device-tree-compiler'
                        'kpartx')
        
        if [[ "${update_r}" = true ]];then
			
			echo -en "apt update requested !\n\n"      
            apt update -y -qq -o=Dpkg::Use-Pty=0 >/dev/null 2>&1
            
        fi

        for a in "${apt_pkgs[@]}"
        do
            if [[ -z $(apt list -qq --installed 2>&1 | grep -w "${a}") ]];then
                
                echo -en "The apt package ${a} is being installed...\n"
                apt install -y -qq -o=Dpkg::Use-Pty=0 ${a} >/dev/null 2>&1
                
            fi

        done

}

py_mod_chck() {

	local py_ml=('python3-git' 'python3-requests' 'python3-bs4')
	for pym in "${py_ml[@]}"
	do

		mn=${pym##*-}
		if [[ "${mn}" == "bs4" ]];then

			if [[ $(python3 -c "from bs4 import BeautifulSoup" 2> /dev/null ; echo $?) -ne 0 ]];then

				echo -en "The python3 module ${pym} is being installed...\n"
				apt install -y -qq -o=Dpkg::Use-Pty=0 $pym >/dev/null 2>&1

			fi

		else

			if [[ $(python3 -c "import ${mn}" 2> /dev/null ; echo $?) -ne 0 ]];then

 				echo -en "The python3 module ${pym} is being installed...\n"
				apt install -y -qq -o=Dpkg::Use-Pty=0 $pym >/dev/null 2>&1

			fi

		fi

	done

}
