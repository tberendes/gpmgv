#!/bin/sh
for file in `ls /data/gpmgv/orbit_subset/GPM/DPR/2ADPR/V03B/CONUS/2015/10/* | grep HDF`
  do
    orbit=`echo $file | cut -f6 -d '.' | cut -c3-6`
    date=`echo $file | cut -f5 -d '.' | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    yyyymmdd=`echo $file | cut -f5 -d '.' | cut -f1 -d '-'`
    starttime=`echo $file | cut -f5 -d '-' \
              | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)"+00"}'`
    endtime=`echo $file | cut -f6 -d '-' | cut -f3 -d '-' \
            | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)"+00"}'`
#    echo $file
    starthr=`echo $starttime | cut -f1 -d ':'`
    endhr=`echo $endtime | cut -f1 -d ':'`
    if [ $starthr \> $endhr ]
      then
        #echo "Incrementing end date for file: $file"
        endyyyymmdd=`offset_date $yyyymmdd 1`
        enddate=`echo $endyyyymmdd | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
      else
        enddate=$date
    fi
    echo "$orbit|$date $starttime|$enddate $endtime"
done
exit
