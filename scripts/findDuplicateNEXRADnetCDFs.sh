#!/bin/sh

cd /data/netcdf/NEXRAD
for dotnc in `ls *.nc`
do
ls ${dotnc}*
done