#!/bin/sh
for file in `cat /tmp/BrisbaneOrbits.txt`
  do
    orbit=`echo $file | cut -f6 -d '.' | cut -c3-6`
    date=`echo $file | cut -f5 -d '.' | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    starttime=`echo $file | cut -f5 -d '-' \
              | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)"+00"}'`
    endtime=`echo $file | cut -f6 -d '-' | cut -f3 -d '-' \
            | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)"+00"}'`
#    echo $file
    echo "$orbit|$date $starttime|$date $endtime"
done
exit
