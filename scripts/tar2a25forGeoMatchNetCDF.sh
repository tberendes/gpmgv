#!/bin/sh

# tar up the 2A25s matching the geo_match netcdf files
cd /data/netcdf/geo_match

tarfile=/data/netcdf/PR_2A25_2008_for_GeoMatch.tar
if [ -s $tarfile ]
  then
    rm -v $tarfile
fi

for orbit in `ls * | cut -f4 -d'.' | sort -u`
  do
    #orbit=`echo $file | cut -f4 -d'.'`
    echo "For geomatch orbit: ${orbit} found 2A25(s):"
    for file25 in `ls /data/prsubsets/2A25/*.${orbit}.*`
      do
        echo $file25
        tar rvf $tarfile $file25
    done
done
