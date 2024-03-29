#!/bin/sh

################################################################################
#
# do_geo_matchup_23.sh    Morris/SAIC/GPM GV    September 2008
#
# DESCRIPTION
#   Called by doGeoMatch4SelectCases.sh, which generates the needed inputs.
#   Runs IDL in batch mode to generate GV-PR matchups and write them to netCDF
#   files, for radar sites that are overpassed in each orbit for a specified
#   date (UTC) and have precipitation echoes.  Files, orbits, and overpassed
#   radar sites are listed in the well-known filename whose YYMMDD date part
#   is provided as the single argument to this script.  This filename is set
#   as an environment variable so that IDL can extract the filename from the
#   environment.  The script tracks the status of grid processing for the date
#   YYMMDD via entries in the 'appstatus' table in the 'gpmgv' database, and
#   takes appropriate actions according to the status of the date's grid run.
#   It also looks at the status of dates other than YYMMDD to see if there is a
#   need to re-try processing for dates where the prior run was unsuccessful.
#
#   This script has a sleep/retry feature in case the IDL single-user license
#   is occupied by another user/process.  It will sleep 30 minutes between
#   attempts.  After 8 times hitting the Snooze button, it will give up and
#   flag the timed-out run to be reattempted the next time this script is run.
#
# ARGUMENTS
#   YYMMDD - A single string listing the 2-digit year, month, and day of the
#            site overpasses for which grids are to be generated.  No validity
#            checks are performed on the value of this date string, other than
#            that is must fit within the database field 'datestamp'.
#
# FILES
#   PR_files_sites4geoMatch.YYMMDD.txt (INPUT) - lists data files, orbits, and
#                                      NEXRAD sites overpassed in each orbit. 
#                                      YYMMDD is passed to this script as the
#                                      sole argument.  YYMMDD is the yr, month,
#                                      day of the run, not necessarily of the
#                                      data.  The full file pathname is
#                                      generated within this script.
#   polar2pr_23.bat (INTERNAL) - Batch file of IDL commands to be run.
#
#  DATABASE
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the app_id attribute value 'gridPRandGV'.
#
#  LOGS
#    Output for script run is logged to file do_geo_matchup.log
#    in the $LOG_DIR directory, unless improper number of arguments are passed.
#    In this case the error is written to a current-date-specific log file
#    do_geo_matchup.yymmdd.fatal.log in $LOG_DIR, where 'yymmdd' is for the
#    date the script run was attempted, not the input data date.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and SELECT, UPDATE, INSERT privileges on tables. 
#      Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $TMP_DIR, $LOG_DIR directories
#
################################################################################


GV_BASE_DIR=/home/morris/swdev                 # change for operational
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/geo_match  # change for operational
export IDL_PRO_DIR                 # IDL polar2pr.bat needs this
IDL=/usr/local/bin/idl
DATA_DIR=/data/gpmgv
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_geo_matchup_dbtempfile

# re-used file listing all yymmdd to be processed this run
DATES2GRID=${TMP_DIR}/do_geo_matchup_todo.txt
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
     LOG_FILE=${LOG_DIR}/do_geo_matchup.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUNFILE=$1
THISRUN=`echo $THISRUNFILE | cut -f2 -d'.'`
LOG_FILE=${LOG_DIR}/do_geo_matchup.${THISRUN}.log
echo "Processing matchups for control file ${THISRUNFILE}" | tee $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match' AND datestamp = '${THISRUN}';" \
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
       ('geo_match', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# check whether we have prior control files/dates that didn't get processed
echo "" | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT datestamp FROM appstatus \
      WHERE app_id = 'geo_match' AND (status='$UNTRIED' OR status='$MISSING') \
      AND ntries < 5 AND datestamp != '${THISRUN}';" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
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
# ps -ef | grep "itt/idl" | grep lmgrd | grep -v grep > /dev/null 2>&1
# if [ $? = 1 ]
#   then
#     echo "FATAL: IDL license manager not running!" | tee -a $LOG_FILE
#     exit 1
# fi

# check that the to-be-called scripts are found
if [ ! -s ${IDL_PRO_DIR}/polar2pr_23.bat ]
  then
     echo "Script ${IDL_PRO_DIR}/polar2pr_23.bat not found, exiting" \
       | tee -a $LOG_FILE
     echo "with status 'UNTRIED', no data processed for ${THISRUN}." \
       | tee -a $LOG_FILE
     exit 1
fi

# check whether the IDL license is tied up by another user.  Sleep a few times
# until it comes free.  If we time out, then leave the input run date flagged
# as one to be re-run next time, and exit.

# ps -ef | grep "itt/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
# if [ $? = 1 ]
#   then
    idl_free='t'
#   else
#     idl_free='f'
# fi

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
    ps -ef | grep "itt/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
    if [ $? = 1 ]
      then
        idl_free='t'
    fi
done

for yymmdd in `cat $DATES2GRID`
  do
    CONTROLFILE=${DATA_DIR}/tmp/PR_files_sites4geoMatch.${yymmdd}.txt
    if [ -s $GETMYMETA ]
      then
        RUNDATE=$yymmdd
#	export RUNDATE              # IDL polar2pr.bat needs this
	export CONTROLFILE          # IDL polar2pr.bat needs this
	echo "" | tee -a $LOG_FILE
	echo "UPDATE appstatus SET ntries = ntries + 1 \
	      WHERE app_id = 'geo_match' AND datestamp = '$RUNDATE';" \
	 | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	echo "" | tee -a $LOG_FILE
	echo "=============================================" | tee -a $LOG_FILE
	echo "Calling IDL for yymmdd = ${RUNDATE}, file = $CONTROLFILE" \
	 | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
        
	$IDL < ${IDL_PRO_DIR}/polar2pr_23.bat | tee -a $LOG_FILE 2>&1
	
	echo "=============================================" | tee -a $LOG_FILE
	
	# check the IDL output in log file before declaring success, i.e., did
        # it produce any output matchup files for $yymmdd

        DBCATALOGFILE=${TMP_DIR}/do_geo_matchup_catalog.${yymmdd}.txt
        grep 'GRtoPR' $LOG_FILE | grep ${yymmdd} > $DBCATALOGFILE
        if [ -s $DBCATALOGFILE ]
          then
	    echo "UPDATE appstatus SET status = '$SUCCESS' \
	          WHERE app_id = 'geo_match' AND datestamp = '$RUNDATE';" \
	          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
          else
	    echo "UPDATE appstatus SET status = '$MISSING' \
	          WHERE app_id = 'geo_match' AND datestamp = '$RUNDATE';" \
	          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        fi
    fi
done

echo "" | tee -a $LOG_FILE
echo "do_geo_matchup.sh complete, exiting." | tee -a $LOG_FILE
exit 0
