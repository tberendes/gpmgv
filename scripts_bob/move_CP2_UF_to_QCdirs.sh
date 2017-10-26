#!/bin/sh

ufdir=/data/gpmgv/gv_radar/finalQC_in/CP2/1CUF
cd $ufdir/2014

for uf in `ls CP2_ppi_gpm_2014*`
  do
    mmdd=`echo $uf | cut -f4 -d '_' | cut -c5-8`
#    echo "File: $uf  Dir: $ufdir/2014/$mmdd"
    mkdir -p $mmdd
    mv -v $uf $mmdd
done

cd $ufdir/2015
for uf in `ls CP2_ppi_gpm_2015*`
  do
    mmdd=`echo $uf | cut -f4 -d '_' | cut -c5-8`
#    echo "File: $uf  Dir: $ufdir/2015/$mmdd"
    mkdir -p $mmdd
    mv -v $uf $mmdd
done

exit
