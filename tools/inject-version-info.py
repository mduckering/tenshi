#!/usr/bin/env python

from __future__ import print_function
import os
import subprocess
import sys

def get_git_hash():
    head_hash = subprocess.check_output(['git', 'rev-parse', 'HEAD']).strip()
    if isinstance(head_hash, bytes):
        head_hash = head_hash.decode()
    rev = ""
    for i in range(0, 20):
        rev += "0x" + head_hash[i*2:i*2+2] + ", "
    return rev

def get_version_info():
    with open(os.path.dirname(sys.argv[0]) + "/../version.txt", "r") as f:
        ver = f.read().strip().split('.')
    if len(ver) != 4:
        raise Exception("Malformed version.txt")

    ver_ints = [0, 0, 0, 0]
    # Normal handling for major, minor, patch
    ver_ints[0] = int(ver[0])
    ver_ints[1] = int(ver[1])
    ver_ints[3] = int(ver[3])
    # Special handling for build number
    if ver[2] == 'X':
        if not 'BUILD_NUMBER' in os.environ:
            ver_ints[2] = 0
        else:
            ver_ints[2] = int(os.environ['BUILD_NUMBER'])
    else:
        ver_ints[2] = int(ver[2])

    bytes = ""
    for i in range(0, 4):
        if ver_ints[i] >= 0x10000:
            raise Exception("Version number too big")
        bytes = bytes + hex(ver_ints[i] & 0xFF) + ", " + hex(ver_ints[i] >> 8) + ", "
    return bytes

def get_working_dir_clean():
    git_status = subprocess.check_output(['git', 'status', '--porcelain', '-uno']).strip()
    return len(git_status) == 0

def get_building_from_jenkins():
    if not 'JOB_NAME' in os.environ:
        return False
    if not os.environ['JOB_NAME'].endswith("-committed"):
        return False
    return True

def do_file_substitutions(final_bytes, infilename, outfilename):
    with open(infilename, "r") as inf:
        with open(outfilename, "w") as outf:
            l = inf.readline()
            while l != '':
                newl = l.replace("###DNE###", "DO NOT EDIT THIS FILE")
                newl = newl.replace("###VERSIONINFO###", final_bytes)
                outf.write(newl)
                l = inf.readline()

def main():
    if len(sys.argv) < 3:
        print("Usage: %s infile outfile", sys.argv[0])
        sys.exit(1)

    githash = get_git_hash()
    version = get_version_info()
    working_dir_clean = get_working_dir_clean()
    building_from_jenkins = get_building_from_jenkins()

    flags_byte = 0
    if not working_dir_clean:
        flags_byte = flags_byte | 0b00000100
    if building_from_jenkins:
        flags_byte = flags_byte | 0b00000010

    final_bytes = githash + version + hex(flags_byte)

    do_file_substitutions(final_bytes, sys.argv[1], sys.argv[2])

if __name__=='__main__':
    main()
