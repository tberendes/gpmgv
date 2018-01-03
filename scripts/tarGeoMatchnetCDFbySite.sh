#!/bin/sh

# tar up the netcdf files by site
cd /data/netcdf/geo_match
for sitefile in `ls GRtoPR.*  | cut -f2 -d '.' | sort -u`
  do
    tarfile=/data/netcdf/GRtoPR.${sitefile}.tar
    tar cvf $tarfile GRtoPR.${sitefile}*
done
