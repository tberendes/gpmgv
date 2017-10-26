#!/bin/sh

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

satid="PR"
# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired data files, if any
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
INCOMPLETE='I' # could not complete all steps, could be external problem

#Edit to whichever mirror file's listings need to be loaded:
MIR_LOG_FILE='/data/logs/mirror.081022.log' 
rundate=`echo $MIR_LOG_FILE | cut -f2 -d'.'`
LOG_FILE=${LOG_DIR}/catalogMissingPRdata.${rundate}.log
export rundate

umask 0002
    
    # catalog the files in the database
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
	    ${orbit},'${type}','${dateString}','${file}','${subset}');" \
	    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        done
    done

    # Call the IDL wrapper script, get2A23-25Meta.sh, to run the IDL .bat files
    # to extract the file metadata.
    if [ -x ${BIN_DIR}/get2A23-25Meta.sh ]
      then
        echo "" | tee -a $LOG_FILE
        echo "Calling get2A23-25Meta.sh to extract PR file metadata." \
          | tee -a $LOG_FILE
    
        ${BIN_DIR}/get2A23-25Meta.sh $rundate
    
        echo "See log file ${LOG_DIR}/get2A23-25Meta.${rundate}.log" \
         | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
#        echo "UPDATE appstatus SET status = '$SUCCESS' \
#          WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
#          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
      else
        echo "" | tee -a $LOG_FILE
        echo "ERROR: Executable file ${BIN_DIR}/get2A23-25Meta.sh not found!" \
          | tee -a $LOG_FILE
        echo "Tag this rundate to be processed for metadata at a later run:" \
          | tee -a $LOG_FILE
	echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
          ('get2A2325Meta','$rundate','$MISSING');" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
        echo ""  | tee -a $LOG_FILE
        echo "Tag this script's run as INCOMPLETE, though problem is external:"\
          | tee -a $LOG_FILE
#        echo "UPDATE appstatus SET status = '$INCOMPLETE' \
#          WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
#          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi

exit
