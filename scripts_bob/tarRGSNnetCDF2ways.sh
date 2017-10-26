#!/bin/sh

# tar up the matching netcdf file pairs
tarfile=/data/netcdf/RGSN_netCDF_gridfiles2.tar

if [ -f $tarfile ]
then
  echo "Output tar file $tarfile exists, move or delete it.  Exiting."
  exit 1
fi

cd /data/netcdf/PR
for file in `ls *RGSN*`
  do
    filepatt=`echo $file | sed 's/PRgrids//' | sed 's/.nc.gz//'`
    gvfile=`ls ../NEXRAD_REO/allYMD/GVgridsREO*${filepatt}*  2>/dev/null`
    if [ $? = 0 ]
    then
      echo "PR: $file   GV: $gvfile"
      tar rvf $tarfile $file
      cd /data/netcdf/NEXRAD_REO/allYMD
      tar rvf $tarfile *${filepatt}*
      cd /data/netcdf/PR
    else
      echo "GET BY ORBIT MATCH:"
      filepatt=`echo $file | cut -f4 -d'.'`
      gvfile=`ls ../NEXRAD_REO/allYMD/GVgridsREO.RGSN.0*.${filepatt}.*`
      if [ $? = 0 ]
      then
        echo "PR: $file   GV: $gvfile"
        tar rvf $tarfile $file
        cd /data/netcdf/NEXRAD_REO/allYMD
        tar rvf $tarfile *${filepatt}*
        cd /data/netcdf/PR
      fi
    fi
done
