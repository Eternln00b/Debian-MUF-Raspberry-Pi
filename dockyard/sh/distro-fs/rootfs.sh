#!/bin/bash

distro_rootfs() {

	local apt_url=$1
	local rel=$2
	local keyr=$3
	local distro=$4
	local distro_id=$5
	local arch=$6
	local targz_fpath=$7
	local u_id=$8
	local tmp_rootfs="/tmp/rootfs_deb"
	local tmp_img="/tmp/rootfs.img"
	local console_env='console-data,console-setup-linux,console-setup,locales,tzdata'
	local dist_env='bash-completion,lsb-base,lsb-release,keyboard-configuration,nano,util-linux'
	local os_env='ifupdown,iw,kmod,sudo,udev,usbutils,perl,psmisc,rsync,dbus,fake-hwclock'
	local net_pa_env='iproute2,iputils-ping,tcpd,wget,openssh-server'
	local net_pb_env='ca-certificates,dhcpcd5,isc-dhcp-client,isc-dhcp-common'
	local netlib_env='libnl-3-200,libnl-genl-3-200,libnl-route-3-200,libssl-dev'
		
	if [[ ! -f ${targz_fpath} ]];then
		
		echo -en "We have to write and compress the root file system ${targz_fpath##*/}\n"
		echo -en "It's going to take a while...\n\n"
		
		if [[ ${distro_id} -ge 12 ]];then 
		
			local id_pkgs="bind9-dnsutils,python-is-python3"
		
		elif [[ ${distro_id} -lt 8 ]];then 
		
			local id_pkgs="dnsutils,crda,net-tools,python"
				
		else
		
			local id_pkgs="dnsutils,crda,python"
		
		fi
				
		local pkgs="${console_env},${dist_env},${os_env},${net_pa_env},${net_pb_env},${netlib_env},${id_pkgs}"

		qemu-img create -f raw "${tmp_img}" 700M > /dev/null
		(echo "n"; echo "p"; echo "1"; echo ""; echo ""; echo "w") | fdisk "${tmp_img}" > /dev/null
		[[ ! -d ${tmp_rootfs} ]] && mkdir -p "${tmp_rootfs}"
		[[ ${arch} == "arm" ]] && arch="armhf"
		local LOOPDEVS=$(kpartx -avs "${tmp_img}" | awk '{print $3}')
		local LOOPROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $1}')
		mkfs.ext4 ${LOOPROOTFS} >/dev/null 2>&1
		mount ${LOOPROOTFS} ${tmp_rootfs}
		debootstrap --keyring="${keyr}" --include=ca-certificates --include="${pkgs}" --arch="${arch}" "${rel}" "${tmp_rootfs}" "${apt_url}/" >/dev/null 2>&1
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

