#!/bin/bash

img_fit() {

    local img_file=$1
    local rootfs_margin=${2:-32}
    local mnt_old="/mnt/img_fit_old"
    local mnt_new="/mnt/img_fit_new"
    local rootfs_new="${img_file}.rootfs"
    
    sync
    local LOOPDEVS=$(kpartx -avs ${img_file} | awk '{print $3}')
    local LOOPDEVROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $2}')
    local rootfs_label=$(e2label ${LOOPDEVROOTFS} 2>/dev/null)
    
    mkdir -p ${mnt_old} ${mnt_new}
    mount -o ro ${LOOPDEVROOTFS} ${mnt_old}
    
    # space really taken by the files + the journal ( 16 MiB ) + the margin ( MiB ) + 2% for the inodes tables
    local rootfs_bytes=$(du -sx --block-size=1 ${mnt_old} | cut -f1)
    local rootfs_mib=$(( ( (rootfs_bytes + (16 + rootfs_margin) * 1048576) * 100 / 98 + 1048575 ) / 1048576 ))
    
    echo -en "\nThe root file system takes $(( rootfs_bytes / 1048576 ))M, its partition will be ${rootfs_mib}M...\n"
    
    # a new file system with the right size, the files are copied in it
    # the journal ( -J ) and the inodes ( -i, one per 16 KiB ) are fixed, so the size above stays right
    rm -f ${rootfs_new}
    truncate -s ${rootfs_mib}M ${rootfs_new}
    mkfs.ext4 -q -J size=16 -i 16384 -L "${rootfs_label}" ${rootfs_new} >/dev/null 2>&1
    mount -o loop ${rootfs_new} ${mnt_new}
    cp -a ${mnt_old}/. ${mnt_new}/
    local copy_chck=$?
    
    umount ${mnt_new}
    umount ${mnt_old}
    kpartx -dvs ${img_file} >/dev/null 2>&1
    rmdir ${mnt_old} ${mnt_new}
    
    if [[ ${copy_chck} -ne 0 ]];then
    
        echo -en "[!] The copy of the root file system failed, the image keeps its size...\n"
        rm -f ${rootfs_new}
        return 1
    
    fi
    
    # the image is cut where the partition 2 starts, the new file system is written there and the partition 2 is resized
    local part_start=$(partx -g -o START -n 2 ${img_file} | tr -d ' ')
    truncate -s $(( part_start * 512 )) ${img_file}
    truncate -s $(( part_start * 512 + rootfs_mib * 1048576 )) ${img_file}
    dd if=${rootfs_new} of=${img_file} bs=4M seek=$(( part_start * 512 )) oflag=seek_bytes conv=notrunc,sparse status=none
    echo ",$(( rootfs_mib * 2048 ))" | sfdisk --no-reread -N 2 ${img_file} >/dev/null 2>&1
    rm -f ${rootfs_new}
    
    echo -en "The image is now $(( $(stat -c %s ${img_file}) / 1048576 ))M.\n"
    
}

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
