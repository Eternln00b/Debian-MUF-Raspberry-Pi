#!/usr/bin/env python3

# Author : https://github.com/Eternln00b

import os
import csv
import sys
import argparse
import requests
from pathlib import Path
from urllib.parse import urlparse
from bs4 import BeautifulSoup

def csv_checking(dist_setup,cl1,cl2,cl3,cl4,cl5,cl6):
    columns_chck = {cl1,cl2,cl3,cl4,cl5,cl6}
    try:
        with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
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
        return False, f"The file '{dist_setup}' looks missing"
    
    except Exception as etmpl:
        return False, f"There's an issue with the csv file : {etmpl}"

def csv_rows(dist_setup):
    try:
        with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            
            if header is None:
                return 0
            
            else:
                l = sum(1 for row in reader if any(field.strip() for field in row))
                return l
    
    except Exception as e:
        return -1

def urls_checking(dist_setup,cl3,cl4,cl5,cl6):
    try:
        with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                dist_ID = row.get(cl3, '').strip()
                apt_url = row.get(cl4, '').strip()
                key_url = row.get(cl5, '').strip()
                secp_url = row.get(cl6, '').strip()
                
                if dist_ID and apt_url and key_url and secp_url :
                    ckey_url = key_url + "-" + dist_ID + ".asc"
                    urls_itm = [apt_url,ckey_url,secp_url]
                    
                    for u in urls_itm:
                        response = requests.get(u)
                        
                        if response.status_code != 200:
                            print(f"The url {u} looks unreachable ...")
                            sys.exit(1)
                
                else:
                    print("Can't check if the distribution setup is valid...")
                    sys.exit(1)
            
    except Exception as e:
        print(f"There was an issue with the urls to check... {e}")
        sys.exit(1)

def release_checking(dist_setup,cl4,cl2):
    try:
        with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                apt_url = row.get(cl4, '').strip()
                dist_rel = row.get(cl2, '').strip()
                
                if apt_url and dist_rel:
                    url_dist = apt_url + "/dists"
                    rel_lc = dist_rel.lower() + "/"
                    response = requests.get(url_dist)
                    
                    if response.status_code != 200:
                        print(f"The url {url_dist} looks unreachable ...")
                        sys.exit(1)
                    
                    else:
                        soup = BeautifulSoup(response.text, 'html.parser')
                        rel_iv = soup.find('a', href=f"{rel_lc}")
                        
                        if not rel_iv:
                            print(f"The release {rel_iv} is unkown")
                            sys.exit(1)

    except Exception as e:
        print(f"Can't check if the release {dist_rel} is valid... {e}")
        sys.exit(1)

def build_env_tw(cl1,cl2,cl3,cl4,cl5,cl6,dist_setup,outf):
    try:
        with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:

                distrib = row.get(cl1, '').strip()
                dist_ID = row.get(cl3, '').strip()
                key_url = row.get(cl5, '').strip()

                keyf = "/usr/share/keyrings/" + distrib + "-release-" + dist_ID + ".gpg"
                ckey_url = key_url + "-" + dist_ID + ".asc"

                if os.path.exists(f"{outf}"):
                    os.remove(f"{outf}")

                with open(dist_setup, 'r', newline='', encoding='utf-8') as f:
                    reader = csv.DictReader(f)  
                    sh_vars = [
                        f'{cl1}="{row.get(cl1, "").strip()}"',
                        f'{cl2}="{row.get(cl2, "").strip()}"',
                        f'{cl3}="{row.get(cl3, "").strip()}"',
                        f'{cl4}="{row.get(cl4, "").strip()}"',
                        f'{cl5}="{ckey_url}"',
                        f'{cl6}="{row.get(cl6, "").strip()}"',
                        f'KEY_FILE="{keyf}"'
                    ]
                    
                    sh_varsf= "\n".join(sh_vars)
                
                with open(outf, 'w', encoding='utf-8') as out:
                    out.write(sh_varsf + "\n")
            
    except FileNotFoundError:
        print(f"I can't file the file '{dist_setup}'")
        sys.exit(1)
    except Exception as e:
        print(f"There's an issue with the csv file: {e}")
        sys.exit(1)

def main():
    pargv = argparse.ArgumentParser()
    pargv.add_argument('--distrov', required=True,
                       help='distribution settings file')
    
    pargv.add_argument('-d', '--dsetup', required=True,
                       help='where to store shell variables related to the distribution')
    
    csv_1cls = "DIST"
    csv_2cls = "RELEASE"
    csv_3cls = "ID"
    csv_4cls = "APT_URL"
    csv_5cls = "ARCHIVE_KEY"
    csv_6cls = "APT_URL_SEC"

    argv = pargv.parse_args()
    file_ok, msg = csv_checking(argv.distrov,csv_1cls,csv_2cls,csv_3cls,csv_4cls,csv_5cls,csv_6cls)
    clone_repos = csv_rows(argv.distrov)

    if not file_ok:
        print(f"There's something wrong... : {msg}")
        sys.exit(1)

    else:
        if clone_repos <= 0:
            match clone_repos:
                case -1:
                   print("How many distro config ???")
            
                case 0:
                   print("There's no distro config...")
            
                case _:
                   print("Whut ?\n")
            sys.exit(1)
        
        else:
            urls_checking(argv.distrov,csv_3cls,csv_4cls,csv_5cls,csv_6cls)
            release_checking(argv.distrov,csv_4cls,csv_2cls)
            build_env_tw(csv_1cls,csv_2cls,csv_3cls,csv_4cls,
                         csv_5cls,csv_6cls,argv.distrov,argv.dsetup)         
            
if __name__ == "__main__":
    main()

