#!/bin/sh

################################################################################
#
# grid_1C21_2A25_2A55.sh    Morris/SAIC/GPM GV    October 2006
#
# DESCRIPTION
#   Runs IDL in batch mode to generate 3D grids and write them to netCDF files
#   for NEXRAD sites overpassed in each orbit.  Files, orbits, and overpassed
#   NEXRAD sites are listed in the filename provided as the single argument to
#   this script.  This filename is set as an environment variable so that IDL
#   can extract the filename from the environment.
#
#   This script has a sleep/retry feature in case the IDL single-user license
#   is occupied by another user/process.  It will sleep 30 minutes between
#   attempts.  After 8 times hitting the Snooze button, it will give up and
#   flag the timed-out run to be reattempted the next time this script is run.
#
# FILES
#   PR_files_sites4gridCases.YYMMDD.txt (INPUT) - lists data files, orbits, and
#                                      NEXRAD sites overpassed in each orbit. 
#                                      YYMMDD is passed to this script as the
#                                      sole argument.  YYMMDD is the yr, month,
#                                      day of the run, not necessarily of the
#                                      data.  The full file pathname is
#                                      generated within this script.
#   get_PR_and_GV_ncgrids.bat (INTERNAL) - Batch file of IDL commands to be run.
#
#  DATABASE
#    Status of the script run is maintained in the 'appstatus' table,
#    under the app_id value 'gridPRandGV'.
#
#  LOGS
#    Output for script run logged to log file grid_1C21_2A25_2A55.log
#    in data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and SELECT, UPDATE, INSERT privileges on tables. 
#      Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $TMP_DIR, $LOG_DIR directories
#
################################################################################


GV_BASE_DIR=/home/morris/swdev
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl/valnet/gridgen  # change for operational
export IDL_PRO_DIR                 # IDL get_PR_and_GV_ncgrids.bat needs this
IDL=/usr/local/bin/idl
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/grid_1C21_2A25_2A55_dbtempfile
# re-used file listing all yymmdd to be processed this run
DATES2GRID=${TMP_DIR}/grid_1C21_2A25_2A55_todo.txt
rm -f $DATES2GRID $DBTEMPFILE

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
     LOG_FILE=${LOG_DIR}/grid_1C21_2A25_KHTX.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUNFILE=$1
LOG_FILE=${LOG_DIR}/grid_1C21_2A25_KHTX.log
echo "Processing 3D grids for control file ${THISRUNFILE}" | tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

THISRUN=`echo $THISRUNFILE | cut -f2 -d'.'`

# initialize the appstatus table entry for this run's yymmdd
# check whether we have an entry for this yymmdd in database
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'ncgridPRhtx' AND datestamp = '${THISRUN}';" \
  | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1

if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to do this yymmdd before, get our past status.
     status=`cat ${DBTEMPFILE}`
     echo "Rundate ${THISRUN} has been attempted before with status = $status" \
     | tee -a $LOG_FILE
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus (app_id, datestamp, status) VALUES \
       ('ncgridPRhtx', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# check whether we have prior control files/dates that didn't get processed
echo "" | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT datestamp FROM appstatus \
      WHERE app_id = 'ncgridPRhtx' AND status = '$UNTRIED' \
      AND datestamp != '${THISRUN}';" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
if [ -s ${DBTEMPFILE} ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Need to retry processing for prior control file dates below:" \
       | tee -a $LOG_FILE
     have_retries='t'
     cat ${DBTEMPFILE} | tee -a $LOG_FILE
     cp ${DBTEMPFILE} $DATES2GRID
fi

# add this run's yymmdd to to-do list, if not already processed successfully
# or if this yymmdd didn't exit fatally in last attempt
case $status in
  $SUCCESS )
    echo "Status indicates yymmdd = ${THISRUN} already successfully processed."\
     | tee -a $LOG_FILE
    if [ $have_retries = 'f' ]
      then
        echo "No file dates to process this run, exiting." | tee -a $LOG_FILE
	exit 0
    fi
  ;;
  $FAILED )
    echo "Status indicates yymmdd = ${THISRUN} had prior fatals, skipping."\
     | tee -a $LOG_FILE
    if [ $have_retries = 'f' ]
      then
        echo "No file dates to process this run, exiting." | tee -a $LOG_FILE
	exit 0
    fi
  ;;
  * )
    echo $THISRUN >> $DATES2GRID
  ;;
esac

# check whether the IDL license manager is running. If not, we are done for,
# and will have to exit and leave the input run date flagged as one to be
# re-run next time
ps -ef | grep "rsi/idl" | grep lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    echo "FATAL: IDL license manager not running!" | tee -a $LOG_FILE
    exit 1
fi

# check that the to-be-called scripts are found
if [ ! -s ${IDL_PRO_DIR}/get_PR_ncgrids.bat ]
  then
     echo "Script ${IDL_PRO_DIR}/get_PR_ncgrids.bat not found, exiting" \
       | tee -a $LOG_FILE
     echo "with status 'UNTRIED', no data processed for ${THISRUN}." \
       | tee -a $LOG_FILE
     exit 1
fi

# check whether the IDL license is tied up by another user.  Sleep a few times
# until it comes free.  If we time out, then leave the input run date flagged
# as one to be re-run next time, and exit.

ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    idl_free='t'
  else
    idl_free='f'
fi

declare -i napnum=1
until [ "$idl_free" = 't' ]
  do
    echo "" | tee -a $LOG_FILE
    echo "Attempt $napnum, waiting $ZZZ seconds for IDL license to free up."\
     | tee -a $LOG_FILE
    #sleep $ZZZ
    sleep 3         # sleep value for testing
    napnum=napnum+1
    if [ $napnum -gt $naps ]
      then
	echo "" | tee -a $LOG_FILE
	echo "Exiting after $naps attempts to get IDL license."\
	 | tee -a $LOG_FILE
	exit 1
    fi
    ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
    if [ $? = 1 ]
      then
        idl_free='t'
    fi
done

for yymmdd in `cat $DATES2GRID`
  do
    GETMYGRIDS=${DATA_DIR}/tmp/PR_files_sites4gridCases.${yymmdd}.txt
    if [ -s $GETMYMETA ]
      then
        RUNDATE=$yymmdd
	export RUNDATE            # IDL get_PR_and_GV_ncgrids.pro needs this
	export GETMYGRIDS          # IDL get_PR_and_GV_ncgrids.pro needs this
	echo "" | tee -a $LOG_FILE
	echo "UPDATE appstatus SET ntries = ntries + 1 \
	      WHERE app_id = 'ncgridPRhtx' AND datestamp = '$RUNDATE';" \
	 | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	echo "" | tee -a $LOG_FILE
	echo "=============================================" | tee -a $LOG_FILE
	echo "Calling IDL for yymmdd = ${yymmdd}, file = $GETMYGRIDS" \
	 | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
        
	$IDL < ${IDL_PRO_DIR}/get_PR_ncgrids.bat | tee -a $LOG_FILE 2>&1
	
	echo "=============================================" | tee -a $LOG_FILE
	
	# check the IDL output file before declaring success

	        echo "UPDATE appstatus SET status = '$SUCCESS' \
	          WHERE app_id = 'ncgridPRhtx' AND datestamp = '$RUNDATE';" \
	          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi
done

echo "" | tee -a $LOG_FILE
echo "grid_1C21_2A25_KHTX.sh complete, exiting." | tee -a $LOG_FILE
exit 0
