#!/bin/sh
#

switchtime=1500
today=`date -u +%Y%m%d`
now=`date -u "+%H%M"`
if [ `expr $now \> $switchtime` = 1 ]
  then
#    yesterday's file should be ready, get it
     ctdate=`offset_date $today -1`
else
#    get file from two days back
     ctdate=`offset_date $today -2`
fi

echo $ctdate

#  Trim date string to use a 2-digit year, as in CT filename convention
yymmdd=`echo $ctdate | cut -c 3-8`
