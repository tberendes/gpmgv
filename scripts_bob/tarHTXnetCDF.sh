#!/bin/sh

# tar up the matching netcdf file pairs
cd /data/netcdf/PR
for file in `ls *HTX*`
  do
    filepatt=`echo $file | sed 's/PR//' | sed 's/.nc.gz//'`
    tarfile=/data/netcdf/${filepatt}.tar
#    gvfile=`ls NEXRAD/*${filepatt}*`
#    echo "PR: $file   GV: $gvfile   TAR: $tarfile"
    tar cvf $tarfile $file
    cd /data/netcdf/NEXRAD
    tar rvf $tarfile *${filepatt}*
    cd /data/netcdf/PR
done

# tar up individual tar files into monthly files
cd /data/netcdf
tarfile=/data/netcdf/Grids_25overlap25rain.KHTX.tar
tar cvf $tarfile *KHTX*.tar

rm grids.*.tar
