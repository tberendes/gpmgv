#!/bin/sh
GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

satid="PR"
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getPRdataTest.${rundate}.log
export rundate
MIR_LOG_FILE=${LOG_DIR}/mirror.${rundate}.log

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getPRdata_dbtestfile
if [ -s ${DBTEMPFILE} ]
  then
    rm -v ${DBTEMPFILE}
fi

    # catalog the files in the database
    for type in 1C21 2A23 2A25 2B31
      do
        for file in `grep $type $MIR_LOG_FILE | grep Got | cut -f2 -d '/' \
                     | cut -f1 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
	    temp1=`echo $file | cut -f4 -d '.'`
	    temp2=`echo $file | cut -f5 -d '.'`
	    # The product version number precedes (follows) the subset ID
	    # in the GPMGV (baseline CSI) product filenames.  Find which of
	    # temp1 and temp2 is the version number.
	    expr $temp1 + 1 > /dev/null 2>&1
	    if [ $? = 0 ]   # is $temp1 a number?
	      then
	        version=$temp1
		subset=$temp2
	      else
	        expr $temp2 + 1 > /dev/null 2>&1
		if [ $? = 0 ]   # is $temp2 a number?
		  then
		    subset=$temp1
		    version=$temp2
		  else
		    echo "Cannot find version number in PR filename: $file" \
		      | tee -a $LOG_FILE
		    exit 2
		fi
	    fi
	    echo "subset ID = $subset, Version = $version" | tee -a $LOG_FILE
	    echo "${satid}|${orbit}|${type}|${dateString}|${file}|${subset}|${version}"\
	    | tee -a ${DBTEMPFILE}
        done
    done
    
if [ -s ${DBTEMPFILE} ]
  then
    cat ${DBTEMPFILE}
fi
