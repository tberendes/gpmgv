#!/bin/sh
cd /data/netcdf/geo_match
for year in 06 07 08 09 10
  do
    for file in `ls *.${year}*.AtSite*`
     do
       newfile=`echo $file | sed 's/.AtSiteElev//'`
       mv -v $file $newfile
    done
done

exit
