#!/bin/sh
#
################################################################################
#
#  catalog_PPS_CS_fromDailyLog.sh     Morris/SAIC/GPM GV     March 2016
#
#  DESCRIPTION
#    Catalogs previously downloaded coincidence subset (CS) satellite files 
#    already moved into their baseline directories by looking at the daily log
#    file for a given date.  To be run when database failures occurred in the
#    cataloging process in the original ingest run.
#
#  ROUTINES CALLED
#
#  FILES
#
#  DATABASE
#    disabled.
#
#  LOGS
#    Output for day YYYYMMDD original script run was logged to daily log file
#    catalog_PPS_CS_data.YYYYMMDD.log in /data/logs subdirectory.  This script
#    logs to catalog_PPS_CS_fromDailyLog.YYYYMMDD.log.
#
#  CONSTRAINTS
#    - User must have write privileges in TMP_CS_DATA and LOG_DIR, and INSERT
#      priveleges for 'gpmgv' database in Postgresql.
#
#  HISTORY
#    March 2016    - Morris - Created
#
################################################################################

GV_BASE_DIR=/home/morris
MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
CS_BASE=${DATA_DIR}/orbit_subset
export CS_BASE
TMP_CS_DATA=/data/tmp/PPS_CS
export TMP_CS_DATA
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
if [ -s $1 ]
  then
    rundate=`echo $1 | cut -f2 -d '.'`
    LOG_FILE=${LOG_DIR}/catalog_PPS_CS_fromDailyLog.${rundate}.log
  else
    echo "Log file not found or not specified as argument."
    exit 1
fi

umask 0002

# file listing partial datestamp YYMMDD of manifest files to be processed this run
FILES2DO=${TMP_CS_DATA}/DatesToGet

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in catalogCStypes4date()
SATSUBTYPE_TEMP=${TMP_CS_DATA}/SatSubsetSubtype2redo
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP


# Retrieve and parse the daily catalog_PPS_CS_data.YYYYMMDD.log file to find
# out which files have been downloaded and moved to baseline directories for a
# date. 
#
# The directory structure into which the downloaded products was be moved is:
#
# satellite/             (GPM, TRMM, F16, etc.)
#   instrument/          (DPR, GMI, SSMIS, etc.)
#     algorithm/         (2AGPROF, 2BDPRGMI, 2A25, 2AKa, 2Aku, etc.), 
#       version/         (V00A, V00B, V01, V07, etc.)
#         subset/        (CONUS, KWAJ, KORA, etc.)
#           year/        (2014, 2015,…)
#             month/     (01, 02, …, 12)
#               day/     (01, 02, …, 28, 29, 30, 31)
#                 (data files)
#
# under the common directory defined by $CS_BASE.
#
# The database table "orbit_subset_product: where the downloaded files listed in
# the log file are to be cataloged has the schema:
#
#     Column    |          Type          |     Modifiers      
# --------------+------------------------+--------------------
#  sat_id       | character varying(15)  | not null
#  orbit        | integer                | not null
#  product_type | character varying(15)  | not null
#  filedate     | date                   | 
#  filename     | character varying(120) | 
#  subset       | character varying(15)  | not null
#  version      | character varying(5)   | not null default 6
#

 # walk through the log file and identify ingested files, store list in temp file
   grep "\->" $1 | cut -f3 -d ' ' | cut -f2 -d "\`" | cut -f1 -d "'" | tee $SATSUBTYPE_TEMP | tee $LOG_FILE
   if [ -s $SATSUBTYPE_TEMP ]
     then
       # check our success and catalog downloaded file(s) in database
       for thisPPSfilepath in `cat $SATSUBTYPE_TEMP`
         do
           # extract the file basename and dirname from thisPPSfilepath
           thisPPSfile=${thisPPSfilepath##*/}
           thisPPSdir=${thisPPSfilepath%/*}
           # check our success
           if [ -s ${thisPPSfilepath} ]
             then
               echo "Have file $thisPPSfile" | tee -a $LOG_FILE
               # get info needed to catalog and move the file to baseline tree
               satellite=`echo $thisPPSdir | cut -f5 -d '/'`
               subset=`echo $thisPPSdir | cut -f9 -d '/'`
               # extract the YYYY/MM/DD directory specification for the file
               YMDdir=`echo $thisPPSfile | cut -f5 -d '.' | cut -f1 -d '-' \
                     | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
               # extract the version specification from the ftp filepath
               Version=`echo $thisPPSfile | cut -f 7 -d '.'`
               # extract the orbit, instrument and algorithm names from the file basename
               Orbit=`echo $thisPPSfile | cut -f 6 -d '.'`
               Instrument=`echo $thisPPSfile | cut -f 3 -d '.'`
               AlgoLong=`echo $thisPPSfile | cut -f 4 -d '.'`
               # format the product_type column value for the database based on rules
               echo $AlgoLong | grep GPROF > /dev/null
               if [ $? = 0 ]
                 then
                   # just use '2AGPROF' as algorithm name
                   Algo=2AGPROF
                 else
                   # apply special cases for TRMM and GPM non-GPROF
                   case $satellite in
                     TRMM ) Algo=$AlgoLong    # just use what's given, e.g., '2A25'
                           if [ "$Version" = "7" ]
                             then
                                Version="V0"$Version  # convert to naming standard
                           fi
                           ;;
                      GPM ) prodTypeLong=`echo $thisPPSfile | cut -f 1 -d '.'`
                            # see if we have '-' in 1st file subfield, e.g. '2A-CS-KWAJ'
                            echo $prodTypeLong | grep '-' > /dev/null
                            if [ $? = 0 ]
                              then
                                # have a compound product type/subset field, cut out type
                                prodType=`echo $prodTypeLong | cut -f1 -d '-'`
                              else
                                # have a simple type indicator, use as-is
                                prodType=$prodTypeLong
                            fi
                            # concatenate type and Instrument
                            Algo=${prodType}${Instrument}  # e.g., '2AKu'
                            ;;
                   esac
               fi
               # Catalog files in 'gpmgv' database table 'orbit_subset_product'
               echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" \
	                          | psql -a -d gpmgv  >> $LOG_FILE 2>&1
           fi
       done
   else
       echo "No downloaded/moved files found in $1." | tee -a $LOG_FILE
   fi

echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "See log file $LOG_FILE"
echo "" | tee -a $LOG_FILE

exit
