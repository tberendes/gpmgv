#!/bin/sh

# set and export 2 environment variables to pass information to the IDL batch script 
IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/geo_match
export IDL_PRO_DIR
CONTROLFILE=/data/tmp/DPR_files_sites4geoMatch.2AKu.NS.V03B.161225.txt
export CONTROLFILE

IDL=/usr/local/bin/idl
BATFILE=polar2dpr_hs_ms_ns.bat     # the IDL batch script to run

# check that the to-be-called scripts are found
if [ ! -s ${IDL_PRO_DIR}/${BATFILE} ]
  then
     echo "" | tee -a $LOG_FILE
     echo "FATAL: Script ${IDL_PRO_DIR}/${BATFILE} not found, " \
       | tee -a $LOG_FILE
     echo "exiting with appstatus value = 'UNTRIED' for ${kind} for datestamp ${THISRUN}." \
       | tee -a $LOG_FILE
     exit 1
fi

echo "=============================================" | >> $LOG_FILE

    echo "Calling IDL"  | tee -a $LOG_FILE

    $IDL < ${IDL_PRO_DIR}/${BATFILE} | tee -a $LOG_FILE 2>&1

echo "=============================================" | >> $LOG_FILE
echo ""

exit 0
