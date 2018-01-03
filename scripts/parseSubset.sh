#!/bin/sh

DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs

rundate=$1

MIR_LOG_FILE=${LOG_DIR}/mirror.${rundate}.log
    
    # catalog the files in the database
    for type in 1C21 2A23 2A25
      do
        for file in `grep $type $MIR_LOG_FILE | cut -f2 -d '/' | cut -f1 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
	    temp1=`echo $file | cut -f4 -d '.'`
	    temp2=`echo $file | cut -f5 -d '.'`
	    # The product version number precedes (follows) the subset ID
	    # in the GPMGV (baseline CSI) product filenames
	    if [ $temp1 = '6' ]
	      then
	        subset=$temp2
	      else
	        subset=$temp1
	    fi
	    echo "subset ID = $subset"
            echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo "INSERT INTO orbit_subset_product \
	    VALUES('${satid}',${orbit},'${type}','${dateString}','${file}');"# \
#	    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        done
    done
exit
