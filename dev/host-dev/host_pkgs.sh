#!/bin/bash

dev_pkgs() {

	local pkgs=("g++-arm-linux-gnueabi" "gcc-aarch64-linux-gnu" "g++-aarch64-linux-gnu" "gcc-arm-linux-gnueabihf" "bison" "bc" "g++-arm-linux-gnueabihf" "gcc-arm-linux-gnueabi"
	"flex" "qemu-utils" "kpartx" "qemu-user-static" "binfmt-support" "libncurses5-dev" "git" "libssl-dev" "device-tree-compiler" "squashfs-tools" "wpasupplicant" "wget"
	"parallel" "parted" "debootstrap" "debian-archive-keyring" "ubuntu-keyring")

	for check_pkg in "${pkgs[@]}"
	do

		if [[ ! $(apt-cache show "${check_pkg}" 2>&1 | awk '/Package:/') ]];then 
	 
    			echo -en "The package $check_pkg is being installed...\n"
    			apt install -y -qq -o=Dpkg::Use-Pty=0 $check_pkg >/dev/null 2>&1
    			
		fi

	done

}

clonedgit_repo() {

	local repo_dir=$1
	local url_repo_firmware=$2
	local url_repo_kernel=$3
	local firmware_branch=$4
	local kernel_branch=$5
	local kernel_arch=$6
	local u_id=$7
	local urls=("${url_repo_firmware}" "${url_repo_kernel}")
	local branchs=("${firmware_branch}" "${kernel_branch}")

	if [[ ${#urls[@]} -ne ${#branchs[@]} ]]; then
		
		echo -en "There's an issue with your urls repositories"
		exit
	
	else
	
		[[ ! -d ${repo_dir} ]] && mkdir -p ${repo_dir}		
			
		while read -r url <&3 && read -r branch <&4
		do
		
			local branch_list=$(git ls-remote --heads ${url} | sed -r 's/\S+//1;s|[[:space:]]refs/heads/||')
						
			if [[ $(curl -A "Mozilla/5.0" -Lfs "${url}" -o /dev/null; echo $?) -ne 0 ]];then 
			
				echo -en "The repository ${url} likely doesn't exist\n"
				exit
			
			elif [[ ! $(echo -en "$branch_list\n" | awk '/\y'${branch}'\y/') ]];then
			
				echo -en "the branch ${branch} of the repository ${url} likely doesn't exist\n"
				exit
			
			else
			
				if [[ "${url##*/}" == "linux" ]];then

					branch=$(echo -en "${branch_list}\n" | sort -Vu | grep -E '^rpi-[0-9]+\.[0-9]+\.y$' | tail -n1)
				
				fi
			
				local cloned_repo="${repo_dir}/${url##*/}-${branch}"
				
				if [[ ! -d ${cloned_repo} ]];then 
			
					local msg_notif="We are cloning the repository ${url}"
					
					if [[ ${branch} != "master" ]];then
					
						[[ "${kernel_arch}" == "aarch64" ]] && echo -en "We are better off to change the branch for this repo ${url}.\n"
						echo -en "${msg_notif}. The selected branch is ${branch}\n"
								
					else
					
						echo -en "${msg_notif}\n"
						
					fi
										
					git clone --depth 1 -q --branch "${branch}" --single-branch "${url}" --jobs=$(nproc) "${cloned_repo}"
				
				fi

			fi
		
		done 3< <(printf "%s\n" "${urls[@]}") 4< <(printf "%s\n" "${branchs[@]}")
		
		chown -R ${u_id}:${u_id} ${repo_dir%'/git'}
		echo
				
	fi
	
}
