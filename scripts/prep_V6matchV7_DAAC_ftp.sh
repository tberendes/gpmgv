#!/bin/sh

# Run this using the command:  ftp -n  < /tmp/daac_ftp_commands.txt

outfile=/tmp/daac_ftp_commands.txt
rm $outfile
echo "open disc2.nascom.nasa.gov" >> $outfile
echo "user anonymous kenneth.r.morris@nasa.gov" >> $outfile
#echo prompt >> $outfile

cd /data/prsubsets_v7_206
for file in `ls 1C21_CSI.*.KWAJ.ITE*`
  do
    yyyymmdd=`echo $file | cut -f2 -d'.'`
    yyyyddd=`ymd2yd $yyyymmdd`
    datepath=`echo $yyyyddd  | awk '{print substr($1,1,4)"/"substr($1,5,3)}'`
    yymmdd=`echo $yyyymmdd | cut -c3-8`
    orbit=`echo $file | cut -f3 -d'.'`
    daacfile=1C21_CSI.${yymmdd}.${orbit}.KWAJ.6.HDF.Z
    echo "get /ftp/data/s4pa//TRMM_L1/TRMM_1C21_CSI_KWAJ/${datepath}/$daacfile $daacfile" >> $outfile
    for type in 2A23 2A25 2B31
      do
        daacfile=${type}_CSI.${yymmdd}.${orbit}.KWAJ.6.HDF.Z
        echo "get /ftp/data/s4pa//TRMM_L2/TRMM_${type}_CSI_KWAJ/${datepath}/$daacfile $daacfile" >> $outfile
    done
done
echo close >> $outfile
cat $outfile

exit
