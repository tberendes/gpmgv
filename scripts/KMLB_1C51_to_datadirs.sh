#!/bin/sh
fromdir='/data/tmp/MELB_Feb98/1C51'
basedir='/data/gv_radar/finalQC_in/KMLB/1C51'

cd $fromdir
for file in `ls *.HDF.Z`
  do
    echo $file
    year=`echo $file | cut -f2 -d'.' | cut -c1-2`
    yrdir=`echo ${basedir}/19${year}`
     mkdir -p $yrdir
    mmdd=`echo $file | cut -f2 -d'.' | cut -c3-6`
    daydir=`echo ${yrdir}/${mmdd}`
     mkdir -p $daydir
     cp -v $file $daydir
    #hour=`echo $file | cut -c15-16`
    #echo "Year = $year, MMDD = $mmdd, nominal = $hour"
done

exit
