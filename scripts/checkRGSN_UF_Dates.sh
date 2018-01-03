#!/bin/sh

# Checks for where RGSN UF file datestamp is different day than UTC day of data within

for row in `cat /data/tmp/reorder/file1CUFtodo.allYMD.txt | sed 's/  */^/g'`
do
dbday=`echo $row | cut -f2 -d'^'`
ufday=`echo $row | cut -f3 -d'_' | cut -c7-8`
orbit=`echo $row | cut -f2 -d'|'`
#echo "$dbday != $ufday ?"
if [ $dbday != $ufday ]
  then
    echo $row
    echo $orbit | tee -a /data/tmp/RGSNorbits2reorder.unl
fi
done
exit