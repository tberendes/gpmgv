#!/bin/sh

################################################################################
#
#  do_DPR2GR_geo_matchup4date_snow.sh    Morris/SAIC/GPM GV    March 2016
#
#
#  DESCRIPTION
#
#   Called by do_DPR2GR_GeoMatch.sh, which generates the needed configurations.
#   Runs IDL in batch mode to generate DPR matchups to previously-volume-matched
#   GR data in "GRtoDPR_HS_MS_NS" netCDF files, and writes them to netCDF
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
#   -r DO_RHI      - A command line option whose value must be 0 or 1, must be
#                    preceded by the "-r" option indicator, and must appear
#                    before the other two command line arguments.  If set to 1
#                    then the script will run matchups to RHI data by calling
#                    IDL with the TBD_RHI.bat batch file.  If set to 0 or not
#                    specified, the dpr2gr_prematch_snow.bat file will be invoked in
#                    IDL to run matchups to PPI scans.  THIS OPTION IS NOT YET
#                    SUPPORTED AS THERE CURRENTLY IS NO CAPABILITY FOR THE
#                    GR RHI MATCHUP TO MULTIPLE DPR SCAN TYPES AT ONCE.
#
#   YYMMDD - A single string listing the 2-digit year, month, and day of the
#            site overpasses for which matchups are to be generated.  No validity
#            checks are performed on the value of this date string, other than
#            that it must fit within the database field 'datestamp'.
#
#   CONTROLFILE - Fully qualified pathname of the IDL control file
#                 DPR_files_sites4geoMatch.TAG.txt.  See FILES, below.
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
#                              DPR 2A product algorithm (e.g. DPR or Ka), the
#                              DPR scan type to be used ("All" only), the PPS
#                              version of the 2A product (e.g., V03C), and the
#                              YYMMDD of the data listed in the control file.
#
#   dpr2gr_prematch_snow_V.bat (EXTERNAL)
#                            - Batch file of IDL commands to be run, where
#                              V is defined by the value of $PARAMETER_SET,
#                              e.g., dpr2gr_prematch_snow_1.bat.
#
#
#  DATABASE
#
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the app_id attribute value 'geo_match${kind}', where
#    the value 'kind' depends on the type of DPR 2A data being processed.
#
#
#  LOGS
#
#    Output for script run is logged to file do_DPR2GR_geo_matchup4date_snow.yymmdd.log
#    in the $LOG_DIR directory, where 'yymmdd' is the input data date,
#    unless improper number of arguments are passed. In this case the error is
#    logged to the current-date-tagged file do_DPR_geo_matchup.yymmdd.fatal.log
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
#    - Calling process must set and export GV_BASE_DIR, TMP_DIR, LOG_DIR
#
#  HISTORY
#    - 10/4/2016 - Replaced app_id prefix 'geo_match_' with 'geo_match' so that
#                  the longest app_id 'geo_matchDPRAll' fits within the 15
#                  character limit for the app_id column in the appstatus table.
#    - 2/15/2017 - Added logic to use PARAMETER_SET environment variable
#                  value to define the version of the dpr2gr_prematch_snow ".bat"
#                  file to be run by IDL.
#
################################################################################


#GV_BASE_DIR=/home/morris/swdev    # must be set & exported by calling process
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/geo_match
export IDL_PRO_DIR                 # IDL dpr2gr_prematch_snow.bat needs this
IDL=/usr/local/bin/idl
#TMP_DIR=/data/tmp   # must be set & exported by calling process
#LOG_DIR=/data/logs  # Ditto


umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_DPR_geo_matchup_dbtempfile

# Constants for possible status of processing, for appstatus table in database
UNTRIED='U'    # haven't attempted processing yet
SUCCESS='S'    # got IDL license and ran metadata extracts
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed in processing, make no more attempts

status=$UNTRIED   # assume we haven't yet tried to do current yymmdd

FORCE_MATCH=0    # if 1, ignore any appstatus for date(s) and (re)run matchups
DO_RHI=0         # if 0 use dpr2gr_prematch_snow.bat, if 1 use TBD_RHI.bat
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
     LOG_FILE=${LOG_DIR}/do_DPR2GR_geo_matchup4date_snow.${THISRUN}.fatal.log
     echo "FATAL: Exactly two non-option arguments required, $# given." | tee -a $LOG_FILE
     echo "Usage: do_DPR2GR_geo_matchup4date_snow.sh [-f[0|1]] YYMMDD CONTROLFILE"
     exit 1
fi

THISRUN=$1
CONTROLFILE=$2  # e.g., /data/tmp/DPR_files_sites4geoMatch.2AKu.NS.V03B.${THISRUN}.txt

LOG_FILE=${LOG_DIR}/do_DPR2GR_geo_matchup4date_snow.${THISRUN}.log

echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "Processing matchups for control file ${CONTROLFILE}" | tee $LOG_FILE
echo "" | tee -a $LOG_FILE

case "${FORCE_MATCH}"
  in
    0) echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE ;;
    1) echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE ;;
    *) echo "Invalid value ${FORCE_MATCH} for -f option in do_DPR2GR_geo_matchup4date_snow.sh."\
       | tee -a $LOG_FILE
       exit 1;;
esac
echo "" | tee -a $LOG_FILE

case "${DO_RHI}"
  in
    0) BATFILE=dpr2gr_prematch_snow_${PARAMETER_SET}.bat ;;
    *) echo "Invalid value ${DO_RHI} for -r option in do_DPR2GR_geo_matchup4date_snow.sh."\
       | tee -a $LOG_FILE
       exit 1;;
esac
echo "Will call IDL with $BATFILE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $CONTROLFILE ]
  then
    export CONTROLFILE          # IDL dpr2gr_prematch_snow.bat needs this
  else
    echo "ERROR in do_DPR2GR_geo_matchup4date_snow.sh, control file $CONTROLFILE not found."\
     | tee -a $LOG_FILE
    exit 1
fi

#exit

# figure out what kind of 2A radar matchup we are doing (instrument and swath)
# - Remove the "|" delimiter and append these values to one another for use in the
#   appstatus query to make it specific to the "flavor" of DPR data to be matched.
# FYI, 'kind' is formed by combining INSTRUMENT_ID with the string "|All" in the
# calling script, e.g., DPR|All, and we remove the "|" to make kind=DPRAll

kind=`head -1 $CONTROLFILE | cut -f 6-7 -d '|' | sed 's/|//'`

# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match${kind}' AND datestamp = '${THISRUN}';" \
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
       ('geo_match${kind}', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
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

echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries = ntries + 1 \
      WHERE app_id = 'geo_match${kind}' AND datestamp = '$THISRUN';" \
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
DBCATALOGFILE=${TMP_DIR}/do_DPR2GR_geo_matchup_catalog.${THISRUN}.txt

# identify any matching IDL output files and write their names to DBCATALOGFILE
grep '/GRtoDPR\.' $LOG_FILE | grep ${THISRUN} > $DBCATALOGFILE
#grep 'GRtoDPR' $LOG_FILE  > $DBCATALOGFILE  #TEMPORARY OVERRIDE FOR MANUAL CONTROL FILE WITH MULTIPLE DATES

if [ -s $DBCATALOGFILE -a "$FORCE_MATCH" = "0" ]
  then
    echo "UPDATE appstatus SET status = '$SUCCESS' \
    WHERE app_id = 'geo_match${kind}' AND datestamp = '$THISRUN';" \
    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
  else
    echo "UPDATE appstatus SET status = '$MISSING' \
    WHERE app_id = 'geo_match${kind}' AND datestamp = '$THISRUN';" \
    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
#    exit 1  # No, don't force parent script to quit if no success for this date
fi

echo "" | tee -a $LOG_FILE
echo "do_DPR2GR_geo_matchup4date_snow.sh complete, exiting." | tee -a $LOG_FILE
echo "See log file $LOG_FILE"
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit 0
