#!/bin/sh
###############################################################################
#
# do_DPRtoGMI_OrbitMatch.sh    Morris/SAIC/GPM GV    October 2014
#
# DESCRIPTION:
# Query gpmgv database for dates/times of rainy DPR or GR events and assemble
# command string to do the DPR-GMI geometry matching for events with data.
# Completed geometry match files are cataloged in the 'gpmgv' database table
# 'geo_match_products'.
#
# 10/14/2014   Morris        Created from do_GMI_GeoMatch.sh.
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv
export DATA_DIR
TMP_DIR=/data/tmp
export TMP_DIR
LOG_DIR=/data/logs
export LOG_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION=V03C        # controls which GMI products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2tmi parameters (polar2tmi.bat file) in use
export PARAMETER_SET
MAX_DIST=250  # max radar-to-subtrack distance for overlap

# set ids of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="GMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2AGPROF"
export ALGORITHM

# override coded defaults with user-specified values
while getopts s:i:v:p:a:d:w: option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        a) ALGORITHM=${OPTARG};;
#        w) SWATH=${OPTARG};;
    esac
done

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/doDPRtoGMI_OrbitMatch.${PPS_VERSION}.${rundate}.log

umask 0002

# Begin main script
echo "Starting TMI-GR matchups on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# update the list of rainy overpasses in database table 'rainy100inside100'
 if [ -s $SQL_BIN ]
   then
     echo "\i $SQL_BIN" # | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
   else
     echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     exit 1
 fi

# query finds unique dates where either of the PR "100 rain certain 4-km
# gridpoints within 100km" or the GR "100 2-km non-zero 2A-53 rainrate gridpoints"
# criteria are met, as encapsulated in the database VIEW rainy100merged_vw.  The
# latter query is much more likely to be met for a set of overpassed GR sites.
# - Excludes orbits whose TMI-GR matchup has already been created/cataloged,
#   and those for which 2A-5x products have not been received yet.

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doTMIGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -240`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
echo "Running GRtoGMI matchups for dates since $datestart" | tee -a $LOG_FILE

# here's a much faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table
DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT c.* into temp tempevents \
from eventsatsubrad_vw c JOIN orbit_subset_product o \
  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
 AND o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
   and c.subset NOT IN ('KOREA','KORA') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' > '${datestart}' \
JOIN rainy100inside100 r on (c.event_num=r.event_num) order by c.overpass_time; \
select DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
  from tempevents c LEFT OUTER JOIN geo_match_product g \
    on c.radar_id=g.radar_id and c.orbit=g.orbit and c.sat_id=g.sat_id \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET} WHERE pathname is null order by 1;"`

echo "2014-08-22" > $datelist
echo " "
echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# build an IDL control file and run the matchups.

   # files to hold the delimited output from the database queries comprising the
   # control files for the TMI-GR matchup file creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/GMI_orbit_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/GMI_orbit_files_sites4geoMatch_temp.txt
    outfileall=${TMP_DIR}/GMI_orbit_files_sites4geoMatch.${ymd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of GMI 2AGPROF files to process, put in file $outfileall

# here's a much faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table
    DBOUT2=`psql -a -A -t -o $outfileall  -d gpmgv -c "select c.orbit, c.radar_id, \
       '${ymd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2a \
into temp possible_2agprof \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where  d.version = '$PPS_VERSION'; \
     select  c.file2a, c.orbit, count(*), c.datestamp, c.subset, c.version \
       into temp temp2 from possible_2agprof c  \
       group by 1,2,4,5,6 order by c.orbit;
     select file2a from temp2;"`  | tee -a $LOG_FILE 2>&1

    echo ""
    echo "Control file ${outfileall} contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE
    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_GMI_geo_matchup4date.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_GMI_geo_matchup4date.sh $ymd on $start1" | tee -a $LOG_FILE
        # ${BIN_DIR}/do_GMI_geo_matchup4date.sh $ymd
    fi

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "See log file: $LOG_FILE"
exit
