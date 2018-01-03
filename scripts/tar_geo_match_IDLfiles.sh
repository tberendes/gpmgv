#!/bin/sh

# tar_geo_match_IDLfiles.sh

cd /home/morris/swdev/idl/dev
dir=`pwd`
#tarfile=${dir}/GPM_VN_geo_match.tar
tarfile=${dir}/GPM_VN_geo_match_v1_1.tar

#for file in `cat geo_match_resolved_to_tar.txt | grep -v rsl_in_idl`
for file in `cat geo_match_resolved_to_tar_V1_1.txt | grep -v rsl_in_idl`
  do
      tar -rvf $tarfile $file
done

cd ..

tar -rvf $tarfile rsl_in_idl

exit
