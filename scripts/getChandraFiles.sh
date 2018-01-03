#!/bin/sh
###############################################################################
# getChandraFiles.sh
#
#   Using control file '/data/tmp/ChandraFileList.txt' make a tar file for each
#   overpass's raw (Level II) WSR-88D and matching 1C21, 2A23, and 2A55 files.
##############################################################################

umask 0002
cd /data/tmp
for file in `cat ChandraFileList.txt | sed 's/ //g'`
  do
#    file=`echo $filerec | sed 's/ //g'`
#    echo $filerec
    radar=`echo $file | cut -f1 -d'|'`
    dirnex=/data/gv_radar/defaultQC_in/${radar}/
    orbit=`echo $file | cut -f2 -d'|'`
    distance=`echo $file | cut -f3 -d'|'`
    subpath=`echo $file | cut -f4 -d'|'`
    nexrad=`echo $file | cut -f5 -d'|'`
    nexradfil=${dirnex}${subpath}/${nexrad}
    PR1C21=`echo $file | cut -f6 -d'|'`
    PR1C21fil=/data/prsubsets/1C21/$PR1C21
    PR2A23=`echo $file | cut -f7 -d'|'`
    PR2A23fil=/data/prsubsets/2A23/$PR2A23
    PR2A25=`echo $file | cut -f8 -d'|'`
    PR2A25fil=/data/prsubsets/2A25/$PR2A25
    tarfile=$radar.$orbit.${distance}_km.tar
    cp -v $nexradfil .
    cp -v $PR1C21fil .
    cp -v $PR2A23fil .
    cp -v $PR2A25fil .
    chmod a+w $nexradfil $PR1C21fil $PR2A23fil $PR2A25fil
    echo "tar file = $tarfile"
    tar -cvf $tarfile $nexrad $PR1C21 $PR2A23 $PR2A25
    rm -vf /data/tmp/$nexrad /data/tmp/$PR1C21 /data/tmp/$PR2A23 /data/tmp/$PR2A25
done

exit
    