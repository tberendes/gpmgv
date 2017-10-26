#!/bin/sh

################################################################################
#
# get2AGPROF_RRgrids4date.sh    Morris/SAIC/GPM GV    Feb 2017
#
# DESCRIPTION
#   Runs IDL in batch mode to grid rainrate from 2AGPROF orbit subset data files
#   for NEXRAD sites overpassed in each orbit.  Files, orbits, and overpassed
#   NEXRAD sites are listed in the filename provided as the single argument to
#   this script.  This filename is set as an environment variable so that IDL
#   can extract the filename from the environment.  IDL will write grid arrays
#   to IDL binary Save files.
#
#   This script has a sleep/retry feature in case the IDL single-user license
#   is occupied by another user/process.  It will sleep 30 minutes between
#   attempts.  After 8 times hitting the Snooze button, it will give up and
#   flag the timed-out run to be reattempted the next time this script is run.
#
# FILES
#   file2AGPROFsites.YYMMDD.txt (INPUT) - text file listing 2AGPROF files, orbits, and
#                                      NEXRAD sites overpassed in each orbit. 
#                                      YYMMDD is passed to this script as the
#                                      sole argument.  YYMMDD is the yr, month,
#                                      day of the run, not necessarily of the
#                                      data.  The full file pathname is
#                                      generated within this script.
#   grid_2AGPROF_rain.bat (INTERNAL)    - Batch file of IDL commands to be run.
#   Meta2AGPROF_dbtempfile (INTERNAL)   - re-used file to temporarily hold output
#                                      from database queries
#   Meta2AGPROF_todo.txt (INTERNAL)     - re-used file to temporarily hold list of
#                                      all YYMMDDs to process in this run
#
#  DATABASE
#    Status of the script run is maintained in the 'appstatus' table, under the
#    app_id value 'getGPROFgrid4dy'.
#
#  LOGS
#    Output for script run logged to daily log file get2AGPROF_RRgrids4date.YYMMDD.log
#    in $META_LOG_DIR directory.  YYMMDD is replaced by the input date.
#
#  CONSTRAINTS
#    - User must have write privileges in $TMP_DIR, $LOG_DIR directories
#
################################################################################


USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev
           IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/gridgen ;;
  gvoper ) GV_BASE_DIR=/home/gvoper
           IDL_PRO_DIR=${GV_BASE_DIR}/idl ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"
export IDL_PRO_DIR                 # IDL grid_2AGPROF_rain.bat needs this

BIN_DIR=${GV_BASE_DIR}/scripts
IDL=/usr/local/bin/idl
DATA_DIR=/data/gpmgv
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/Meta2AGPROF_dbtempfile
# re-used file listing all yymmdd to be processed this run
META2AGPROF=${TMP_DIR}/Meta2AGPROF_todo.txt
rm -f $META2AGPROF $DBTEMPFILE

# Constants for possible status of processing, for appstatus table in database
UNTRIED='U'    # haven't attempted processing yet
SUCCESS='S'    # got IDL license and ran metadata extracts
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed in processing, make no more attempts

have_retries='f'  # indicates whether we have missing prior filedates to retry
status=$UNTRIED   # assume we haven't yet tried to do current yymmdd

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/get2AGPROF_RRgrids4date.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
LOG_FILE=${META_LOG_DIR}/get2AGPROF_RRgrids4date.${THISRUN}.log
echo "Processing 2AGPROF metadata for rundate ${THISRUN}" | tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# add this run's yymmdd to to-do list
echo $THISRUN >> $META2AGPROF

# check that the to-be-called scripts are found and/or executable

if [ ! -s ${IDL_PRO_DIR}/grid_2AGPROF_rain.bat ]
  then
     echo "Script ${IDL_PRO_DIR}/grid_2AGPROF_rain.bat not found, exiting" \
       | tee -a $LOG_FILE
     echo "with status 'UNTRIED', no metadata processed for ${THISRUN}." \
       | tee -a $LOG_FILE
     exit 1
fi

for yymmdd in `cat $META2AGPROF`
  do
    GETMYMETA=${TMP_DIR}/file2AGPROFsites.${yymmdd}.txt
    if [ -s $GETMYMETA ]
      then
        RUNDATE=$yymmdd
      	export RUNDATE            # DB query needs this
       	export GETMYMETA          # IDL grid_2AGPROF_rain.bat needs this
       	echo "" | tee -a $LOG_FILE
       	echo "=============================================" | tee -a $LOG_FILE
       	echo "Calling IDL for yymmdd = ${yymmdd}, file = $GETMYMETA" \
            	 | tee -a $LOG_FILE
       	echo "" | tee -a $LOG_FILE
        
       	$IDL < ${IDL_PRO_DIR}/grid_2AGPROF_rain.bat | tee -a $LOG_FILE 2>&1
	
       	echo "=============================================" | tee -a $LOG_FILE
    fi
done

echo "" | tee -a $LOG_FILE
echo "get2AGPROF_RRgrids4date.sh complete." | tee -a $LOG_FILE
exit 0
