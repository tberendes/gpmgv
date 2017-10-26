#!/bin/sh
###############################################################################
#
# update_gvradar_sweeps.sh    Morris/SAIC/GPM GV    February 2011
#
# Identifies new 1CUF files that have been cataloged but not yet processed to
# extract and store the set of sweep elevation angles present in the radar
# volume scan in the file.  A database query identifies the files to be
# processed and creates a control file listing the 1CUF files to process.
# Calls the IDL procedure catalog_1cuf_sweeps.pro to do the legwork of
# reading and processing the 1CUF files and storing the elevation angles sets
# in the database with a link to the 1CUF data file.
#
# 2/18/2011   Morris    Created.
# 8/26/2014   Morris    Changed LOG_DIR to /data/logs
#
###############################################################################


GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
LOG_DIR=/data/logs
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl
export IDL_PRO_DIR                 # IDL catalog_1cuf_sweeps.bat needs this
IDL=/usr/local/bin/idl
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/update_gvradar_sweeps.${rundate}.log

umask 0002

echo "Starting radar volume sweep elevation cataloging on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\t \a \f '|' \o '/tmp/files1cufnew.unl' \\\select radar_id, \
filepath||'/'||filename, fileidnum from gvradar where product='1CUF' and \
nominal > (select max(nominal) from gvradar_sweeps) order by 3 limit 20;" | psql gpmgv \
| tee -a $LOG_FILE 2>&1

if [ -s /tmp/files1cufnew.unl ]
  then
   # we have 1CUF files that haven't been processed to extract sweep angles
   # check that the to-be-called scripts are found
    if [ ! -s ${IDL_PRO_DIR}/catalog_1cuf_sweeps.bat ]
      then
         echo "Script ${IDL_PRO_DIR}/catalog_1cuf_sweeps.bat not found, exiting" \
           | tee -a $LOG_FILE
         echo "with no data processed for ${rundate}." \
           | tee -a $LOG_FILE
         exit 1
    fi
    CONTROLFILE=/tmp/files1cufnew.unl
    export CONTROLFILE          # IDL .bat file needs this
    echo "" | tee -a $LOG_FILE
     $IDL < ${IDL_PRO_DIR}/catalog_1cuf_sweeps.bat | tee -a $LOG_FILE 2>&1
fi

echo "" | tee -a $LOG_FILE
echo "update_gvradar_sweeps.sh complete, exiting." | tee -a $LOG_FILE
exit 0
