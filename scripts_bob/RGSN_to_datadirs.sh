#!/bin/sh
fromdir=~/Desktop
#fromdir='/tmp/RGSN'
basedir='/data/gv_radar/finalQC_in/RGSN/1CUF'

cd $fromdir
for file in `ls *.uf`
  do
    echo $file
    yyyymmdd=`echo $file | cut -f3 -d '_' | cut -c1-8`
    year=`echo $yyyymmdd | cut -c1-4`
    yrdir=`echo ${basedir}/${year}`
    mkdir -p $yrdir
    mmdd=`echo $yyyymmdd | cut -c5-8`
    daydir=`echo ${yrdir}/${mmdd}`
    mkdir -p $daydir
    cp -v $file $daydir
    #hour=`echo $file | cut -c15-16`
    #echo "Year = $year, MMDD = $mmdd, nominal = $hour"
done

exit
