#!/bin/sh

# tar up the matching netcdf file pairs
tarfile=/data/netcdf/RGSN_netCDF_gridfiles.tar
cd /data/netcdf/PR
for file in `ls *RGSN*`
  do
    #filepatt=`echo $file |cut -f4 -d'.'`
    filepatt=`echo $file | sed 's/PRgrids//' | sed 's/.nc.gz//'`
    gvfile=`ls ../NEXRAD_REO/allYMD/GVgridsREO*${filepatt}* > /dev/null 2>&1`
    if [ $? != 0 ]
    then
      echo "PR: $file   GV: $gvfile"
      #tar rvf $tarfile $file
      #cd /data/netcdf/NEXRAD_REO/allYMD
      #tar rvf $tarfile *${filepatt}*
      #cd /data/netcdf/PR
    fi
done
