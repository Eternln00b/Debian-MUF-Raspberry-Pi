#!/bin/bash

final_debian_img() {

    local img_name_c="${img_name}.xz"
        
    for d_img in $(find "${BUILD_AREA}" -maxdepth 1 -type f -regex ".*/\(.*\.img\|.*\.xz\)$")
    do

        rm ${d_img}

    done

    chown ${usr_id}:${usr_id} ${img_name}
    chmod 644 ${img_name}
    
    if [[ ${img_comp} = true ]];then
    
        echo -en "The file ${img_name} is gonna be compressed !\n\n"
        xz -T $(nproc) -k -e --best ${img_name} 
        local tcomp=$?
        
        if [[ ${tcomp} -ne 0 ]];then
            
            echo -en "It's going to take sometimes...\n\n"
            xz -k --best ${img_name} 
		
        fi
        
        rm ${img_name}
        mv ${img_name_c} ${BUILD_AREA}   
    
    else
    
        mv ${img_name} ${BUILD_AREA}
            
    fi
    
}
