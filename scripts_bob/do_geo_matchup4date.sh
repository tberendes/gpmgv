#!/bin/sh

################################################################################
#
# do_geo_matchup4date.sh    Morris/SAIC/GPM GV    March 2011
#
# DESCRIPTION
#   Called by doGeoMatch4SelectCases.sh, which generates the needed inputs.
#   Runs IDL in batch mode to generate GV-PR matchups and write them to netCDF
#   files, for radar sites that are overpassed in each orbit for a specified
#   date (UTC) and have precipitation echoes.  Files, orbits, and overpassed
#   radar sites are listed in the well-known filename whose YYMMDD date part
#   is provided as the single argument to this script.  This filename is set
#   as an environment variable so that IDL can extract the filename from the
#   environment.  The script tracks the status of data processing for the date
#   YYMMDD via entries in the 'appstatus' table in the 'gpmgv' database, and
#   takes appropriate actions according to the status of the date's run.
#
#   This script has a sleep/retry feature in case the IDL single-user license
#   is occupied by another user/process.  It will sleep 30 minutes between
#   attempts.  After 8 times hitting the Snooze button, it will give up and
#   flag the timed-out run to be reattempted the next time this script is run.
#
# ARGUMENTS
#   YYMMDD - A single string listing the 2-digit year, month, and day of the
#            site overpasses for which matchups are to be generated.  No validity
#            checks are performed on the value of this date string, other than
#            that it must fit within the database field 'datestamp'.
#
# FILES
#   PR_files_sites4geoMatch.YYMMDD.txt (INPUT) - lists data files, orbits, and
#                                      NEXRAD sites overpassed in each orbit. 
#                                      YYMMDD is passed to this script as the
#                                      sole argument.  YYMMDD is the yr, month,
#                                      day of the run, not necessarily of the
#                                      data.  The full file pathname is
#                                      generated within this script.
#   polar2pr.bat                       (INTERNAL) - Batch file of IDL commands to be run.
#
#  DATABASE
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the app_id attribute value 'gridPRandGV'.
#
#  LOGS
#    Output for script run is logged to file do_geo_matchup4date.yymmdd.log
#    in the $LOG_DIR directory, where 'yymmdd' is the input data date,
#    unless improper number of arguments are passed.
#    In this case the error is written to a current-date-specific log file
#    do_geo_matchup.yymmdd.fatal.log in $LOG_DIR, where 'yymmdd' is for the
#    date the script run was attempted, not the input data date.
#
#  RETURN VALUES
#    0 = normal, successfully created new matchup files
#    1 = error in processing or no input data; no matchup files created
#    2 = already successfully ran matchups for this date, do nothing
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and SELECT, UPDATE, INSERT privileges on tables. 
#      Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $TMP_DIR, $LOG_DIR directories
#
################################################################################


#GV_BASE_DIR=/home/morris/swdev       # exported by calling script
BIN_DIR=${GV_BASE_DIR}/scripts
USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/geo_match
  else
    if [ "$USER_ID" = "gvoper" ]
      then
        IDL_PRO_DIR=${GV_BASE_DIR}/idl
      else
        echo "User unknown, can't set IDL_PRO_DIR!"
        exit 1
    fi
fi
export IDL_PRO_DIR                    # IDL polar2pr.bat needs this
IDL=/usr/local/bin/idl
#DATA_DIR=/data/gpmgv                 # exported by calling script
#TMP_DIR=${DATA_DIR}/tmp              # exported by calling script
#LOG_DIR=${DATA_DIR}/logs             # exported by calling script
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_geo_matchup_dbtempfile

# re-used file listing all yymmdd to be processed this run
#DATES2GRID=${TMP_DIR}/do_geo_matchup_todo.txt
#rm -f $DATES2GRID $DBTEMPFILE

# Constants for possible status of processing, for appstatus table in database
UNTRIED='U'    # haven't attempted processing yet
SUCCESS='S'    # got IDL license and ran metadata extracts
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed in processing, make no more attempts

#have_retries='f'  # indicates whether we have missing prior filedates to retry
status=$UNTRIED   # assume we haven't yet tried to do current yymmdd

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${LOG_DIR}/do_geo_matchup4date.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUNFILE=$1
THISRUN=`echo $THISRUNFILE | cut -f2 -d'.'`
LOG_FILE=${LOG_DIR}/do_geo_matchup4date.${THISRUN}.log
echo "Processing matchups for control file ${THISRUNFILE}" | tee $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match_PR' AND datestamp = '${THISRUN}';" \
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
       ('geo_match_PR', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# add this run's yymmdd to to-do list, if not already processed successfully
# or if this yymmdd didn't exit fatally in last attempt
case $status in
  $SUCCESS )
    echo "Status indicates yymmdd = ${THISRUN} already successfully processed."\
     | tee -a $LOG_FILE
    exit 2
  ;;
  $FAILED )
    echo "Status indicates yymmdd = ${THISRUN} had prior fatals, skipping."\
     | tee -a $LOG_FILE
    exit 1
  ;;
  * )
    echo "Attempting matchups for yymmdd = ${THISRUN}" | tee -a $LOG_FILE
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
if [ ! -s ${IDL_PRO_DIR}/polar2pr.bat ]
  then
     echo "Script ${IDL_PRO_DIR}/polar2pr.bat not found, exiting" \
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

CONTROLFILE=${TMP_DIR}/PR_files_sites4geoMatch.${THISRUN}.txt
if [ -s $CONTROLFILE ]
  then
    #export THISRUN              # IDL polar2pr.bat needs this
    export CONTROLFILE          # IDL polar2pr.bat needs this
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET ntries = ntries + 1 \
          WHERE app_id = 'geo_match_PR' AND datestamp = '$THISRUN';" \
         | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE
    echo "=============================================" | tee -a $LOG_FILE
    echo "Calling IDL for yymmdd = ${THISRUN}, file = $CONTROLFILE" \
     | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
       
    $IDL < ${IDL_PRO_DIR}/polar2pr.bat | tee -a $LOG_FILE 2>&1

    echo "=============================================" | tee -a $LOG_FILE

   # check the IDL output in log file before declaring success, i.e., did
   # it produce any output matchup files for $THISRUN -- The following file
   # must be identically defined here and in doGeoMatch4NewRainCases.sh

    DBCATALOGFILE=${TMP_DIR}/do_geo_matchup_catalog.${THISRUN}.txt
    grep 'GRtoPR' $LOG_FILE | grep ${THISRUN} > $DBCATALOGFILE
    if [ -s $DBCATALOGFILE ]
      then
	echo "UPDATE appstatus SET status = '$SUCCESS' \
	      WHERE app_id = 'geo_match_PR' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
      else
	echo "UPDATE appstatus SET status = '$MISSING' \
	      WHERE app_id = 'geo_match_PR' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        #exit 1
    fi
  else
    echo "ERROR in do_geo_matchup4date.sh, control file $CONTROLFILE not found."
    exit 1
fi

echo "" | tee -a $LOG_FILE
echo "do_geo_matchup4date.sh complete, exiting." | tee -a $LOG_FILE
echo "See log file $LOG_FILE"
exit 0
