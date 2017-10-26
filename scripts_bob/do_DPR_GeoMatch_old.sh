#!/bin/sh
###############################################################################
#
# do_DPR_GeoMatch.sh    Morris/SAIC/GPM GV    March 2010
#
# Wrapper to do PR-GV NetCDF geometric matchups for 1C21/2A25/2B31/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which is run to update the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See the SQL command file
# ${BIN_DIR}/'rainCases100kmAddNewEvents.sql'.
#
# NOTE:  When running dates that might have already had PR-GV matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match', either for the date(s) to be
#        run, or for all dates.
#
# 4/18/2014   Morris       - Created from doGeoMatch4NewRainCases.sh.
#                            Added capability to accept command line parameters
#                            to define the type of satellite data products to
#                            match up to the ground radar, and modified
#                            queries to use new database VIEWs.
#                          - Added SAT_ID to the fields written to the loadfile
#                            to match up to the new geo_match_product database
#                            table definition.
#
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

LOG_DIR=/data/logs
export LOG_DIR
TMP_DIR=/data/tmp
export TMP_DIR
#GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V04A"        # controls which PR products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="Ku"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2AKu"
export ALGORITHM
SWATH="NS"
export SWATH

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
        w) SWATH=${OPTARG};;
    esac
done

echo ""
echo "SAT_ID: $SAT_ID"
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
echo "PPS_VERSION: $PPS_VERSION"
echo "PARAMETER_SET: $PARAMETER_SET"
echo "ALGORITHM: $ALGORITHM"
echo "SWATH: $SWATH"

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
    GEO_MATCH_VERSION=`echo ${ncfile} | cut -f8 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}"
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

# update the list of rainy overpasses in database table 'rainy100inside100'
if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN | psql -a -d gpmgv" | tee -a $LOG_FILE 2>&1
  else
    echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the query to just run grids for range of dates/orbits.  Limit ourselves
# to the past 30 days.

datelist=${TMP_DIR}/doGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -40`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
echo "Running PRtoGR matchups for dates since $datestart" | tee -a $LOG_FILE

DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT DISTINCT date(date_trunc('day', \
c.overpass_time at time zone 'UTC')) from eventsatsubrad_vw c \
LEFT JOIN orbit_subset_product o ON c.orbit = o.orbit AND c.subset = o.subset \
   AND c.sat_id = o.sat_id AND o.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} \
LEFT OUTER JOIN geo_match_product g on (c.event_num=g.event_num and \
   o.version=g.pps_version and g.instrument_id='${INSTRUMENT_ID}') \
JOIN rainy100inside100 r on (c.event_num=r.event_num) \
WHERE g.pathname is null and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' order by 1;"`

echo " "
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
   # control files for the 1C21/2A23/2A25/2B31 grid creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/DPR_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/DPR_files_sites4geoMatch_temp.txt
    outfileall=${TMP_DIR}/DPR_files_sites4geoMatch_old.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of DPR files to process, put in file $filelist
   # -- 2BDPRGMI file is ignored for now

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
       '${yymmdd}', c.subset, d.version, '${INSTRUMENT_ID}', '${SWATH}', \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename\
       as file2a12\
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
     left outer join geo_match_product b on \
       (c.event_num=b.event_num and d.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}' and b.parameter_set=${PARAMETER_SET}) \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
       and b.pathname is null and d.version = '$PPS_VERSION' \
     group by 1,3,4,5,6,7,8 \
     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1

    date | tee -a $LOG_FILE 2>&1
echo ''
echo "filelist:"
cat $filelist
echo ''
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
          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
	    collate_satsubprod_1cuf c \
            left outer join geo_match_product e on \
              (c.event_num=e.event_num and \
               c.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}' \
               and e.parameter_set=${PARAMETER_SET}) \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num\
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and e.pathname is null and c.version = '$PPS_VERSION' \
            AND C.FILE1CUF NOT LIKE '%rhi%' \
          order by 3,9;
          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
            from timediftmp group by 1 order by 1;
          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
        | tee -a $LOG_FILE 2>&1

#        date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Control file additions:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
       # copy the temp file outputs from psql to the daily control file
        echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

echo "Output control file:"
ls -al $outfileall
#exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper script, do_DPR_geo_matchup4date.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

#        echo "" | tee -a $LOG_FILE
#        echo "" | tee -a $LOG_FILE
        echo "=================================================================="\
        | tee -a $LOG_FILE
#        echo "" | tee -a $LOG_FILE
    fi

    #echo "Continue to next date? (Y or N):"
    #read -r bail
    bail="Y"
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
