#!/bin/bash
# This script can be copied from the Git repo
# and executed to create a deployable instance of getmetadata2adpr_v7
# This assumes that the git repository for gpmgv is
# under your home directory and the idl environment
# has been configured to include the git/gpmgv/idl
# directory and all of it's subdirectories in the
# IDL_PATH variable.  Git shoudl be updated by:
#     cd ~/git/gpmgv
#     git pul origin master
mkdir -p v7_metadata/idl
cp -a ~/git/gpmgv/idl/getmetadata/v07/*.bat v7_metadata/idl
cd v7_metadata/idl
idl < make_saves_v7.bat
