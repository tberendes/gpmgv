#!/bin/sh
#
satid="PR"
#MIR_LOG_FILE=${MIR_DATA_DIR}/gpmprsubsets.log

for MIR_LOG_FILE in `ls /data/logs/mirror.*.log`
do

if [ -s $MIR_LOG_FILE ]
  then
    for type in 1C21 2A23 2A25
      do
        for file in `grep $type $MIR_LOG_FILE | cut -f2 -d '/' | cut -f1 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
            #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo "insert into orbit_subset_product \
	    values('${satid}',${orbit},'${type}','${dateString}','${file}');" \
	    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        done
    done
fi
done