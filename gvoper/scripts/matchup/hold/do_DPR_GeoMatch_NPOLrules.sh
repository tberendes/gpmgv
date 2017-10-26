#!/bin/sh
###############################################################################
#
# do_DPR_GeoMatch_NPOLrules.sh    Morris/SAIC/GPM GV    March 2015
#
# Wrapper to do DPR-GR geometric matchups for 2ADPR/2AKa/2AKu and 1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# This "special" version brings up each new control file in the editor 'gedit'
# and waits while the user makes manual changes to the control file to replace
# missing 1CUF file placeholders with the actual 1CUF filenames, since this
# capability is "broken" for the NPOL/NPOL_MD file name disconnect between the
# gpmgv database tables and the radar file directory structure.
#
# Criteria are as defined in the query which is run to update the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the DPR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-Ku product.  See the SQL command file
# '${BIN_DIR}/rainCases100kmAddNewEvents.sql'.
#
# NOTE:  - When running dates that might have already had PR-GV matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match', either for the date(s) to be
#        run, or for all dates, OR use the "-f" option on the command line when
#        running this script.
#        - By default, processes matchups for the GR site ID 'NPOL_MD', but this
#        can be overridden by specifying a different radar ID after the "-g"
#        option on the command line.
#
# late 2014    Morris      - Created from do_DPR_GeoMatch.sh.
# 3/27/2014    Morris      - Modified to bring up each new control file in the
#                            'gedit' editor and pause to allow the user to
#                            manually fix missing radar file pathnames before
#                            proceeding to do_DPR_geo_matchup4date.sh to run
#                            the matchups in IDL.
# 2/14/2017   Morris       - Added definition and export of ITE_or_Operational
#                            environment variable.
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

# in case there are machine-specific filepath differences
# - all commented out until/if a need arises
#MACHINE=`hostname | cut -c1-3`
#if [ "$MACHINE" = "ds1" ]
#  then
#    DATA_DIR=/data/gpmgv
#  else
#    DATA_DIR=/data/gpmgv
#fi
#export DATA_DIR
#echo "DATA_DIR: $DATA_DIR"

LOG_DIR=/data/logs
export LOG_DIR
TMP_DIR=/data/tmp
export TMP_DIR
#GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V05A"        # controls which PR products we process
PARAMETER_SET=2  # set of polar2dpr parameters (polar2dpr.bat file) in use
INSTRUMENT_ID="DPR"       # default product to match up, can override to Ka or Ku
SAT_ID="GPM"
SWATH="NS"
GEO_MATCH_VERSION=1.21
GRSITE="NPOL_WA"

SKIP_NEWRAIN=0   # if 1, skip call to psql with SQL_BIN
FORCE_MATCH=0    # if 1, ignore appstatus for date(s) and (re)run matchups
DO_RHI=0         # if 1, then matchup to RHI UF files
NULL_SKIP=0      # if 1, then disable NULL check for geo_match_product

# override coded defaults with user-specified values
while getopts s:i:v:p:d:w:m:g:kfrn option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        w) SWATH=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        g) GRSITE=${OPTARG};;
        k) SKIP_NEWRAIN=1;;
        f) FORCE_MATCH=1;;
        r) DO_RHI=1;;
        n) NULL_SKIP=1;;
    esac
done

ALGORITHM=2A$INSTRUMENT_ID
export ALGORITHM

# extract the first character of the PPS_VERSION and set and export it as a
# flag for the IDL batch script to determine whether we are processing ITE or
# operational data and set the top-level path to the data files accordingly

ITE_or_Operational=`echo $PPS_VERSION | cut -c1`
export ITE_or_Operational

echo ""
echo "SAT_ID: $SAT_ID"
export SAT_ID
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
export INSTRUMENT_ID
echo "PPS_VERSION: $PPS_VERSION"
export PPS_VERSION
echo "PARAMETER_SET: $PARAMETER_SET"
export PARAMETER_SET
echo "ALGORITHM: $ALGORITHM"
echo "SWATH: $SWATH"
export SWATH
echo "GEO_MATCH_VERSION: $GEO_MATCH_VERSION"
export GEO_MATCH_VERSION
echo "GR SITE: $GRSITE"
export GRSITE
echo "SKIP_NEWRAIN: $SKIP_NEWRAIN"
echo "FORCE_MATCH: $FORCE_MATCH"
echo "DO_RHI: $DO_RHI"
echo "NULL_SKIP: $NULL_SKIP"
echo "ITE_or_Operational: $ITE_or_Operational"

COMBO=${SAT_ID}_${INSTRUMENT_ID}_${ALGORITHM}_${SWATH}

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/do_DPR_GeoMatch.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2dpr procedure, as
# listed in the do_DPR_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_DPR_geo_matchup4date.sh by examining the do_DPR_geo_matchup4date.yymmdd.log file. 
# Formats catalog entry for the geo_match_product table in the gpmgv database,
# and loads the entries to the database.

YYMMDD=$1
MATCHUP_LOG=${LOG_DIR}/do_DPR_geo_matchup4date.${YYMMDD}.log  # NOT USED
DBCATALOGFILE=$2
SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql
echo "Cataloging new matchup files listed in $DBCATALOGFILE"
# this same file is used in catalog_geo_match_products.sh and is also defined
# this way in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the name or format must be coordinated in all 3 files.

loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

for ncfile in `cat $DBCATALOGFILE`
  do
    radar_id=`echo ${ncfile} | cut -f2 -d '.'`
    orbit=`echo ${ncfile} | cut -f4 -d '.'`
   # PPS_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
    GEO_MATCH_VERSION_FILE=`echo ${ncfile} | cut -f8 -d '.' | sed 's/_/./'`
    # check for mismatch between input/coded geo_match_version and matchup file version
    if [ `expr $GEO_MATCH_VERSION_FILE = $GEO_MATCH_VERSION` = 0 ]
      then
        echo "Mismatch between script GEO_MATCH_VERSION ("${GEO_MATCH_VERSION}\
") and file GEO_MATCH_VERSION ("${GEO_MATCH_VERSION_FILE}")"
      exit 1
    fi
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}|${SWATH}"
    gzfile=`ls ${ncfile}\.gz`
    if [ $? = 0 ]
      then
        echo "Found $gzfile" | tee -a $LOG_FILE
        rowdata="${rowpre}${gzfile}${rowpost}"
        echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
      else
        echo "Didn't find gzip version of $ncfile" | tee -a $LOG_FILE
        ungzfile=`ls ${ncfile}`
        if [ $? = 0 ]
          then
            echo "Found $ungzfile" | tee -a $LOG_FILE
            rowdata="${rowpre}${ungzfile}${rowpost}"
            echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
        fi
    fi
done

if [ -s $loadfile ]
  then
   # load the rows to the database
    echo "\i $SQL_BIN2" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
fi

return
}
################################################################################

# Begin main script

echo "Starting $INSTRUMENT_ID and GR matchup netCDF generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""
case $COMBO
  in
    GPM_DPR_2ADPR_HS)  echo "$COMBO OK" 
                       MAX_DIST=125  # max radar-to-subtrack distance for overlap
                       MATCHTYPE=DPR ;;
    GPM_DPR_2ADPR_MS)  echo "$COMBO OK" 
                       MAX_DIST=125
                       MATCHTYPE=DPR ;;
    GPM_DPR_2ADPR_NS)  echo "$COMBO OK" 
                       MAX_DIST=250
                       MATCHTYPE=DPR ;;
    GPM_Ku_2AKu_NS)    echo "$COMBO OK" 
                       MAX_DIST=250
                       MATCHTYPE=DPR ;;
    GPM_Ka_2AKa_HS)    echo "$COMBO OK" 
                       MAX_DIST=125
                       MATCHTYPE=DPR ;;
    GPM_Ka_2AKa_MS)    echo "$COMBO OK" 
                       MAX_DIST=125
                       MATCHTYPE=DPR ;;
    *) echo "Illegal Satellite/Instrument/Algorithm/Swath combination: $COMBO" \
       | tee -a $LOG_FILE
       echo "Exiting with error." | tee -a $LOG_FILE
       exit 1
esac
echo "Max Dist: $MAX_DIST"

if [ "$SKIP_NEWRAIN" = "0" ]
  then
    # update the list of rainy overpasses in database table 'rainy100inside100'
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
      else
        echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        exit 1
    fi
  else
    echo "" | tee -a $LOG_FILE
    echo "Skipping update of database table rainy100inside100" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

if [ "$DO_RHI" = 0 ]
  then
    IS_OR_NOT='NOT'
  else
    IS_OR_NOT=' '
fi

if [ "$NULL_SKIP" = 0 ]
  then
    NULL_BOGUS="is null"             # for comparison of NULL/NOT NULL filepath
    NULL_BOGUS2=" = 'No_GeoMatch'"   # for comparison of COALESCE filepath
  else
    NULL_BOGUS=" != 'bOgUs' "
    NULL_BOGUS2=" != 'bOgUs' "
fi

echo "IS_OR_NOT: $IS_OR_NOT"
echo "NULL_BOGUS: $NULL_BOGUS"
echo "NULL_BOGUS2: $NULL_BOGUS2"

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the query to just run grids for range of dates/orbits.  Limit ourselves
# to the past 30 days.

datelist=${TMP_DIR}/doGeoMatchSelectedDates_temp.txt
rm -v $datelist

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -160`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
datestart='2015-11-11'
echo "Running DPRtoGR matchups for dates since $datestart" | tee -a $LOG_FILE
dateEnd='2016-01-31'

# here's a faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table
DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT c.* into temp tempevents \
from eventsatsubrad_vw c JOIN orbit_subset_product o \
  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
 AND o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
   and c.subset NOT IN ('KOREA','KORA') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' > '${datestart}' \
   and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
AND C.RADAR_ID IN ('${GRSITE}') \
JOIN rainy100inside100 r on (c.event_num=r.event_num) order by c.overpass_time; \
select DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
  from tempevents c LEFT OUTER JOIN geo_match_product g \
    on c.radar_id=g.radar_id and c.orbit=g.orbit and c.sat_id=g.sat_id \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET} and g.geo_match_version=${GEO_MATCH_VERSION}
   and g.scan_type='${SWATH}' \
 WHERE pathname $NULL_BOGUS \
 UNION \
 select DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
  from tempevents c LEFT OUTER JOIN geo_match_product g \
    on c.radar_id=g.radar_id and c.orbit=g.orbit and c.sat_id=g.sat_id \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET} and g.geo_match_version=${GEO_MATCH_VERSION}
   and g.scan_type='${SWATH}' \
 WHERE pathname is null order by 1 ;"`

#echo "2014-04-01" > $datelist   # edit/uncomment to just run a specific date

echo ""
echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

for thisdate in `cat $datelist`
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`

   # files to hold the delimited output from the database queries comprising the
   # control files for the 2ADPR/Ka/Ku-GR matchup creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/DPR_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/DPR_files_sites4geoMatch_temp.txt
    tag=${GRSITE}.${ALGORITHM}.${SWATH}.${PPS_VERSION}.${yymmdd}
    outfileall=${TMP_DIR}/DPR_files_sites4geoMatch.${tag}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of DPR files to process, put in file $filelist
   # -- 2BDPRGMI file is ignored for now

    echo "DROP TABLE temp_n_geo;" | psql gpmgv

   # here's a faster four-query set with the "left outer join geo_match_product"
   # connected to a simple temp table

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, c.event_num, c.radar_id, \
       '${yymmdd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, '${SWATH}'::text as swath, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2a \
       into temp possible_2adpr \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('${GRSITE}') \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where cast(nominal at time zone 'UTC' as date) = '${thisdate}' and d.version = '$PPS_VERSION'; \

     CREATE TABLE temp_n_geo AS \
     select c.orbit, c.datestamp, c.subset, c.version, c.instrument, c.swath, c.file2a, \
            COALESCE(b.pathname, 'No_GeoMatch') as pathname, c.radar_id, c.event_num, b.instrument_id, \
            b.geo_match_version, b.scan_type, b.parameter_set, b.sat_id \
       from possible_2adpr c left outer join geo_match_product b on (c.radar_id=b.radar_id \
        and c.orbit=b.orbit and c.version=b.pps_version and b.instrument_id = '${INSTRUMENT_ID}' \
        and b.geo_match_version=${GEO_MATCH_VERSION} and b.scan_type='${SWATH}' \
        and b.parameter_set=${PARAMETER_SET} and b.sat_id='GPM');

     update temp_n_geo set instrument_id = '${INSTRUMENT_ID}', geo_match_version = ${GEO_MATCH_VERSION},\
                           scan_type = '${SWATH}', parameter_set = ${PARAMETER_SET}, sat_id = 'GPM';

     select  orbit, count(*), datestamp, subset, version, instrument, swath, file2a\
       from temp_n_geo where pathname $NULL_BOGUS2 group by 1,3,4,5,6,7,8 order by orbit;"`  | tee -a $LOG_FILE 2>&1

#     select  c.orbit, count(*), c.datestamp, c.subset, c.version, c.instrument, c.swath, c.file2a\
#       from possible_2adpr c left outer join geo_match_product b on (c.radar_id=b.radar_id \
#        and c.orbit=b.orbit and c.version=b.pps_version and b.instrument_id = '${INSTRUMENT_ID}' \
#        and b.geo_match_version=${GEO_MATCH_VERSION} and b.scan_type='${SWATH}' \
#        and b.parameter_set=0 and b.sat_id='GPM') where b.pathname $NULL_BOGUS \
#   group by 1,3,4,5,6,7,8 order by c.orbit;"`  | tee -a $LOG_FILE 2>&1

echo ''
echo "filelist:"
cat $filelist
echo ''
echo "select c.orbit, c.event_num, c.radar_id, \
       '${yymmdd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, '${SWATH}'::text as swath, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2a \
       into temp possible_2adpr \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
        AND C.RADAR_ID IN ('${GRSITE}') \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where cast(nominal at time zone 'UTC' as date) = '${thisdate}' and d.version = '$PPS_VERSION'; \

     CREATE TABLE temp_n_geo AS \
     select c.orbit, c.datestamp, c.subset, c.version, c.instrument, c.swath, c.file2a, \
            COALESCE(b.pathname, 'No_GeoMatch') as pathname, c.radar_id, c.event_num, b.instrument_id, \
            b.geo_match_version, b.scan_type, b.parameter_set, b.sat_id \
       from possible_2adpr c left outer join geo_match_product b on (c.radar_id=b.radar_id \
        and c.orbit=b.orbit and c.version=b.pps_version and b.instrument_id = '${INSTRUMENT_ID}' \
        and b.geo_match_version=${GEO_MATCH_VERSION} and b.scan_type='${SWATH}' \
        and b.parameter_set=${PARAMETER_SET} and b.sat_id='GPM');
     update temp_n_geo set instrument_id = '${INSTRUMENT_ID}', geo_match_version = ${GEO_MATCH_VERSION},\
                           scan_type = '${SWATH}', parameter_set = ${PARAMETER_SET}, sat_id = 'GPM';
     select  orbit, count(*), datestamp, subset, version, instrument, swath, file2a\
       from temp_n_geo where pathname $NULL_BOGUS2 group by 1,3,4,5,6,7,8 order by orbit;"
#exit
   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do DPR-GR matchup file creation.
   #  We now use temp tables and sorting by time difference between overpass_time and
   #  radar nominal time (nearest minute) to handle where the same radar_id
   #  comes up more than once for an orbit.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f1 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`
	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
          into temp timediftmp
          from overpass_event a, fixed_instrument_location b, \
	    collate_npol_wa_1cuf c \
            left outer join temp_n_geo e on \
              (c.radar_id=e.radar_id and c.orbit=e.orbit and c.event_num=e.event_num and \
               c.version=e.version and e.instrument_id = '${INSTRUMENT_ID}' \
               and e.parameter_set=${PARAMETER_SET} and e.sat_id='${SAT_ID}' \
               and e.geo_match_version=${GEO_MATCH_VERSION}) and e.scan_type='${SWATH}' \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' \
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and e.pathname $NULL_BOGUS2 and c.version = '$PPS_VERSION' \
            AND ( C.FILE1CUF ${IS_OR_NOT} LIKE '%rhi%' OR C.FILE1CUF ='no_1CUF_file' ) \
            AND C.RADAR_ID IN ('${GRSITE}') \
          order by 3,9;
          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
            from timediftmp group by 1 order by 1;
          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
        | tee -a $LOG_FILE 2>&1

#        date | tee -a $LOG_FILE 2>&1

echo "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
          from overpass_event a, fixed_instrument_location b, \
	    collate_npol_wa_1cuf c \
            left outer join temp_n_geo e on \
              (c.radar_id=e.radar_id and c.orbit=e.orbit and c.event_num=e.event_num and \
               c.version=e.version and e.instrument_id = '${INSTRUMENT_ID}' \
               and e.parameter_set=${PARAMETER_SET} and e.sat_id='${SAT_ID}' \
               and e.geo_match_version=${GEO_MATCH_VERSION}) and e.scan_type='${SWATH}' \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' \
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and e.pathname $NULL_BOGUS2 and c.version = '$PPS_VERSION' \
            AND C.FILE1CUF ${IS_OR_NOT} LIKE '%rhi%' \
            AND C.RADAR_ID IN ('${GRSITE}') \
          order by 3,9;"

        echo ""  | tee -a $LOG_FILE
        echo "Control file additions:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
       # copy the temp file outputs from psql to the daily control file
        echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

echo ""
echo "Output control file:"
ls -al $outfileall
cat $outfileall
#exit  # if uncommented, creates the control file for first date, and exits
gedit $outfileall

   echo "Continue to IDL matchup step? (Y or N):"
    read -r bail
    if [ "$bail" != 'Y' -a "$bail" != 'y' ]
      then
        if [ "$bail" != 'N' -a "$bail" != 'n' ]
          then
            echo "Illegal response: ${bail}, skipping." | tee -a $LOG_FILE
        fi
        echo "Skipping IDL matchup step on user command." | tee -a $LOG_FILE
      else
        if [ -s $outfileall ]
          then
           # Call the IDL wrapper script, do_DPR_geo_matchup4date.sh, to run
           # the IDL .bat files.  Let each of these deal with whether the yymmdd
           # has been done before.

            echo "" | tee -a $LOG_FILE
            start1=`date -u`
            echo "Calling do_DPR_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
            ${BIN_DIR}/do_DPR_geo_matchup4date.sh -f $FORCE_MATCH -r $DO_RHI $yymmdd $outfileall

            case $? in
              0 )
                echo ""
                echo "SUCCESS status returned from do_DPR_geo_matchup4date.sh"\
                 | tee -a $LOG_FILE
               # extract the pathnames of the matchup files created this run, and 
               # catalog them in the geo_matchup_product table.  The following file
               # must be identically defined here and in do_DPR_geo_matchup4date.sh
                DBCATALOGFILE=${TMP_DIR}/do_DPR_geo_matchup_catalog.${yymmdd}.txt
                if [ -s $DBCATALOGFILE ] 
                  then
                    catalog_to_db $yymmdd $DBCATALOGFILE
                  else
                    echo "but no matchup files listed in $DBCATALOGFILE !"\
                     | tee -a $LOG_FILE
                    #exit 1
                fi
              ;;
              1 )
                echo ""
                echo "FAILURE status returned from do_DPR_geo_matchup4date.sh, quitting!"\
                 | tee -a $LOG_FILE
                exit 1
              ;;
              2 )
                echo ""
                echo "REPEAT status returned from do_DPR_geo_matchup4date.sh, do nothing!"\
                 | tee -a $LOG_FILE
              ;;
            esac

            echo "" | tee -a $LOG_FILE
            end=`date -u`
            echo "Matchup script for $yymmdd completed on $end" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
            echo "=================================================================="\
            | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
        fi
    fi

   echo "Continue to next date? (Y or N):"
    read -r bail
    if [ "$bail" != 'Y' -a "$bail" != 'y' ]
      then
         if [ "$bail" != 'N' -a "$bail" != 'n' ]
           then
             echo "Illegal response: ${bail}, exiting." | tee -a $LOG_FILE
         fi
         echo "Quitting on user command." | tee -a $LOG_FILE
         exit
    fi

done

exit
