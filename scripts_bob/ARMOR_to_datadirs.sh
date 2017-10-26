#!/bin/sh
fromdir='/tmp/ARMOR'
basedir='/data/gv_radar/finalQC_in/RMOR/1CUF'

cd $fromdir
for file in `ls *.uf.gz`
  do
    echo $file
    year=`echo $file | cut -c7-10`
    yrdir=`echo ${basedir}/${year}`
    mkdir -p $yrdir
    mmdd=`echo $file | cut -c11-14`
    daydir=`echo ${yrdir}/${mmdd}`
    mkdir -p $daydir
    cp -v $file $daydir
    #hour=`echo $file | cut -c15-16`
    #echo "Year = $year, MMDD = $mmdd, nominal = $hour"
done

exit
