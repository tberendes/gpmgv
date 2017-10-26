#!/bin/sh
################################################################################
#
# get_PR_DPR_Meta.sh    Morris/SAIC/GPM GV    April 2014
#
# DESCRIPTION
# Child script called from get_PPS_CS_data.sh.  Runs the two metadata extraction
# scripts, get2A23-25MetaNew.sh and get2ADPRMeta.sh, which call IDL routines to
# do the metadata generation for a specific datestamped set of downloaded files,
# and then load their respective IDL outputs to the 'gpmgv' database.
#
# HISTORY
#
# 04/03/14 - Morris - Created.
# 08/26/14 - Morris - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
# 11/17/15 - Morris - Disabled PR metadata attempts (get2A23-25MetaNew.sh).
# 05/31/16 - Morris - Fixed location of log file get2ADPRMeta.${THISRUN}.log in
#                     diagnostic message/
#
################################################################################

GV_BASE_DIR=/home/gvoper
BIN_DIR=${GV_BASE_DIR}/scripts
DATA_DIR=/data/gpmgv
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs

umask 0002

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/get_PR_DPR_Meta.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
LOG_FILE=${META_LOG_DIR}/get_PR_DPR_MetaNew.${THISRUN}.log

echo "Processing DPR metadata only for datestamp ${THISRUN}" \
 | tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++"\
 | tee -a $LOG_FILE

     
# Call the IDL wrapper script, get2A23-25MetaNew.sh, to run the IDL .bat files
# to extract the PR file metadata.

#if [ -x ${BIN_DIR}/get2A23-25MetaNew.sh ]
#  then
#    DO2A2325='y'
#  else
#    DO2A2325='n'
#    echo "" | tee -a $LOG_FILE
#    echo "ERROR: Executable file ${BIN_DIR}/get2A23-25MetaNew.sh not found!" \
#      | tee -a $LOG_FILE
#    echo "Tag this rundate to be processed for metadata at a later run:" \
#      | tee -a $LOG_FILE
#    echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
#      ('get2A2325Meta','$THISRUN','$MISSING');" | psql -a -d gpmgv \
#      | tee -a $LOG_FILE 2>&1
#    echo ""  | tee -a $LOG_FILE
#    #exit 1
#fi

#if [ "${DO2A2325}" = "y" ]
#  then
#    echo "" | tee -a $LOG_FILE
#    echo "Calling get2A23-25MetaNew.sh to extract PR file metadata." \
#      | tee -a $LOG_FILE
#   
#    ${BIN_DIR}/get2A23-25MetaNew.sh $THISRUN
#    
#    echo "See log file ${LOG_DIR}/get2A23-25Meta.${THISRUN}.log" \
#     | tee -a $LOG_FILE
#    echo ""  | tee -a $LOG_FILE
#fi
     
# Call the IDL wrapper script, get2ADPRMeta.sh, to run the IDL .bat files
# to extract the DPR file metadata.

if [ -x ${BIN_DIR}/get2ADPRMeta.sh ]
  then
    DO2ADPR='y'
  else
    DO2ADPR='n'
    echo "" | tee -a $LOG_FILE
    echo "ERROR: Executable file ${BIN_DIR}/get2ADPRMeta.sh not found!" \
      | tee -a $LOG_FILE
    echo "Tag this rundate to be processed for metadata at a later run:" \
      | tee -a $LOG_FILE
    echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
      ('get2ADPRMeta','$THISRUN','$MISSING');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
    echo ""  | tee -a $LOG_FILE
    exit 1
fi

if [ "${DO2ADPR}" = "y" ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Calling get2ADPRMeta.sh to extract DPR file metadata." \
      | tee -a $LOG_FILE
    
#    ${BIN_DIR}/get2ADPRMeta.sh $THISRUN  # TEMPORARILY DISABLED FOR V05 REPROCESSING
    ${BIN_DIR}/get2ADPRMeta.sh $THISRUN 
    
    echo "See log file ${LOG_DIR}/meta_logs/get2ADPRMeta.${THISRUN}.log" \
     | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
fi

exit 0
