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

# tar up individual tar files into single-site files
cd /data/netcdf
for sitefile in `ls grids.*.tar  | cut -f2 -d '.' | sort -u`
  do
    tarfile=/data/netcdf/VN_Grids100rainyIn100km.${sitefile}.tar
    tar cvf $tarfile grids.*${sitefile}*.tar
done

rm grids.*.tar
