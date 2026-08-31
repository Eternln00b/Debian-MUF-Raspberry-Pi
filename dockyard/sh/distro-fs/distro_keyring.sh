#!/bin/bash

distro_import_key() {

	local distribution=$1
	local keyf=$2
	local archv_k=$3

	if [[ -z "${distribution}" || -z "${keyf}" || -z "${archv_k}" ]];then

		echo -en "You have to set the distribution name, the keyringfile and the security provider url !\n"
		return 1

	else

		if [[ ! -f "${keyf}" && "${distribution}" == "debian" ]];then

                        curl -fsSL ${archv_k} | gpg --import --no-default-keyring --keyring "${keyf}" >/dev/null 2>&1
			keyf_d=$?

			if [[ ${keyf_d} -ne 0 ]];then

				echo -en "I can't download the archive key for the moment...\n"
				return 1

			fi

		fi

	fi

}

