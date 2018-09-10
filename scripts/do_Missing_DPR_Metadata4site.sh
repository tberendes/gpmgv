#!/bin/sh
###############################################################################
#
# do_Missing_DPR_Metadata.sh    Morris/SAIC/GPM GV    Jan 2015
#
# Computes missing rain event metadata from 2AKu or 2ADPR data for a specified
# ground radar site.  Assumes that the overpass event information for the site
# is present in the gpmgv database.  Has hard-coded defaults for PPS version,
# GR site, Instrument, and Algorithm that can be overridden by command line
# parameters.
#
###############################################################################

USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
  else
    if [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
      else
        echo "User unknown, can't set GV_BASE_DIR!"
        exit 1
    fi
fi
echo "GV_BASE_DIR: $GV_BASE_DIR"
export GV_BASE_DIR

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
ORBDATA_DIR=${DATA_DIR}/orbit_subset
echo "ORBDATA_DIR: $ORBDATA_DIR"

LOG_DIR=/data/logs
export LOG_DIR
META_LOG_DIR=${LOG_DIR}/meta_logs
TMP_DIR=/data/tmp
export TMP_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V05A"        # controls which DPR products we process
export PPS_VERSION
INSTRUMENT_ID="Ku"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2AKu"
export ALGORITHM
GRSITE="KDTX"
export GRSITE
SUBSET='CONUS'
export SUBSET

# override coded defaults with user-specified values
while getopts s:i:v:a:g:u: option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        a) ALGORITHM=${OPTARG};;
        g) GRSITE=${OPTARG};;
        u) SUBSET=${OPTARG};;
    esac
done

echo ""
echo "SAT_ID: $SAT_ID"
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
echo "PPS_VERSION: $PPS_VERSION"
echo "ALGORITHM: $ALGORITHM"
echo "GR SITE: $GRSITE"
echo "SUBSET: $SUBSET"

COMBO=${SAT_ID}_${INSTRUMENT_ID}_${ALGORITHM}

rundate=MsgMta                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/do_Missing_DPR_Metadata.${rundate}.log
export rundate

umask 0002

echo "Starting missing metadata run for DPR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""
case $COMBO
  in
    GPM_DPR_2ADPR)     echo "$COMBO OK" 
                       MAX_DIST=250
                       MATCHTYPE=DPR ;;
    GPM_Ku_2AKu)       echo "$COMBO OK" 
                       MAX_DIST=250
                       MATCHTYPE=DPR ;;
    *) echo "Illegal Satellite/Instrument/Algorithm/Swath combination: $COMBO" \
       | tee -a $LOG_FILE
       echo "Exiting with error." | tee -a $LOG_FILE
       exit 1
esac

yymmdd=$rundate
# files to hold the delimited output from the database queries comprising the
# control files for the 2AKu RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2AKu files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${TMP_DIR}/files2aKu_temp.txt
outfile=${TMP_DIR}/file2aKu_sites_temp.txt
outfileall=${TMP_DIR}/file2aDPRsites.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of 2AKu files to be processed, put in file $filelist
# There should be 11 metadata items for each overpass
# If less, just add the event to the list and let the duplicate rejection take
# care of any redundant database inserts.
echo "select '${ORBDATA_DIR}/${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'\
||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'||to_char(d.filedate,'MM')||'/'\
||to_char(d.filedate,'DD')||'/'||d.filename, d.orbit, c.radar_id, count(*)\
     from eventsatsubrad_vw c\
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset IN ('${SUBSET}') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('$GRSITE') and d.version='${PPS_VERSION}' \
       and 11 > (select count(*) from event_meta_numeric \
       where event_num=c.event_num) group by 1,2,3 \
     order by 2,3;"

echo "\t \a \f '|' \o $filelist \
     \\\ select '${ORBDATA_DIR}/${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'\
||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'||to_char(d.filedate,'MM')||'/'\
||to_char(d.filedate,'DD')||'/'||d.filename, d.orbit, c.radar_id, count(*)\
     from eventsatsubrad_vw c\
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset IN ('${SUBSET}') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('$GRSITE') and d.version='${PPS_VERSION}' \
       and 11 > (select count(*) from event_meta_numeric \
       where event_num=c.event_num) group by 1,2,3 \
     order by 2,3;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 2A23/2A25 file metadata extraction
#echo "Filelist:"
#head $filelist
#echo ""
#tail $filelist
echo ""

if [ -s $filelist ]
  then
       for thisrow in `cat $filelist`
         do
           thisPPSfilepath=`echo $thisrow | cut -f1 -d '|'`
           file2aDPR=${thisPPSfilepath##*/}
           file2aDPRdir=${thisPPSfilepath%/*}
           echo "File: $file2aDPR"
           echo "\t \a \f '|' \o $outfile \
            \\\ SELECT '${thisPPSfilepath}', b.orbit, count(*) \
             FROM overpass_event a, orbit_subset_product b, \
                  siteproductsubset d \
            WHERE b.filename = '${file2aDPR}' \
              AND b.subset = d.subset AND a.sat_id = d.sat_id AND a.sat_id=b.sat_id \
              AND a.radar_id = '$GRSITE' AND a.radar_id = d.radar_id AND a.orbit = b.orbit \
         GROUP BY b.filename, b.orbit; \
           SELECT a.event_num, a.radar_id, b.latitude, b.longitude \
             FROM overpass_event a, fixed_instrument_location b, \
               orbit_subset_product c, siteproductsubset d \
            WHERE a.radar_id = b.instrument_id and a.radar_id = d.radar_id AND a.radar_id = '$GRSITE' \
              AND a.sat_id = d.sat_id AND a.sat_id=c.sat_id \
              AND a.orbit = c.orbit and c.subset = d.subset \
              AND c.filename='${file2aDPR}';" \
                | psql gpmgv  >> $LOG_FILE 2>&1

           thisorbitpadded=`echo ${file2aDPR} | cut -f6 -d '.'`
           thisorbit=`expr $thisorbitpadded + 0`  # convert to numeric to remove zero padding
           thissubset=`echo ${file2aDPRdir} | cut -f9 -d'/'`
#           echo ""  | tee -a $LOG_FILE
           if [ -s $outfile ]
             then
               echo "Control file additions for subset ${thissubset}, orbit ${thisorbit}:"\
                   | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
	           # copy the temp file output from psql to the daily control file
               cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
             else
               echo "No control file additions for subset ${thissubset}, orbit ${thisorbit}"\
                 | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
           fi
       done

    if [ -s $outfileall ]
      then
        echo "" | tee -a $LOG_FILE
        start1=`date -u`
       #   reset the database for running of missing metadata.  Re-uses a fixed yymmdd,
       #   so we need to remove all values with this tag from appstatus table.
        echo "delete from appstatus where app_id = 'get2ADPRMeta4dy' and datestamp = '${yymmdd}';" \
          | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1

        echo "Calling get2ADPRMeta4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/get2ADPRMeta4date.sh $yymmdd

        # CHECK THE STATUS OF THE ABOVE SCRIPT BEFORE BLINDLY DECLARING SUCCESS
	     if [ $? = 1 ]
	       then
	         echo "UPDATE appstatus SET status = '$MISSING' \
	           WHERE app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';" \
	           | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	         echo "See log file ${META_LOG_DIR}/get2ADPRMeta4date.${yymmdd}.log" \
              | tee -a $LOG_FILE
            exit 1
          else
            echo "" | tee -a $LOG_FILE
            end=`date -u`
            echo "Metadata script for $yymmdd completed on $end," | tee -a $LOG_FILE
            echo "set status to SUCCESS in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
            echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
             app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';"\
              | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	     fi
      else
        echo "" | tee -a $LOG_FILE
        echo "Mark $yymmdd as incomplete -- no coincidence data for orbit(s)," \
	          | tee -a $LOG_FILE
        echo "  or no 2A${INSTRUMENT} subset data files listed in ${MIR_LOG_FILE}," \
	          | tee -a $LOG_FILE
        echo "  so set status to MISSING in database:" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$MISSING' WHERE \
         app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';"\
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi
fi

echo ""
echo "Control file: $outfileall"
ls -al $outfileall

exit
