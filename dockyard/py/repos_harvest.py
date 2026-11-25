#!/usr/bin/env python3

# Author : https://github.com/Eternln00b

import os
import re
import csv
import sys
import argparse
import requests
from git import Repo, Git, GitCommandError
from pathlib import Path
from functools import lru_cache
from urllib.parse import urlparse

def csv_checking(repos_list,csv_1f,csv_2f):
    columns_chck = {csv_1f,csv_2f}
    try:
        with open(repos_list, 'r', newline='', encoding='utf-8') as f:
            repo_chck = csv.DictReader(f)
            repo_head = repo_chck.fieldnames

            if repo_head is None :
                return False, "The file template isn't right or it's empty"

            elif set(repo_head).issuperset(columns_chck):
                return True, list(repo_head)
            
            else:
                missing_clmns = columns_chck - set(repo_head)
                return False, f"missing columns : {', '.join(sorted(missing_clmns))}"

    except FileNotFoundError:
        return False, f"The file '{repos_list}' looks missing"
    
    except Exception as etmpl:
        return False, f"There was an issue with the csv file : {etmpl}"

def csv_rows(repos_list):
    try:
        with open(repos_list, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            
            if header is None:
                return 0
            
            else:
                l = sum(1 for row in reader if any(field.strip() for field in row))
                return l
    
    except Exception as e:
        return -1

def repo_name(url):
    urlpath = Path(urlparse(url).path)
    repn = urlpath.name

    if repn.endswith(".git"):
        repn = repn[:-4]

    return repn

def rpi_kernel_released(kernel_head,min_sublevel=1):
    makefile_url = f"https://raw.githubusercontent.com/raspberrypi/linux/{kernel_head}/Makefile"

    try:
        response = requests.get(makefile_url, timeout=30)

    except requests.RequestException:
        return False

    if response.status_code != 200:
        return False

    makefile_vars = {}

    for line in response.text.splitlines()[:10]:
        mk_var = re.fullmatch(r"(SUBLEVEL|EXTRAVERSION)\s*=\s*(.*)", line.strip())

        if mk_var:
            makefile_vars[mk_var.group(1)] = mk_var.group(2).strip()

    sublevel = makefile_vars.get("SUBLEVEL", "0")
    extraversion = makefile_vars.get("EXTRAVERSION", "")

    return extraversion == "" and sublevel.isdigit() and int(sublevel) >= min_sublevel

# result kept in memory : the branch is looked up only once
@lru_cache(maxsize=None)
def rpi_kernel_ref(url,branch):
    rpi_kernel_repo = "github.com/raspberrypi/linux"
    urltp = urlparse(url)
    repo_path = (urltp.netloc + urltp.path).lower().rstrip("/")

    if repo_path.endswith(".git"):
        repo_path = repo_path[:-4]

    if branch not in ("default", "latest", "recent"):
        return branch

    elif repo_path != rpi_kernel_repo:
        print(f"The keyword '{branch}' can only be used with https://{rpi_kernel_repo}...")
        sys.exit(1)

    os.environ["GIT_TERMINAL_PROMPT"] = "0"
    git_cmd = Git()
    kernel_ref = None

    try:
        if branch == "default":
            remote_head = git_cmd.ls_remote("--symref", url, "HEAD", kill_after_timeout=60)

            for line in remote_head.splitlines():
                if line.startswith("ref: refs/heads/"):
                    kernel_ref = line.split()[1].replace("refs/heads/", "")
                    break

        else:
            remote_heads = git_cmd.ls_remote("--heads", url, "rpi-*", kill_after_timeout=60)
            kernel_vers = {}

            for line in remote_heads.splitlines():
                head = line.split()[1].replace("refs/heads/", "")
                head_ver = re.fullmatch(r"rpi-(\d+)\.(\d+)\.y", head)

                if head_ver:
                    kernel_vers[head] = (int(head_ver.group(1)), int(head_ver.group(2)))

            kernel_heads = sorted(kernel_vers, key=kernel_vers.get, reverse=True)

            if branch == "latest" and kernel_heads:
                kernel_ref = kernel_heads[0]

            elif branch == "recent":
                for head in kernel_heads:
                    if rpi_kernel_released(head):
                        kernel_ref = head
                        break

    except GitCommandError:
        print(f"I can't reach the repo '{url}' to find the '{branch}' kernel branch...")
        sys.exit(1)

    if kernel_ref is None:
        print(f"I can't find the '{branch}' kernel branch in the repo '{url}'...")
        sys.exit(1)

    print(f"The '{branch}' kernel branch is '{kernel_ref}'")
    return kernel_ref

def repo_chck(repos_list,csv_1f,csv_2f):
    os.environ["GIT_TERMINAL_PROMPT"] = "0"
    git_cmd = Git()

    try:
        with open(repos_list, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                branch = row.get(csv_1f, '').strip()
                url = row.get(csv_2f, '').strip()

                if url and branch:
                    branch = rpi_kernel_ref(url, branch)

                    try:
                        remote_refs = git_cmd.ls_remote(url, f"refs/heads/{branch}", f"refs/tags/{branch}",
                                                        kill_after_timeout=60)

                    except GitCommandError:
                        print(f"the repo '{url}' isn't reachable or doesn't exist...")
                        sys.exit(1)

                    if not remote_refs.strip():
                        print(f"the branch or the tag '{branch}' doesn't exist in the repo '{url}'...")
                        sys.exit(1)

    except Exception as e:
        print(f"There was an issue with the repos to check... {e}")
        sys.exit(1)
    
def cloning_repo(repos_list,dest,outf,csv_1f,csv_2f,csv_3f):                                 
    try:
        with open(repos_list, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            with open(outf, 'w', encoding='utf-8') as out:
                for row in reader:
                    branch = row.get(csv_1f, '').strip()
                    url = row.get(csv_2f, '').strip()
                    sparse = (row.get(csv_3f) or '').strip()
                    
                    if branch and url :
                        branch = rpi_kernel_ref(url, branch)

                        repn = repo_name(url)
                        dir_name = repn + "-" + branch
                        dest_path = os.path.join(dest, dir_name)
                        sh_vn = repn + "_" + "crep" + "=" + "'" + dest_path + "'" + "\n"
                        with open(outf, 'a', encoding='utf-8') as out:
                            out.write(sh_vn)
                            
                            if not os.path.isdir(dest_path):
                                os.makedirs(dest_path, exist_ok=True)
                                print(f"I'm cloning the repo {url}. The selected branch is '{branch}'")
                                nproc = os.cpu_count()
                                
                                if sparse:
                                    print(f"Only these items will be checked out : {sparse}")
                                    sparse_repo = Repo.clone_from(url, dest_path, depth=1, branch=branch, single_branch=True,
                                                                  filter="blob:none", no_checkout=True)
                                    sparse_repo.git.sparse_checkout("init", "--no-cone")
                                    sparse_repo.git.sparse_checkout("set", *sparse.split())
                                    sparse_repo.git.checkout(branch)
                                
                                else:
                                    Repo.clone_from(url, dest_path, depth=1, branch=branch, single_branch=True, jobs=nproc)
                                                
    except Exception as e:
        print(f"Can't clone the repos for the moment... {e}")
        sys.exit(1)
        
def main():
    pargv = argparse.ArgumentParser()
    pargv.add_argument('-r', '--repolst', required=True,
                       help='csv repos list to clone')

    pargv.add_argument('-c', '--clonedrdir', required=True,
                       help='where to clone the repos')
    
    pargv.add_argument('-l', '--listdrf', required=True,
                       help='where to store shell variables related to the cloned repos')
    
    csv_1cls = "branch"
    csv_2cls = "url"
    csv_3cls = "sparse"

    argv = pargv.parse_args()
    file_ok, msg = csv_checking(argv.repolst,csv_1cls,csv_2cls)
    clone_repos = csv_rows(argv.repolst)

    if not file_ok:
        print(f"There's something wrong... : {msg}")
        sys.exit(1)

    else:
        if clone_repos <= 0:
            match clone_repos:
                case -1:
                   print("How many repos ???")
            
                case 0:
                   print("There's no repo to clone...")
            
                case _:
                   print("Whut ?\n")
            sys.exit(1)
        
        else:
            repo_chck(argv.repolst,csv_1cls,csv_2cls)
            cloning_repo(argv.repolst,argv.clonedrdir,
                         argv.listdrf,csv_1cls,csv_2cls,csv_3cls)            
            
if __name__ == "__main__":
    main()
