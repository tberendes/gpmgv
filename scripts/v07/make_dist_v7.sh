#!/bin/bash
# This script can be copied from the Git repo
# and executed to create a full instance
# of the geomatch code.
# This assumes that the git repository for gpmgv is
# under your home directory and the idl environment
# has been configured to include the git/gpmgv/idl
# directory and all of it's subdirectories in the
# IDL_PATH variable.  Git shoudl be updated by:
#     cd ~/git/gpmgv
#     git pul origin master
mkdir -p v7_geomatch/idl
mkdir -p v7_geomatch/scripts
cp ~/git/gpmgv/scripts/v07/* v7_geomatch/scripts
chmod 755 v7_geomatch/scripts/*
cp ~/git/gpmgv/idl/geo_match/v07/*.bat v7_geomatch/idl
cd v7_geomatch/idl
idl < make_saves_v7.bat
