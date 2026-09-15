#!/bin/bash

raccess_items() {

	local projects_itmd=$1
	local uid=$2
	
	if [[ -n "${projects_itmd}" && -d "${projects_itmd}" ]];then
	
		[[ "$(stat -c "%U:%G" ${project_itmd})" == "root:root" ]] && chown -R ${uid}:${uid} ${projects_itmd}
				
		for r in $(find ${project_itmd} -maxdepth 1 -type f -name '*.tar.gz')
		do
		
			chown ${uid}:${uid} ${r}
		
		done
	
	fi
	
}
