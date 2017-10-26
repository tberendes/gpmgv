#!/bin/sh

# Run this using the command:  ftp -n  < /tmp/pps_ftp_commands.txt

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
LOG_DIR=${DATA_DIR}/logs
GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts

datelist=${DATA_DIR}/tmp/orbitsRainyBy100pts.txt
echo "\t \a \f '|' \o $datelist \
  \\\select distinct orbit from rainy100inside100 where \
   date_trunc('year', overpass_time at time zone 'UTC') = '2009-01-01' order by 1;" | psql gpmgv

outfile=/tmp/pps_ftp_commands.txt
rm $outfile
echo "open pps.gsfc.nasa.gov" >> $outfile
echo "user gpmgv R1dd!eMeT#is" >> $outfile
echo prompt >> $outfile

for file in `cat ~/list_1C21_2009.txt`
  do
    yearDotOrbit=`echo $file | cut -f2-3 -d'.' | awk '{print "20"$1}'`
    #echo YearOrbit: $yearDotOrbit
    YYYY=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c1-4`
    MM=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c5-6`
    DD=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c7-8`
    orbit=`echo $yearDotOrbit | cut -f2 -d'.'`
# check whether this orbit has any rainy cases !!!
    grep $orbit $datelist > /dev/null
    if [ $? = 0 ]
      then
        for type in 1C21 2A23 2A25
          do
            echo "cd /itedata/ByVersion/ITE_225/$YYYY/$MM/$DD" >> $outfile
            echo "mget ${type}.${yearDotOrbit}.ITE_225*" >> $outfile
            echo "Getting orbit $orbit"
        done
      else
        echo "Skipping orbit $orbit"
    fi
done
echo bye >> $outfile
cat $outfile

exit
