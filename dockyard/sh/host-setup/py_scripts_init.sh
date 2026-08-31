#!/bin/bash

py_funct_init() {
	
	local py_scriptsd=$1
	local dest="/usr/local/sbin"
	
	for s in $(find ${py_scriptsd} -type f -name '*.py')
	do
	
		cp "${s}" "/tmp/${s##*/}"
		chmod +x "/tmp/${s##*/}"
		ln -s "/tmp/${s##*/}" "${dest}/${s##*/}"
	
	done

}

py_scripts_clr() {

	local syml_dir="/usr/local/sbin"

	for s in $(find -L "${syml_dir}" -xtype l -name '*.py')
	do
	
		unlink "${syml_dir}/${s##*/}"
	
	done
	
	for p in $(find /tmp -type f -name '*.py')
	do
	
		rm "${p}" 
	
	done
	
}
