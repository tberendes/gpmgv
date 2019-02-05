#!/bin/sh

################################################################################
#
#  do_DPRGMI_geo_matchup4date_snow.sh    Morris/SAIC/GPM GV    April 2014
#
#
#  DESCRIPTION
#
#   Called by do_DPRGMI_GeoMatch4RainDates.sh, which generates the needed inputs.
#   Runs IDL in batch mode to generate GV-DPRGMI matchups and write them to netCDF
#   files, for radar sites that are overpassed in each orbit for a specified
#   date (UTC) and have precipitation echoes.  Files, orbits, and overpassed
#   radar sites are listed in the well-known filename whose YYMMDD date stamp
#   is provided as the single argument to this script.  This filename is set
#   as an environment variable so that IDL can extract the filename from the
#   environment.  The script tracks the status of data processing for the date
#   YYMMDD via entries in the 'appstatus' table in the 'gpmgv' database, and
#   takes appropriate actions according to the status of the date's run.
#
#
#  SYNOPSIS
#
#   do_DPRGMI_geo_matchup4date.sh  YYMMDD
#
#
#  ARGUMENTS
#
#   YYMMDD   - Mandatory argument, a single string listing the 2-digit year,
#              month, and day of the site overpasses for which matchups are
#              to be generated.  No validity checks are performed on the
#              value of this date string, other than that it must fit
#              within the database field 'datestamp'.
#
#
#  ENVIRONMENT VARIABLES
#
#   The following environment variables must be set and exported by the caller
#   so that they are defined and available to this script:
#
#   GV_BASE_DIR - Partial top-level path to IDL batch file to be run.
# PARAMETER_SET - Version of the IDL batch file to be run.
#       CTL_DIR - Path to COMB_files_sites4geoMatch.YYMMDD.txt control files.
#       TMP_DIR - Path to temporary files used in this and the calling script.
#       LOG_DIR - Path to log files used in this and the calling script.
#
#
#  FILES
#
#   COMB_files_sites4geoMatch.YYMMDD.txt (INPUT)
#                            - lists data files, orbits, and NEXRAD sites
#                              overpassed in each orbit.  YYMMDD is passed
#                              to this script as the sole argument. YYMMDD 
#                              is the year, month, day of the run, not
#                              necessarily of the data.  The full file
#                              pathname is generated within this script.
#                            - This script only checks for the existence of the
#                              file and passes its pathname to IDL via setting
#                              the environment variable CONTROLFILE.
#
#   polar2dprgmi_snow_V.bat (EXTERNAL) - Batch file of IDL commands to be run, where
#                                   V is defined by the value of $PARAMETER_SET,
#                                   e.g., polar2dprgmi_snow_1.bat.
#
#
#  DATABASE
#
#    Status of this script's runs are maintained in the 'appstatus' table,
#    in rows tagged with the app_id attribute value 'geo_match_COMB'.
#
#
#  LOGS
#
#    Output for script run is logged to file do_DPRGMI_geo_matchup4date.yymmdd.log
#    in the $LOG_DIR directory, where 'yymmdd' is the input data date,
#    unless improper number of arguments are passed. In this case the error is
#    logged to the current-date-tagged file do_DPRGMI_geo_matchup.yymmdd.fatal.log
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
#  7/12/2016   Morris     Changed location of control files to CTL_DIR from
#                         TMP_DIR.
#  2/15/2017   Morris   - Added logic to use PARAMETER_SET environment variable
#                         value to define the version of the polar2dprgmi_snow ".bat"
#                         file to be run by IDL.
#                       - Changed IDL_PRO_DIR to ${GV_BASE_DIR}/idl/geo_match
#                         for user gvoper.
#  2/4/2019   Morris    - modified to create new snow water equivalent fields
#
################################################################################


#GV_BASE_DIR=/home/morris/swdev   # set/exported by caller
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl/geo_match  #changed for operational (user gvoper)
export IDL_PRO_DIR                # IDL polar2dprgmi_snow_V.bat needs this
IDL=/usr/local/bin/idl
#DATA_DIR=/data/gpmgv
#TMP_DIR=${DATA_DIR}/tmp   # must be set & exported by calling process
#LOG_DIR=${DATA_DIR}/logs  # Ditto

umask 0002

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/do_DPRGMI_geo_matchup_dbtempfile

# re-used file listing all yymmdd to be processed this run
#DATES2GRID=${TMP_DIR}/do_DPRGMI_geo_matchup_todo.txt
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
     LOG_FILE=${LOG_DIR}/do_DPRGMI_geo_matchup4date_snow.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
CONTROLFILE=${CTL_DIR}/COMB_files_sites4geoMatch_snow.${THISRUN}.txt
THISRUN=`echo $CONTROLFILE | cut -f2 -d'.'`
LOG_FILE=${LOG_DIR}/do_DPRGMI_geo_matchup4date_snow.${THISRUN}.log
echo "Processing matchups for control file ${CONTROLFILE}" | tee $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $CONTROLFILE ]
  then
    #export THISRUN              # IDL polar2dprgmi_snow.bat needs this
    export CONTROLFILE          # IDL polar2dprgmi_snow.bat needs this
  else
    echo "ERROR in do_DPRGMI_geo_matchup4date_snow.sh, control file $CONTROLFILE not found."\
     | tee -a $LOG_FILE
    exit 1
fi

# figure out what kind of 2A radar matchup we are doing (instrument and swath)
#kind=`head -1 $CONTROLFILE | cut -f 6-7 -d '|' | sed 's/|//'`
kind=COMB   # hard-coded for DPRGMI matchups

# initialize the appstatus table entry for this run's yymmdd, first
# checking whether we already have an entry for this yymmdd in database
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'geo_match_${kind}' AND datestamp = '${THISRUN}';" \
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
       ('geo_match_${kind}', '${THISRUN}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# add this run's yymmdd to to-do list, if not already processed successfully
# or if this yymmdd didn't exit fatally in last attempt
case $status in
  $SUCCESS )
    echo "Status indicates yymmdd = ${THISRUN} already successfully processed."\
     | tee -a $LOG_FILE
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

# check that the to-be-called scripts are found.  We now use the PARAMETER_SET
# variable exported by the calling script to determine which version of the
# polar2dprgmi_snow batch file to use
if [ ! -s ${IDL_PRO_DIR}/polar2dprgmi_snow_${PARAMETER_SET}.bat ]
  then
     echo "" | tee -a $LOG_FILE
     echo "FATAL: Script ${IDL_PRO_DIR}/polar2dprgmi_snow_${PARAMETER_SET}.bat not found, " \
       | tee -a $LOG_FILE
     echo "exiting with appstatus value = 'UNTRIED' for datestamp ${THISRUN}." \
       | tee -a $LOG_FILE
     exit 1
fi

if [ -s $CONTROLFILE ]   # legacy if check, moved error logic to top of script
  then
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET ntries = ntries + 1 \
          WHERE app_id = 'geo_match_${kind}' AND datestamp = '$THISRUN';" \
         | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE
    echo "=============================================" | tee -a $LOG_FILE
    echo "Calling IDL for yymmdd = ${THISRUN}, file = $CONTROLFILE" \
     | tee -a $LOG_FILE
    echo "using batch file ${IDL_PRO_DIR}/polar2dprgmi_snow_${PARAMETER_SET}.bat" \
     | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
       
    $IDL < ${IDL_PRO_DIR}/polar2dprgmi_snow_${PARAMETER_SET}.bat | tee -a $LOG_FILE 2>&1

    echo "=============================================" | tee -a $LOG_FILE

   # check the IDL output in log file before declaring success, i.e., did
   # it produce any output matchup files for $THISRUN -- The following file
   # must be identically defined here and in do_DPRGMI_GeoMatch.sh and
   # do_DPRGMI_GeoMatch_from_ControlFiles.sh

    DBCATALOGFILE=${TMP_DIR}/do_DPRGMI_geo_matchup_catalog_snow.${THISRUN}.txt
    grep 'GRtoDPR' $LOG_FILE | grep ${THISRUN} > $DBCATALOGFILE
    if [ -s $DBCATALOGFILE ]
      then
	echo "UPDATE appstatus SET status = '$SUCCESS' \
	      WHERE app_id = 'geo_match_${kind}' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
      else
	echo "UPDATE appstatus SET status = '$MISSING' \
	      WHERE app_id = 'geo_match_${kind}' AND datestamp = '$THISRUN';" \
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
#        exit 1
    fi
fi

echo "" | tee -a $LOG_FILE
echo "do_DPRGMI_geo_matchup4date_snow.sh complete, exiting." | tee -a $LOG_FILE
exit 0
