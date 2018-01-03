#!/bin/sh
#
GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

satid="PR"
rundate=`date -u +%y%m%d`

MIR_DATA_DIR=${DATA_DIR}/prsubsets
MIR_LOG_FILE=${LOG_DIR}/mirror.${rundate}.log

    # catalog the files in the database - need separate logic for the GPM_KMA
    # subset files, as they have a different naming convention
    for type in 1C21 2A23 2A25 2B31
      do
        for file in `grep $type $MIR_LOG_FILE | grep Got | cut -f2 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
            echo $file | grep "GPM_KMA" > /dev/null
            if  [ $? = 0 ]
              then
                subset='GPM_KMA'
                version=`echo $file | cut -f4 -d '.'`
              else
	        temp1=`echo $file | cut -f4 -d '.'`
	        temp2=`echo $file | cut -f5 -d '.'`
	        # The product version number precedes (follows) the subset ID
	        # in the GPMGV (baseline CSI) product filenames.  Find which of
	        # temp1 and temp2 is the version number.
	        expr $temp1 + 1
	        if [ $? = 0 ]   # is $temp1 a number?
	          then
	            version=$temp1
		    subset=$temp2
	          else
	            expr $temp2 + 1
		    if [ $? = 0 ]   # is $temp2 a number?
		      then
		        subset=$temp1
		        version=$temp2
		      else
		        echo "Cannot find version number in PR filename: $file"\
		          | tee -a $LOG_FILE
		        exit 2
	    	    fi
	        fi
            fi
	    echo "subset ID = $subset" | tee -a $LOG_FILE
            #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo "INSERT INTO orbit_subset_product VALUES ('${satid}',\
${orbit},'${type}','${dateString}','${file}','${subset}');"
        done
    done
exit
