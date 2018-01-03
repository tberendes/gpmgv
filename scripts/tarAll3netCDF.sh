#!/bin/sh

# tar up the matching netcdf file triplets
cd /data/netcdf/PR
for file in `ls *`
  do
    filepatt=`echo $file | sed 's/PRgrids//' | sed 's/.nc.gz//'`
    tarfile=/data/netcdf/grids${filepatt}.tar
#    gvfile=`ls NEXRAD/*${filepatt}*`
#    echo "PR: $file   GV: $gvfile   TAR: $tarfile"
    tar cvf $tarfile $file
    cd /data/netcdf/NEXRAD
    tar rvf $tarfile *${filepatt}*
    cd /data/netcdf/NEXRAD_REO/allYMD
    tar rvf $tarfile *${filepatt}*
    cd /data/netcdf/PR
done

# tar up individual tar files into monthly files
cd /data/netcdf
for monfile in `ls grids.*.tar  | cut -f3 -d '.' | cut -c 1-4 | sort -u`
  do
    tarfile=/data/netcdf/VN_Grids100rainyIn100km.${monfile}.tar
    tar cvf $tarfile grids.*${monfile}*.tar
done

rm grids.*.tar
