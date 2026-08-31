#!/usr/bin/env python3

# Author : https://github.com/Eternln00b

import os
import csv
import sys
import argparse
from pathlib import Path

def csv_checking(cfg_lst,cl1,cl2,cl3,cl4,cl5,cl6,cl7,cl8):
    columns_chck = {cl1,cl2,cl3,cl4,cl5,cl6,cl7,cl8}
    try:
        with open(cfg_lst, 'r', newline='', encoding='utf-8') as f:
            cfg_chck = csv.DictReader(f)
            cfg_head = cfg_chck.fieldnames

            if cfg_head is None :
                return False, "The file template isn't right or it's empty"

            elif set(cfg_head).issuperset(columns_chck):
                return True, list(cfg_head)
            
            else:
                missing_clmns = columns_chck - set(cfg_head)
                return False, f"missing columns : {', '.join(sorted(missing_clmns))}"

    except FileNotFoundError:
        return False, f"The file '{cfg_lst}' looks missing"
    
    except Exception as etmpl:
        return False, f"There's an issue with the csv file : {etmpl}"

def csv_rows(cfg_lst):
    try:
        with open(cfg_lst, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            
            if header is None:
                return 0
            
            else:
                l = sum(1 for row in reader if any(field.strip() for field in row))
                return l
    
    except Exception as e:
        return -1

def build_env_tw(cfg_lst,rpi_m,rpi_arch,outf,
                 cl1,cl2,cl3,cl4,cl5,cl6,cl7,
                 cl8,shv1,shv2,shv3,shv4,f_tm):
    match rpi_arch:
        case 'armhf':
            match rpi_m:
                case 'RPi1'|'cm1'|'zero'|'zerow':
                    id_cfg = 1

                case 'RPi2'|'RPi3'|'RPi3+'|'cm3'|'cm3+'|'zero2w':
                    id_cfg = 2
                
                case 'RPi4'|'400'|'cm4'|'cm4s':
                    id_cfg = 3

                case _:
                    print(f"The Raspberry pi model {rpi_m} isn't supported with the architecture {rpi_arch}.\n")
                    sys.exit(1)
        
        case 'aarch64':
            match rpi_m:
                case 'RPi3'|'RPi3+'|'cm3'|'cm3+'|'zero2w'|'RPi4'|'400'|'cm4'|'cm4s':
                    id_cfg = 4

                case 'RPi5'|'500'|'500+'|'cm5':
                    id_cfg = 5

                case _:
                    print(f"The Raspberry pi model {rpi_m} isn't supported with the architecture {rpi_arch}.\n")
                    sys.exit(1)
        case _:
            print(f"The arch {rpi_arch} is not supported.\n")
            sys.exit(1)

    try:
        if os.path.exists(f"{outf}"):
            os.remove(f"{outf}")
        
        if os.path.exists(f"{shv4}"):
            os.remove(f"{shv4}")
        		
        with open(cfg_lst, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)

            for row in reader:
                if int(row[cl1]) == id_cfg:
                    sh_vars = [
                        f'{cl2}="{row.get(cl2, "").strip()}"',
                        f'{cl3}="{row.get(cl3, "").strip()}"',
                        f'{cl4}="{row.get(cl4, "").strip()}"',
                        f'{cl5}="{row.get(cl5, "").strip()}"',
                        f'{cl6}="{row.get(cl6, "").strip()}"',
                        f'{cl7}="{row.get(cl7, "").strip()}"',
                        f'{cl8}="{row.get(cl8, "").strip()}"',
                        f'chroot_scripts="{shv1}"',
                        f'chroot_usr="{shv2}"',
                        f'rootfs_targz="{shv3}"',
                        f'img_name="{shv4}"'
                    ]
                    sh_varsf= "\n".join(sh_vars)
                    chroot_path = row.get(cl8, "").strip()

                    with open(outf, 'w', encoding='utf-8') as out:
                        out.write(sh_varsf + "\n")
                    
                    with open(f_tm, 'r', encoding='utf-8') as file_m:
                        content = file_m.read()
                    
                    with open(outf, 'a', encoding='utf-8') as dest:
                        dest.write(content)
                        os.remove(f"{f_tm}")

            if not Path(outf).exists():
                print(f"Configuration ID {id_cfg} cannot be found in the {cfg_lst}")
                sys.exit(1)
            
    except FileNotFoundError:
        print(f"I can't file the file '{cfg_lst}'")
        sys.exit(1)
    except FileNotFoundError:
        print(f"I can't file the file '{f_tm}'")
        sys.exit(1)
    except Exception as e:
        print(f"There's an issue with the csv file: {e}")
        sys.exit(1)
        
def main():
    pargv = argparse.ArgumentParser()
    pargv.add_argument('-b', '--buildcfg', required=True,
                       help='csv list of the cross-compile configurations')
    
    pargv.add_argument('-r', '--raspberry', required=True,
                       help='raspberry pi model')
    
    pargv.add_argument('-a', '--architecture', required=True,
                       help='architecture to use')
    
    pargv.add_argument('-c', '--chrootsd', required=True,
                       help='where chroot scripts are stored')
    
    pargv.add_argument('-u', '--usrchroots', required=True,
                       help='user''s chroot config')
    
    pargv.add_argument('--targzrootfs', required=True,
                       help='tar.gz the root files system')
    
    pargv.add_argument('--imgfile', required=True,
                       help='Where the .img for the rpi is going to be written')

    pargv.add_argument('-t', '--tmpclonedrlf', required=True,
                       help='temporary list to merge of the cloned repos')
    
    pargv.add_argument('-s', '--shellvarsf', required=True,
                       help='where to store shell variables')

    csv_c1 = "ID"
    csv_c2 = "ARCH"
    csv_c3 = "KDEV_ARCH"
    csv_c4 = "DEFCONFIG"
    csv_c5 = "KERNEL_IMG"
    csv_c6 = "KERNEL"
    csv_c7 = "CC_COMPILER"
    csv_c8 = "chrootfs"
        
    argv = pargv.parse_args()
    file_ok, msg = csv_checking(argv.buildcfg,csv_c1,csv_c2,csv_c3,
                                csv_c4,csv_c5,csv_c6,csv_c7,csv_c8)
    cfgs = csv_rows(argv.buildcfg)

    if not file_ok:
        print(f"There's something wrong... : {msg}")
        sys.exit(1)

    else:
        if cfgs <= 0:
            match cfgs:
                case -1:
                   print(f"I can't see any environment in the file {argv.buildcfg}...")
            
                case 0:
                   print(f"There is no environment defined in the file {argv.buildcfg}...")
            
                case _:
                   print("Whatever... you can go futher for the moment.\n")
            sys.exit(1)
        
        else:
            build_env_tw(argv.buildcfg,argv.raspberry,argv.architecture,argv.shellvarsf,
                         csv_c1,csv_c2,csv_c3,csv_c4,csv_c5,csv_c6,csv_c7,csv_c8,argv.chrootsd,
                         argv.usrchroots,argv.targzrootfs,argv.imgfile,argv.tmpclonedrlf)
                       
if __name__ == "__main__":
    main()
