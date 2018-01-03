#!/bin/sh

# tar up the matching netcdf file pairs
cd /data/netcdf/PR
for file in `ls *`
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
for monfile in `ls grids.*.tar  | cut -f3 -d '.' | cut -c 1-4 | sort -u`
  do
    tarfile=/data/netcdf/Grids25overlap25rain.${monfile}.tar
    tar cvf $tarfile grids.*.${monfile}*.tar
done

rm grids.*.tar
