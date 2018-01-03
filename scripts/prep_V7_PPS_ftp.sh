#!/bin/sh

# Run this using the command:  ftp -n  < /tmp/pps_ftp_commands.txt

outfile=/tmp/pps_ftp_commands.txt
rm $outfile
echo "open pps.gsfc.nasa.gov" >> $outfile
echo "user gpmgv R1dd!eMeT#is" >> $outfile
echo prompt >> $outfile

for file in `grep -E 1C21_CSI.0[0-1] ~/Desktop/list_1C21_1998-2009.txt`
  do
    yearDotOrbit=`echo $file | cut -f2-3 -d'.' | awk '{print "20"$1}'`
    #echo YearOrbit: $yearDotOrbit
    YYYY=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c1-4`
    MM=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c5-6`
    DD=`echo $yearDotOrbit | cut -f1 -d'.' | cut -c7-8`
    orbit=`echo $yearDotOrbit | cut -f2 -d'.'`
    for type in 1C21 2A23 2A25 2B31
      do
        echo "cd /itedata/ByVersion/ITE_206/$YYYY/$MM/$DD" >> $outfile
        echo "mget ${type}.${yearDotOrbit}.ITE_20*" >> $outfile
    done
done
echo bye >> $outfile
cat $outfile

exit
