#!/bin/sh

################################################################################
#
#  do_GMI_geo_matchup4date.sh    Morris/SAIC/GPM GV    May 2011
#
#
#  DESCRIPTION
#
#   Called by do_GMI_GeoMatch.sh, which generates the needed inputs.
#   Runs IDL in batch mode to generate GV-GMI matchups and write them to netCDF
#   files, for radar sites that are overpassed in each orbit for a specified
#   date (UTC) and have precipitation echoes.  Files, orbits, and overpassed
#   radar sites are listed in the well-known filename of the control file whose
#   YYMMDD date stamp is specified as the single argument to this script.
#   The control file's complete pathname is built and exported by this script
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
#
#  SYNOPSIS
#
#   do_GMI_geo_matchup4date.sh  CONTROLFILE
#
#
#  ARGUMENTS
#
#   YYMMDD - Mandatory argument, datestamp of the fully qualified pathname of
#            the IDL control file GMI_files_sites4geoMatch.YYMMDD.txt, where
#            YYMMDD varies as described below.  The full pathname to the control
#            file is formatted by this script using the same rules as in the
#            calling script, do_GMI_GeoMatch.sh.
#
#
#  ENVIRONMENT VARIABLES
#
#   The following environment variables must be set and exported by the caller
#   so that they are defined and available to this script:
#
#   GV_BASE_DIR - Partial top-level path to IDL batch file to be run.
#       TMP_DIR - Path to temporary files used in this and the calling script.
#       LOG_DIR - Path to log files used in this and the calling script.
#
#
#  FILES
#
#   GMI_files_sites4geoMatch.YYMMDD.txt (INPUT)
#                            - lists data files, orbits, ground radar sites, and
#                              required metadata for ground radars overpassed in
#                              the rainy orbits on date YYMMDD, in the format
#                              required by the IDL polar2gmi procedure.
#                            - This script only checks for the existence of the
#                              file and passes its pathname to IDL via setting
#                              the environment variable CONTROLFILE.
#
#   polar2gmi.bat (EXTERNAL) - Batch file of IDL commands to be run.
#
#
#  DATABASE
#
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the app_id attribute value 'geo_match_gmi'.
#
#
#  LOGS
#
#    Output for script run is logged to file do_GMI_geo_matchup4date.yymmdd.log
#    in the $LOG_DIR directory, where 'yymmdd' is the input data date,
#    unless improper number of arguments are passed. In this case the error is
#    logged to the current-date-tagged file do_GMI_geo_matchup.yymmdd.fatal.log
#    in $LOG_DIR, where 'yymmdd' is for the date the script run was attempted,
#    not the input data date.
#
#
#  RETURN VALUES
#
#    0 = normal, successfully created new matchup files
#    1 = error in processing or no input data; no matchup files created
#    2 = already successfully ran matchups for this date, do nothing
#
#
#  CONSTRAINTS
#
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and SELECT, UPDATE, INSERT privileges on tables. 
#      Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $TMP_DIR, $LOG_DIR directories
#
#  HISTORY
#
#  07/17/17  Morris     - Modified to take YYMMDD as the single argument in
#                         place of the full pathname of the control file.
#
################################################################################


#GV_BASE_DIR=/home/morris/swdev   # set/exported by caller, change for operational
BIN_DIR=${GV_BASE_DIR}/scripts/matchup
#IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/geo_match  # change for operational
IDL_PRO_DIR=${GV_BASE_DIR}/idl/geo_match  # change for operational
export IDL_PRO_DIR                 # IDL polar2gmi.bat needs this
IDL=/usr/local/bin/idl
#DATA_DIR=/data/gpmgv
#TMP_DIR=${DATA_DIR}/tmp   # must be set & exported by calling process
#LOG_DIR=${DATA_DIR}/logs  # Ditto
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_GMI_geo_matchup_dbtempfile

# re-used file listing all yymmdd to be processed this run
#DATES2GRID=${TMP_DIR}/do_GMI_geo_matchup_todo.txt
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
     LOG_FILE=${LOG_DIR}/do_GMI_geo_matchup4date.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
THISRUNFILE=${TMP_DIR}/GMI_files_sites4geoMatch.${THISRUN}.txt
LOG_FILE=${LOG_DIR}/do_GMI_geo_matchup4date.${THISRUN}.log
echo "Processing matchups for control file ${THISRUNFILE}" | tee $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match_gmi' AND datestamp = '${THISRUN}';" \
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
       ('geo_match_gmi', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# add this run's yymmdd to to-do list, if not already processed successfully
# or if this yymmdd didn't exit fatally in last attempt
case $status in
  $SUCCESS )
    echo "Status indicates yymmdd = ${THISRUN} already successfully processed."\
     | tee -a $LOG_FILE
#  TAB 2/5/20 remove exit to allow reprocessing of previous days
#    exit 2
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
if [ ! -s ${IDL_PRO_DIR}/polar2gmi.bat ]
  then
     echo "" | tee -a $LOG_FILE
     echo "FATAL: Script ${IDL_PRO_DIR}/polar2gmi.bat not found, " \
       | tee -a $LOG_FILE
     echo "exiting with appstatus value = 'UNTRIED' for datestamp ${THISRUN}." \
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

CONTROLFILE=${TMP_DIR}/GMI_files_sites4geoMatch.${THISRUN}.txt
if [ -s $CONTROLFILE ]
  then
    #export THISRUN              # IDL polar2gmi.bat needs this
    export CONTROLFILE          # IDL polar2gmi.bat needs this
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET ntries = ntries + 1 \
          WHERE app_id = 'geo_match_gmi' AND datestamp = '$THISRUN';" \
         | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE
    echo "=============================================" | tee -a $LOG_FILE
    echo "Calling IDL for yymmdd = ${THISRUN}, file = $CONTROLFILE" \
     | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
       
    $IDL < ${IDL_PRO_DIR}/polar2gmi.bat | tee -a $LOG_FILE 2>&1

    echo "=============================================" | tee -a $LOG_FILE

   # check the IDL output in log file before declaring success, i.e., did
   # it produce any output matchup files for $THISRUN -- The following file
   # must be identically defined here and in doGeoMatch4NewRainCases.sh

    DBCATALOGFILE=${TMP_DIR}/do_GMI_geo_matchup_catalog.${THISRUN}.txt
    grep 'GRtoGPROF' $LOG_FILE | grep ${THISRUN} > $DBCATALOGFILE
    if [ -s $DBCATALOGFILE ]
      then
	echo "UPDATE appstatus SET status = '$SUCCESS' \
	      WHERE app_id = 'geo_match_gmi' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
      else
	echo "UPDATE appstatus SET status = '$MISSING' \
	      WHERE app_id = 'geo_match_gmi' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
#        exit 1
    fi
  else
    echo "ERROR in do_GMI_geo_matchup4date.sh, control file $CONTROLFILE not found."
    exit 1
fi

echo "" | tee -a $LOG_FILE
echo "do_GMI_geo_matchup4date.sh complete, exiting." | tee -a $LOG_FILE
exit 0
