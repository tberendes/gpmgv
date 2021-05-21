#!/bin/sh

################################################################################
#
#  do_GR_HS_FS_geo_matchup4date_v7.sh    Morris/SAIC/GPM GV    April 2014
#
#
#  DESCRIPTION
#
#   Called by do_GR_HS_FS_GeoMatch_v7.sh, which generates the needed inputs.
#   Runs IDL in batch mode to generate GV-DPR matchups and write them to netCDF
#   files, for radar sites that are overpassed in each orbit for a specified
#   date (UTC) and have precipitation echoes.  Files, orbits, and overpassed
#   radar sites are listed in the provided filename whose YYMMDD date stamp
#   is provided as the first argument to this script.  The filename is set
#   as an environment variable so that IDL can extract the filename from the
#   environment.  The script tracks the status of data processing for the date
#   YYMMDD for each particular "kind" or matchup (algorithm/swath/version) via
#   entries in the 'appstatus' table in the 'gpmgv' database, and takes
#   appropriate actions according to the status of the date/kind's run.  The
#   "-f" option can override this status checking and force the matchup to be
#   run if set to the value 1.
#
#   This script has a sleep/retry feature in case the IDL single-user license
#   is occupied by another user/process.  It will sleep 30 minutes between
#   attempts.  After 8 times hitting the Snooze button, it will give up and
#   flag the timed-out run to be reattempted the next time this script is run.
#
#
#  ARGUMENTS
#
#   -f FORCE_MATCH - A command line option whose value must be 0 or 1, must be
#                    preceded by the "-f" option indicator, and must appear
#                    before the other two command line arguments.  If set to 1
#                    then the matchups for the specified YYMMDD and control file
#                    are (re)processed regardless of the existing "appstatus"
#                    for the YYMMDD datestamp, i.e., a matchup is "forced" to be
#                    run.  If set to 0 or not specified, then the legacy behavior
#                    of checking appstatus against the YYMMDD, instrument, and
#                    swath combination before proceeding is used.  Default=0
#
#  NOTE: RHI is not implemented yet in this program, was never ported to hs_ms_ns 
#   -r DO_RHI      - A command line option whose value must be 0 or 1, must be
#                    preceded by the "-r" option indicator, and must appear
#                    before the other two command line arguments.  If set to 1
#                    then the script will run matchups to RHI data by calling
#                    IDL with the rhi2dpr_hs_ms_ns.bat batch file.  If set to 0
#                    or not specified, then the polar2dpr_hs_ms_ns.bat file will
#                    be invoked in IDL to run matchups to PPI scans.
#
#   YYMMDD - A single string listing the 2-digit year, month, and day of the
#            site overpasses for which matchups are to be generated.  No validity
#            checks are performed on the value of this date string, other than
#            that it must fit within the database field 'datestamp'.
#
#   CONTROLFILE - Fully qualified pathname of the IDL control file
#                 DPR_files_sites4geoMatch.TAG.txt
#
#
#  ENVIRONMENT VARIABLES
#
#   The following environment variables must be set and exported by the caller
#   so that they are defined and available to this script:
#
#   GV_BASE_DIR - Partial top-level path to IDL batch file to be run.
# PARAMETER_SET - Version of the IDL batch file to be run.
#       TMP_DIR - Path to temporary files used in this and the calling script.
#       LOG_DIR - Path to log files used in this and the calling script.
#
#
#  FILES
#
#   DPR_files_sites4geoMatch.TAG.txt (INPUT)
#                            - lists data files, orbits, and NEXRAD sites
#                              overpassed in each orbit on date YYMMDD.  TAG is
#                              a combination of parameters that indicate the 
#                              DPR 2A product algorithm ('DPR' only, herein), the
#                              DPR scan type to be used ('All3', herein), the PPS
#                              version of the 2A product (e.g., 'V03C'), and the
#                              YYMMDD of the data listed in the control file.
#
#   polar2dpr_hs_fs_V.bat or rhi2dpr_hs_ms_ns_V.bat (EXTERNAL)
#                            - Batch file of IDL commands to be run, where
#                              V is defined by the value of $PARAMETER_SET,
#                              e.g., polar2dpr_hs_ms_ns_1.bat.  RHI is a
#                              future option not yet implemented.
#
#
#  DATABASE
#
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the fixed app_id attribute value 'geo_match_GRx3' and
#    a datestamp having the value of $YYMMDD.
#
#
#
#  LOGS
#
#    Output for script run is logged to file:
#
#           do_GR_HS_FS_geo_matchup4date_v7.yymmdd.log
#
#    in the $LOG_DIR directory, where 'yymmdd' is the input data date,
#    unless an improper number of arguments are passed. In this case the error
#    is logged to the current-date-tagged file:
#
#           do_GR_HS_FS_geo_matchup.yymmdd.fatal.log
#
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
#    - Calling process must set and export GV_BASE_DIR, TMP_DIR, LOG_DIR, and
#      PARAMETER_SET
#
#
#  HISTORY
#
#  2/15/2017   Morris     Added logic to use PARAMETER_SET environment variable
#                         value to define the version of the polar2dpr_hs_fs
#                         ".bat" file to be run by IDL.
#  1/24/20:    Berendes   FORCE_MATCH default set to "1" and removed FORCE_MATCH
#                         clause from final check that causes DB field to be 
#                         set to "missing" if FORCE_MATCH is used.  I belive this
#                         is a pre-existing bug, and the date check is unnecessary 
#                         in our current processing scheme since the parent script
#                         checks for duplicates on each processing date and doesn't 
#                         add duplicates to the control file unless -f is used
#                         in parent script.
#
################################################################################


#GV_BASE_DIR=/home/morris/swdev    # must be set & exported by calling process
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl
export IDL_PRO_DIR                 # IDL polar2dpr_hs_fs.bat needs this
IDL=/usr/local/bin/idl
#TMP_DIR=/data/tmp   # must be set & exported by calling process
#LOG_DIR=/data/logs  # Ditto

ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_GR_HS_FS_geo_matchup_dbtempfile

# Constants for possible status of processing, for appstatus table in database
UNTRIED='U'    # haven't attempted processing yet
SUCCESS='S'    # got IDL license and ran metadata extracts
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed in processing, make no more attempts

status=$UNTRIED   # assume we haven't yet tried to do current yymmdd

FORCE_MATCH=1    # if 1, ignore any appstatus for date(s) and (re)run matchups
DO_RHI=0         # if 0 use polar2dpr_hs_ms_ns.bat, if 1 use rhi2dpr_hs_ms_ns.bat (TBD)
echo ""

# override coded default with user-specified value, if given
while getopts f:r: option
  do
    case "${option}"
      in
        f) FORCE_MATCH=${OPTARG};;
        r) DO_RHI=${OPTARG};;
    esac
done
shift $((OPTIND-1))  # shift the non-option arguments to beginning of list

if [ $# != 2 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${LOG_DIR}/do_GR_HS_FS_geo_matchup4date_v7.${THISRUN}.fatal.log
     echo "FATAL: Exactly two non-option arguments required, $# given." | tee -a $LOG_FILE
     echo "Usage: do_GR_HS_FS_geo_matchup4date_v7.sh [-f[0|1]] YYMMDD CONTROLFILE"
     exit 1
fi

THISRUN=$1
CONTROLFILE=$2  # e.g., /data/tmp/DPR_files_sites4geoMatch.2AKu.NS.V03B.${THISRUN}.txt

LOG_FILE=${LOG_DIR}/do_GR_HS_FS_geo_matchup4date_v7.${THISRUN}.log

echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "Processing matchups for control file ${CONTROLFILE}" | tee $LOG_FILE
echo "" | tee -a $LOG_FILE

case "${FORCE_MATCH}"
  in
    0) echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE ;;
    1) echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE ;;
    *) echo "Invalid value ${FORCE_MATCH} for -f option in do_GR_HS_FS_geo_matchup4date_v7.sh."\
       | tee -a $LOG_FILE
       exit 1;;
esac
echo "" | tee -a $LOG_FILE

# We now use the PARAMETER_SET variable exported by the calling script to
# determine which version of the polar2dpr or rhi2dpr batch file to use
case "${DO_RHI}"
  in
    0) BATFILE=polar2dpr_hs_fs_v7_${PARAMETER_SET}.bat ;;
    1) BATFILE=rhi2dpr_hs_ms_ns_${PARAMETER_SET}.bat ;;
    *) echo "Invalid value ${DO_RHI} for -r option in do_GR_HS_FS_geo_matchup4date_v7.sh."\
       | tee -a $LOG_FILE
       exit 1;;
esac
echo "Will call IDL with $BATFILE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $CONTROLFILE ]
  then
    export CONTROLFILE          # IDL polar2dpr_hs_fs_V.bat needs this
  else
    echo "ERROR in do_GR_HS_FS_geo_matchup4date_v7.sh, control file $CONTROLFILE not found."\
     | tee -a $LOG_FILE
    exit 1
fi

#exit


# figure out what kind of 2A radar matchup we are doing (instrument and swath)
# - append these values to one another for use in diagnostic messages to make
#   it specific to the "flavor" of DPR data to be matched up
# - Note that appstatus table entries for this script use the fixed app_id value
#   'geo_match_GRx3', not something based on $kind.

kind=`head -1 $CONTROLFILE | cut -f 6-7 -d '|' | sed 's/|//'`

# this is doesn't work since char length of status column is 15, an not long enough to append to 
# create suffix for appstatus type to account for parameter, PPS version, and geo_match version
#gver=`echo $GEO_MATCH_VERSION | sed 's/\./_/'`
# use $PARAMETER_SET, $PPS_VERSION
#kindstr=$PARAMETER_SET'_'$PPS_VERSION'_'$gver
# append kindstr to app_id
# changing app id from geo_match_GRx3 to GM_GRx3 to shorten it to keep appended 
# length < 15 char for database field length

# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database

# TODO would need to increase size of table column for this to work
# WHERE app_id = 'GM_GRx3_${kindstr}' AND datestamp = '${THISRUN}';" \

# WHERE app_id = 'geo_match_GRx3' AND datestamp = '${THISRUN}';" \
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match_GRx3' AND datestamp = '${THISRUN}';" \
  | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1

if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to do this kind's yymmdd before, get our past status.
     status=`cat ${DBTEMPFILE}`
     echo "Rundate ${THISRUN} for ${kind} has been attempted before with status = $status" \
     | tee -a $LOG_FILE
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus (app_id, datestamp, status) VALUES \
       ('geo_match_GRx3', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# set up to do this "kind" of run's yymmdd if not already processed successfully
# or if this yymmdd didn't exit fatally in last attempt
case $status in
  $SUCCESS )
    echo "Status indicates yymmdd = ${THISRUN} for ${kind} already successfully processed."\
     | tee -a $LOG_FILE
    if [ "$FORCE_MATCH" = "0" ]
      then
        echo "Exiting script." | tee -a $LOG_FILE
        exit 2
      else
        echo "Overriding status, reprocessing ${kind} for date." | tee -a $LOG_FILE
    fi
  ;;
  $FAILED )
    echo "Status indicates yymmdd = ${THISRUN} for ${kind} had prior fatals, skipping."\
     | tee -a $LOG_FILE
    exit 1
  ;;
  * )
    echo "Attempting ${kind} matchups for yymmdd = ${THISRUN}" | tee -a $LOG_FILE
  ;;
esac

# check whether the IDL license manager is running. If not, we are done for,
# and will have to exit and leave the input run date flagged as one to be
# re-run next time.  N/A TO CURRENT MULTI-USER/MULTI-HOST LICENSE SITUATION.

# ps -ef | grep "itt/idl" | grep lmgrd | grep -v grep > /dev/null 2>&1
# if [ $? = 1 ]
#   then
#     echo "FATAL: IDL license manager not running!" | tee -a $LOG_FILE
#     exit 1
# fi

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

# check whether the IDL license is tied up by another user.  Sleep a few times
# until it comes free.  If we time out, then leave the input run date flagged
# as one to be re-run next time, and exit. 
# DOES NOT APPLY TO MULTI-USER/MULTI-HOST LICENSE SITUATION.

# ps -ef | grep "itt/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
# if [ $? = 1 ]
#   then
    idl_free='t'   # SET TO "t" BY DEFAULT FOR OUR LICENSE TYPE
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

echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries = ntries + 1 \
      WHERE app_id = 'geo_match_GRx3' AND datestamp = '$THISRUN';" \
     | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

echo "=============================================" | >> $LOG_FILE

    echo "Calling IDL for yymmdd = ${THISRUN}, file = $CONTROLFILE" \
     | tee -a $LOG_FILE
    echo "using batch file ${IDL_PRO_DIR}/${BATFILE}" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    $IDL < ${IDL_PRO_DIR}/${BATFILE} | tee -a $LOG_FILE 2>&1

echo "=============================================" | >> $LOG_FILE
echo ""

# check the IDL output in log file before declaring success, i.e., did
# it produce any output matchup files for $THISRUN -- The following file
# must be identically defined here and in doGeoMatch4NewRainCases.sh

DBCATALOGFILE=${TMP_DIR}/do_GR_HS_FS_geo_matchup_catalog.${THISRUN}.txt
grep 'GRtoDPR' $LOG_FILE | grep ${THISRUN} > $DBCATALOGFILE
#grep 'GRtoDPR' $LOG_FILE  > $DBCATALOGFILE  #TEMPORARY OVERRIDE FOR MANUAL CONTROL FILE WITH MULTIPLE DATES

# prior behavior caused "MISSING" status whenever FORCE_MATCH = 1
#if [ -s $DBCATALOGFILE -a "$FORCE_MATCH" = "0" ]
if [ -s $DBCATALOGFILE ]
  then
    echo "UPDATE appstatus SET status = '$SUCCESS' \
    WHERE app_id = 'geo_match_GRx3' AND datestamp = '$THISRUN';" \
    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
  else
    echo "UPDATE appstatus SET status = '$MISSING' \
    WHERE app_id = 'geo_match_GRx3' AND datestamp = '$THISRUN';" \
    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
#    exit 1  # No, don't force parent script to quit if no success for this date
fi

echo "" | tee -a $LOG_FILE
echo "do_GR_HS_FS_geo_matchup4date_v7.sh complete, exiting." | tee -a $LOG_FILE
echo "See log file $LOG_FILE"
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit 0
