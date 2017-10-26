#!/bin/sh

cd /data/netcdf/geo_match
for sitefile in `ls GRtoPR.*.cal.nc.gz  | grep -v KWAJ`
  do
    newname=`echo ${sitefile} | sed 's/.cal//'`
    mv -v ${sitefile} $newname
done
