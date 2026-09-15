#!/bin/bash

deb_pkg_listing() {

	local distro_ID=$1
	local deb_basef=$2
	local deb_projectf=$3
	
	if [[ -z ${distro_ID} ]];then
	
		echo -en "I need the Debian ID in order to continue...\n\n"
		return 1
	
	elif [[ -z ${deb_basef} || ! -f ${deb_basef} ]];then
	
		echo -en "I need the base packages list in order to continue...\n\n"
		return 1
		
	else
	
		local pkgs_lst=$(grep '^[^@#]' ${deb_basef} | sed -z 's/\n/,/g;s/.$//')
		
		if [[ -n ${deb_projectf} && -f ${deb_projectf} ]];then
		
			local pkgs_project=$(sed -z 's/\n/,/g;s/.$//' ${deb_projectf})
		
		fi
		
		if [[ ${distro_ID} -lt 12 ]];then
		
			fpkgs_list="${pkgs_lst},net-tools,dnsutils,crda,python"
		
		else

			local mdeb_kpkg="bind9-dnsutils,debian-keyring,debian-archive-keyring,iproute2"
			
			if [[ ${distro_ID} -gt 12 ]];then
			
				fpkgs_list="${mdeb_kpkg},python-is-python3,${pkgs_lst}"
			
			else
			
				fpkgs_list="${mdeb_kpkg},${pkgs_lst}"	
			
			fi
			
		fi
		
		if [[ -n ${pkgs_project} ]];then
		
			local afpkgs_lst="${pkgs_project},${fpkgs_list}"
			echo ${afpkgs_lst}
		
		else
		
			echo ${fpkgs_list}
		
		fi
		
	fi
	
}

distro_rootfs() {

	local apt_url=$1
	local rel=$2
	local keyr=$3
	local distro=$4
	local distro_id=$5
	local arch=$6
	local os_inst_pkgs=$7
	local targz_fpath=$8
	local tmp_rootfs="/tmp/rootfs_deb"
	local tmp_img="/tmp/rootfs.img"
			
	if [[ ! -f ${targz_fpath} ]];then
		
		echo -en "We have to write and compress the root file system ${targz_fpath##*/}\n"
		echo -en "It's going to take a while...\n\n"
		
		if [[ ${distro_id} -ge 12 ]];then
		
			qemu-img create -f raw "${tmp_img}" 750M > /dev/null
		
		else
		
			qemu-img create -f raw "${tmp_img}" 700M > /dev/null
		
		fi
		
		(echo "n"; echo "p"; echo "1"; echo ""; echo ""; echo "w") | fdisk "${tmp_img}" > /dev/null
		[[ ! -d ${tmp_rootfs} ]] && mkdir -p "${tmp_rootfs}"
		[[ ${arch} == "arm" ]] && arch="armhf"
		local LOOPDEVS=$(kpartx -avs "${tmp_img}" | awk '{print $3}')
		local LOOPROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $1}')
		mkfs.ext4 ${LOOPROOTFS} >/dev/null 2>&1
		mount ${LOOPROOTFS} ${tmp_rootfs}
		debootstrap --keyring="${keyr}" --include=ca-certificates --include="${os_inst_pkgs}" --arch="${arch}" "${rel}" "${tmp_rootfs}" "${apt_url}/" >/dev/null 2>&1
		local exit_code_deb=$?
		
		if [[ ${exit_code_deb} -ne 0 ]]; then
		
			echo -en "${distro} ${rel} seems not supported for the ${arch} architecture...\n"
			echo -en "You have to change the release and the distro id variables...\n\n"
			
		
		else
		
			tar --xform s:'^./':: --exclude="lost+found" --exclude="debootstrap" -zcf "${targz_fpath}" -C "${tmp_rootfs}" .
			chown -R ${u_id}:${u_id} "${targz_fpath}"
					
		fi
		
		umount -l "${tmp_rootfs}" || true
		kpartx -dvs "${tmp_img}" >/dev/null 2>&1
		rm -rf "${tmp_rootfs}" "${tmp_img}"
		[[ ${exit_code_deb} -ne 0 ]] && exit
				
	fi
			
}

os_pre_build() {

	local boot_size=$1
	local img_size=$2
	local mnt_rootfs=$3
	local img_name=$4
	local targz_rootfs=$5
	local mnt_bootfs=${mnt_rootfs}/boot
	local mnt_dirs=("proc" "dev" "dev/pts" "sys" "tmp")

	[[ ! -d ${mnt_rootfs} ]] && mkdir -p ${mnt_rootfs}
	echo -en "We are going to build the Debian OS !\n"

	qemu-img create -f raw ${img_name} ${img_size} > /dev/null 
	(echo "n"; echo "p"; echo "1"; echo "2048"; echo "+${boot_size}"; echo "n"; echo "p"; echo "2"; echo ""; echo ""; 
 	 echo "t"; echo "1"; echo "c"; echo "w") | fdisk ${img_name} > /dev/null
	
	local LOOPDEVS=$(kpartx -avs ${img_name} | awk '{print $3}')
	local LOOPDEVBOOT=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $1}')
	local LOOPDEVROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $2}')
	
	mkfs.vfat ${LOOPDEVBOOT} >/dev/null 2>&1
	mkfs.ext4 ${LOOPDEVROOTFS} >/dev/null 2>&1

	fatlabel ${LOOPDEVBOOT} Boot >/dev/null 2>&1
	e2label ${LOOPDEVROOTFS} Debian >/dev/null 2>&1

	mount ${LOOPDEVROOTFS} ${mnt_rootfs}
	tar -C ${mnt_rootfs} -xf ${targz_rootfs}
	mount ${LOOPDEVBOOT} ${mnt_bootfs}
		
	for os_dir in "${mnt_dirs[@]}"
	do

		if [[ ${os_dir} == "proc" ]];then
		
			mount -t proc /${os_dir} ${mnt_rootfs}/${os_dir}

		elif [[ ${os_dir} == "sys" ]];then
		
			mount -t sysfs /${os_dir} ${mnt_rootfs}/${os_dir}

		else
		
			mount -o bind /${os_dir} ${mnt_rootfs}/${os_dir}

		fi

	done
	
}

os_build() {

	local rpi_arch=$1
	local mnt_rootfs=$2
	local firmware_dir=$3
	local dev_scripts=$4
	local dev_vars=$5
	local firmware_precomp="${firmware_dir}/boot"
	local mnt_bootfs=${mnt_rootfs}/boot
	local mnt_chck=$(awk '/\57dev\57mapper\57loop[0-99]/' /proc/mounts | wc -l)
		
	if [[ ${mnt_chck} -ne 2 ]];then
	
		echo -en "The loop device isn't mounted...\n"
		return 1
		
	elif [[ ! -d "${firmware_precomp}" ]];then
	
		echo -en "The firmware folder is missing...\n" 
		return 1
	
	else
			
		[[ -f ${firmware_precomp}/COPYING.linux ]] && cp ${firmware_precomp}/COPYING.linux ${mnt_bootfs}
		[[ -f ${firmware_precomp}/LICENCE.broadcom ]] && cp ${firmware_precomp}/LICENCE.broadcom ${mnt_bootfs}
		
		if [[ ! -f ${firmware_precomp}/bootcode.bin ]];then
		
			echo -en "The bootcode ${firmware_precomp}/bootcode.bin is missing...\n"
			return 1
		
		else
		
			cp ${firmware_precomp}/bootcode.bin ${mnt_bootfs}
			for precomp in $(find ${firmware_precomp}/{*.dat,*.elf} -type f)
			do
		
				cp ${precomp} ${mnt_bootfs}
			
			done
		
		fi
		
		echo -en "pboot=Boot\n" | dd conv=notrunc oflag=append of=${dev_vars} >/dev/null 2>&1
		echo -en "prootfs=Debian\n" | dd conv=notrunc oflag=append of=${dev_vars} >/dev/null 2>&1
		[[ ${rpi_arch} == "armhf" ]] && rpi_arch="arm"
		cp $(which qemu-${rpi_arch}-static) ${mnt_rootfs}/usr/bin/
		
		for chrt_script in $(find "${dev_scripts}" -maxdepth 1 -name "*.sh" | sort -V)
		do
	
			chroot "${mnt_rootfs}" "${chrt_script}"
			exit_code=$?
		
			if [[ ${exit_code} -ne 0 ]]; then
		
				echo -en "There's an issue with the chroot script ${chrt_script}...\n"
				return 1
        
			fi
	
		done
		
		rm -rf "${dev_scripts}" "${dev_vars}"
		
		if [[ ${exit_code} -eq 0 ]]; then

			truncate -s 0 ${mnt_rootfs}/usr/bin/qemu-${rpi_arch}-static >/dev/null 2>&1
			unlink ${mnt_rootfs}/usr/bin/qemu-${rpi_arch}-static
		
		fi
		
	fi	
	
}

