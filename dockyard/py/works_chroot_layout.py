#!/usr/bin/env python3

# Author : https://github.com/Eternln00b

import os
import sys
import argparse
from pathlib import Path

def build_env_tw(chroot_cfg,outf,apt_url,secp_url,rel,kernel_name):
    try:
        if os.path.exists(f"{outf}"):
            os.remove(f"{outf}")
        
        with open(chroot_cfg, 'r', encoding='utf-8') as cfg_r:
            content = cfg_r.read()
        
        with open(outf, 'w', encoding='utf-8') as dest:
            dest.write(content)

        sh_vars = [
            f'APT_URL="{apt_url}"',
            f'APT_URL_SEC="{secp_url}"',
            f'RELEASE="{rel}"',
            f'RPi_kernel="{kernel_name}"'
        ]
        
        sh_varsf= "\n".join(sh_vars)
        
        with open(outf, 'a', encoding='utf-8') as out:
            out.write(sh_varsf + "\n")
        
    except FileNotFoundError:
        print(f"I can't file the file '{chroot_cfg}'")
        sys.exit(1)
    except Exception as e:
        print(f"Can't define the chroot variables: {e}")
        sys.exit(1)

def main():
    pargv = argparse.ArgumentParser()
    pargv.add_argument('-u', '--usrchroots', required=True,
                       help='user settings for the chroot env')
    pargv.add_argument('-s', '--shellvarsf', required=True,
                       help='Where to store the chroot variables')
    pargv.add_argument('--apturl', required=True,
                       help='The apt repo url to use')
    pargv.add_argument('--urlsec', required=True,
                       help='The security provider url to use')
    pargv.add_argument('--release', required=True,
                       help='The distribution release name to use')
    pargv.add_argument('--kerneln', required=True,
                       help='The kernel name to use')
    
    argv = pargv.parse_args()
    build_env_tw(argv.usrchroots,argv.shellvarsf,argv.apturl,
                 argv.urlsec,argv.release,argv.kerneln)

if __name__ == "__main__":
    main()
