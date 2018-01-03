#!/bin/sh

cd /data/netcdf/PR
for dotnc in `ls *.nc`
do
ls ${dotnc}*
done