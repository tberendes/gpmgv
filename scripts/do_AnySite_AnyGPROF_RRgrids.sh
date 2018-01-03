#!/bin/sh
###############################################################################
#
# do_AnySite_AnyGPROF_RRgrids.sh    Morris/SAIC/GPM GV    Feb 2017
#
# Computes gridded rain rate from 2AGPROF data for a user-selected
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

LOG_DIR=/data/logs
export LOG_DIR
META_LOG_DIR=${LOG_DIR}/meta_logs
TMP_DIR=/data/tmp
export TMP_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V04A"        # controls which DPR products we process
export PPS_VERSION
INSTRUMENT_ID="GMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2AGPROF"
export ALGORITHM
GRSITE="KWAJ"
export GRSITE
RES_KM=25                 # default grid spacing
export RES_KM

# override coded defaults with user-specified values
while getopts s:i:v:a:g:r: option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        g) GRSITE=${OPTARG};;
        r) RES_KM=${OPTARG};;
    esac
done

echo ""
echo "SAT_ID: $SAT_ID"
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
echo "PPS_VERSION: $PPS_VERSION"
echo "ALGORITHM: $ALGORITHM"
echo "GR SITE: $GRSITE"
echo "RES_KM: $RES_KM"

MACHINE=`echo $PPS_VERSION | cut -c1`
if [ "$MACHINE" = "I" ]
  then
    DATA_DIR=/data/emdata
  else
    DATA_DIR=/data/gpmgv
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
ORBDATA_DIR=${DATA_DIR}/orbit_subset
echo "ORBDATA_DIR: $ORBDATA_DIR"

# Only the GPM GMI combination has information on site rain events in the
# rainy100inside100 table in the gpmgv database.  If running for another SAT_ID
# and INSTRUMENT, then exclude this table from the first query that identifies
# the 2AGPROF files to process, and set the FIND_RAIN variable to 1 to tell IDL
# to save a grid only if it has 2AGROF rain of a sufficient area.

if [ "$SAT_ID" = "GPM" ]
  then
    FIND_RAIN=0
    RAIN_CLAUSE="JOIN rainy100inside100 r on (c.event_num=r.event_num)"
  else
    FIND_RAIN=1
    RAIN_CLAUSE=" "
fi
export FIND_RAIN

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

MAX_DIST=400

dateStart='2016-03-05'
dateEnd='2016-04-25' #'2016-12-01'
echo "Running GPROF metadata for dates from $dateStart" to $dateEnd | tee -a $LOG_FILE

yymmdd=$rundate
# files to hold the delimited output from the database queries comprising the
# control files for the GPROF RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# GPROF files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${TMP_DIR}/filesGPROF_temp.txt
outfile=${TMP_DIR}/fileGPROF_sites_temp.txt
outfileall=${TMP_DIR}/file2AGPROFsites.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of GPROF files to be processed, put in file $filelist
# There should be 11 metadata items for each overpass
# If less, just add the event to the list and let the duplicate rejection take
# care of any redundant database inserts.
echo "select '${ORBDATA_DIR}/${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'\
||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'||to_char(d.filedate,'MM')||'/'\
||to_char(d.filedate,'DD')||'/'||d.filename, d.orbit, c.radar_id, count(*)\
     from eventsatsubrad_vw c\
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('$GRSITE') and d.version='${PPS_VERSION}' \
        and c.overpass_time at time zone 'UTC' > '${dateStart}' \
        and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
     $RAIN_CLAUSE \
        group by 1,2,3 order by 2,3;"


echo "\t \a \f '|' \o $filelist \
     \\\ select '${ORBDATA_DIR}/${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'\
||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'||to_char(d.filedate,'MM')||'/'\
||to_char(d.filedate,'DD')||'/'||d.filename, d.orbit, c.radar_id, count(*)\
     from eventsatsubrad_vw c\
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('$GRSITE') and d.version='${PPS_VERSION}' \
        and c.overpass_time at time zone 'UTC' > '${dateStart}' \
        and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
     $RAIN_CLAUSE \
        group by 1,2,3 order by 2,3;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do GPROF file metadata extraction
# - Ignore the '2aDPR' designation in the variable names, it's a carryover.
echo "Filelist:"
cat $filelist
#echo ""
#tail $filelist
echo ""
#exit

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
        echo "Calling get2AGPROF_RRgrids4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/get2AGPROF_RRgrids4date.sh $yymmdd
    fi
fi

echo ""
echo "Control file: $outfileall"
ls -al $outfileall

exit
