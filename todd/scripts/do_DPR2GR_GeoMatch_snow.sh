#!/bin/sh
###############################################################################
#
# do_DPR2GR_GeoMatch_snow.sh    Morris/SAIC/GPM GV    March 2016
#
# Wrapper to do DPR-GV NetCDF geometric matchups for DPR 2A-[DPR|Ka|Ku] files
# already received and cataloged, for cases meeting predefined criteria.  This
# script drives volume matches of DPR data to GR data that has already been
# volume matched to DPR for all of the DPR scan types.  The previously matched
# GR data are contained in "GRtoDPR_HS_MS_NS" netCDF files, which are read and
# merged with the volume matched DPR data to produce the baseline "GRtoDPR"
# matchup netCDF files.  This script queries the 'gpmgv' database to find rainy
# site overpass events between a specified start and end date and assembles a
# series of date-specific control files to run matchups for those dates.  For
# each date, calls the child script do_DPR2GR_geo_matchup4date_snow.sh, which in turn
# invokes IDL to generate the DPRtoGR volume match netCDF files for that day's
# rainy overpass events as listed in the daily control file.  Ancillary output
# from the script is a series of 'control files', one per day in the range of
# dates to be processed, listing DPR and ground radar data files to be processed
# for rainy site overpass events for that calendar date, as well as metadata
# parameters related to the DPR and GR data and the site overpass events.
#
# The script has logic to compute the start and end dates over which to attempt
# volume match runs.  The end date is the current calendar day, and the start
# date is 30 day prior to the current date.  These computed values exist to
# support routine (cron-scheduled) runs of the script.  The computed values
# are overridden in practice by specifying override values for the variables
# 'startDate' and 'endDate' in the main script itself, and these values must be
# updated each time the script is to be (re)run manually.
#
# Only those site overpasses within the user-specified date range which are
# identified as 'rainy' will be configured in the daily control files to be run.
# Event criteria are as defined in the table "rainy100inside100" in the "gpmgv"
# database, whose contents are updated by an SQL query command file run in this
# script as a default option.  Event definition includes cases where the DPR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-DPR product.  See the SQL command file
# ${BIN_DIR}/'rainCases100kmAddNewEvents.sql'.
#
# SYNOPSIS
# --------
#
#    do_DPR2GR_GeoMatch_snow.sh [OPTION]...
#
#
#    OPTIONS/ARGUMENTS:
#    -----------------
#    -i INSTRUMENT_ID       Override default INSTRUMENT_ID (DPR) to the specified
#                           INSTRUMENT_ID (Ka or Ku).  This determines which type of
#                           2A product will be processed in the matchups.  STRING type.
#
#    -v PPS_VERSION         Override default PPS_VERSION to the specified PPS_VERSION.
#                           This determines which version of the 2A product will be
#                           processed in the matchups.  STRING type.
#
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET.#                           This defines which version "V" of the IDL batch file#                           dpr2gr_prematch_V.bat is to be used in processing matchups.#                           This value also gets written to the geo_match_product table#                           in the gpmgv database as a descriptive attribute.  It's up#                           to the user to keep track of its use and meaning in relation#                           to the configured parameters in the dpr2gr_prematch_V.bat#                           files. See do_DPR2GR_geo_matchup4date_snow.sh for details.#                           INTEGER type.
#
#    -m GEO_MATCH_VERSION   Override default GEO_MATCH_VERSION to the specified
#                           GEO_MATCH_VERSION.  This only changes if the IDL code that
#                           produces the output netCDF file now produces a new or
#                           different version of the matchup file.  If the value of
#                           GEO_MATCH_VERSION is not the same as the version encoded in
#                           the output netCDF filename a fatal error occurs.  FLOAT type.
#
#    -f                     If specified, then instruct matchup programs to create
#                           and overwrite any existing matchups for a date even if
#                           the database says they have been run already (see NOTE).
#                           Takes no argument value.
#
# NOTE:  When running dates that might have already had DPR-GV matchup sets
#        run, the child script do_DPR2GR_geo_matchup4date_snow.sh will skip
#        processing for these dates, as a check of the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_matchIIAll', where II is the value
#        of $INSTRUMENT and the rest of the characters (geo_match and All) are
#        fixed and literal values, for the date(s) to be run, or for all dates.
#        EXCEPTION:  If script is called with the -f option
#        (e.g., "do_DPR2GR_GeoMatch_snow.sh -f"), then the status of prior runs
#        for the set of dates configured in the script will be ignored and
#        the matchups will be re-run, possibly overwriting the existing files.
#
#        The SWATH variable has the fixed value "All" in this script, as the
#        IDL procedure dpr2gr_prematch.pro automatically runs matchup for all
#        the scan types present in the 2A product type being processed.
#    
#
# PRECONDITIONS
# -------------
# Since this script relies on the existence of previously-volume-matched ground
# radar data in "GRtoDPR_HS_MS_NS" netCDF files, do_GR_HS_MS_NS_GeoMatch_snow.sh
# must already have been configured and successfully run over the start and
# end date range configured in this script.  Neither this script nor its child
# script do_DPR2GR_geo_matchup4date_snow.sh check for the pre-existence of these
# GRtoDPR_HS_MS_NS netCDF files.
#
# 3/25/2016   Morris       - Created from do_DPR_GeoMatch.sh.
# 10/5/2016   Morris       - Cleanup and additional documentation.
#                          - Dropped the unused yymmdd argument to function
#                            catalog_to_db().
#                          - Renamed variable SWATH to SCAN in function to
#                            distinguish it from variable used in main script.
#                          - Dropped the unused/disabled optional arguments.
# 2/14/2017   Morris       - Added definition and export of ITE_or_Operational
#                            environment variable.
# 6/19/2017   Morris       - Changed default PPS_VERSION value to "V05A".
# 8/31/2018   Berendes     - Added new snow equivalent RR fields and changed
#							 version to 1.22
#
###############################################################################

# set up the default and override configuration parameters

USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
  elif [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
  elif [ "$USER_ID" = "tberendes" ]
      then
        GV_BASE_DIR=/home/tberendes/git/gpmgv/todd
  else
      echo "User unknown, can't set GV_BASE_DIR!"
      exit 1
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

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/do_DPR2GR_GeoMatch_snow.${rundate}.log
export rundate

PPS_VERSION="V06A"         # specifies default PPS version of products to process
export PPS_VERSION
PARAMETER_SET=2  # default set of dpr2gr_prematch parameters (dpr2gr_prematch.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="DPR"        # default type of DPR 2A products to process: DPR, Ka, or Ku
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
SWATH="All"
# TAB 8/30/18 changed version to 1.22 from 1.21 for new snow equivalent RR fields
GEO_MATCH_VERSION=1.22     # current GRtoDPR netCDF matchup file version output by IDL
export GEO_MATCH_VERSION

# Set up to ALWAYS skip call to psql with SQL_BIN, must have already been done
# by do_GR_HS_MS_NS_GeoMatch_snow.sh, otherwise we might attempt additional "rainy"
# events/dates with no precomputed GR matchups:
SKIP_NEWRAIN=1

# If FORCE_MATCH is set to 1, ignore appstatus for date(s) and force (re)run of
# matchups by child script do_DPR2GR_geo_matchup4date_snow.sh:
FORCE_MATCH=0

# *************  UNSET THIS! *******************
SKIP_CATALOG=0   # if 1, skip call to catalog_to_db, THIS IS FOR TESTING PURPOSES ONLY

# override coded defaults with any optional user-specified values
while getopts i:v:p:m:f option
  do
    case "${option}"
      in
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        f) FORCE_MATCH=1;;
        *) echo "Usage: "
           echo "do_DPR2GR_GeoMatch_snow.sh -i INSTRUMENT -v PPS_Version -p ParmSet " \
                "-m GeoMatchVersion -f"
           exit 1
    esac
done

ALGORITHM=2A$INSTRUMENT_ID
export ALGORITHM

# extract the first character of the PPS_VERSION and set and export it as a
# flag for the IDL batch script to determine whether we are processing ITE or
# operational data, and set the top-level path to the data files accordingly

ITE_or_Operational=`echo $PPS_VERSION | cut -c1`
export ITE_or_Operational

COMBO=${SAT_ID}_${INSTRUMENT_ID}_${ALGORITHM}_${SWATH}

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL dpr2gr_prematch procedure as
# listed in the do_DPR2GR_geo_matchup_catalog.yymmdd.txt file, which was produced
# by do_DPR2GR_geo_matchup4date_snow.sh by examining its own log file for date yymmdd, 
# 'do_DPR2GR_geo_matchup4date_snow.yymmdd.log'. Parses the output netCDF file names to
# extract individual identifying fields, formats fields into a row of data for
# the 'geo_match_product' table in the 'gpmgv' database, and loads the entries
# to the database by calling the 'psql' utility with the fixed SQL command file
# catalog_geo_match_products.sql.

DBCATALOGFILE=$1
SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql
echo "Cataloging new matchup files listed in $DBCATALOGFILE"

# This same file definition (loadfile, below) is also used in the ad-hoc script
# catalog_geo_match_products.sh, and also has the same definition in an SQL
# command in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the path, name, or format must be coordinated in all
# three files AND IN ANY OTHER SCRIPTS THAT CALL psql TO EXECUTE
# catalogGeoMatchProducts.unl.  For instance, in do_GR_HS_MS_NS_GeoMatch.sh.

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

   # NEED TO EXTRACT THE SCAN TYPE OUT OF THE FILE NAMES AS MULTIPLE SCANS
   # ARE RUN AUTOMATICALLY.
    SCAN=`echo ${ncfile} | cut -f7 -d '.'`

    # check for mismatch between input/coded geo_match_version and matchup file version
    VERSION_FILENAME=`echo ${ncfile} | cut -f8 -d '.' | sed 's/_/./'`
    if [ `expr $VERSION_FILENAME = $GEO_MATCH_VERSION` = 0 ]
      then
        echo "Mismatch between script GEO_MATCH_VERSION ("${GEO_MATCH_VERSION}\
") and file GEO_MATCH_VERSION ("${VERSION_FILENAME}")"
#      exit 1
    fi
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${VERSION_FILENAME}|1|${INSTRUMENT_ID}|${SAT_ID}|${SCAN}"
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
   # call 'psql' with the predefined SQL command file to load the rows of data
   # in "loadfile" to the database
    echo "\i $SQL_BIN2" | psql -a -d gpmgv >> $LOG_FILE 2>&1
    tail $LOG_FILE | grep INSERT
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
echo "SAT_ID: $SAT_ID" | tee -a $LOG_FILE
echo "INSTRUMENT_ID: $INSTRUMENT_ID" | tee -a $LOG_FILE
echo "PPS_VERSION: $PPS_VERSION" | tee -a $LOG_FILE
echo "PARAMETER_SET: $PARAMETER_SET" | tee -a $LOG_FILE
echo "ALGORITHM: $ALGORITHM" | tee -a $LOG_FILE
#echo "SWATH: $SWATH" | tee -a $LOG_FILE
#echo "SKIP_NEWRAIN: $SKIP_NEWRAIN" | tee -a $LOG_FILE
echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE
echo "ITE_or_Operational: $ITE_or_Operational" | tee -a $LOG_FILE
echo "COMBO: $COMBO" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""
# configure some SQL constraint values based on GPM product type
case $COMBO
  in
    GPM_DPR_2ADPR_All) echo "$COMBO OK" 
                       MAX_DIST=250  # max radar-to-subtrack distance for overlap
                       MATCHTYPE=DPR ;;
    GPM_Ku_2AKu_All)   echo "$COMBO OK" 
                       MAX_DIST=250
                       MATCHTYPE=DPR ;;
    GPM_Ka_2AKa_All)   echo "$COMBO OK" 
                       MAX_DIST=150
                       MATCHTYPE=DPR ;;
    *) echo "Illegal Satellite/Instrument/Algorithm/Swath combination: $COMBO" \
       | tee -a $LOG_FILE
       echo "Exiting with error." | tee -a $LOG_FILE
       exit 1
esac
echo "Max Dist: $MAX_DIST" | tee -a $LOG_FILE

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

# Build a list of dates with precip events as defined in rainy100inside100 table
# where the GPM orbit also passes within MAX_DIST km of the ground radar.
# Modify the query to consider a specific range of dates/orbits.  Limit this
# to the past 30 days (unless overridden by specifying dateStart and dateEnd).
# Note that startDate through endDate-1 are inclusive, whereas events for
# endDate itself are (typically) excluded.

datelist=${TMP_DIR}/doGeoMatchSelectedDates_temp.txt
rm -v $datelist

# get today's YYYYMMDD, format it as dateEnd
ymd=`date -u +%Y%m%d`
dateEnd=`echo $ymd | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -30`
dateStart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

# OK, override the automatic date setup above and just specify the start
# and end dates here in the code for an ad-hoc run.  Or to use the automatic
# dates (such as running this script on a cron or in a data-driven mode), just
# comment out the next 2 lines.
#dateStart='2018-02-23'
#dateEnd='2018-02-24'

#dateStart='2017-11-01'
#dateEnd='2018-05-01'

#dateStart='2018-11-01'
#dateEnd='2019-02-19'
#dateStart='2018-12-23'
#dateEnd='2019-01-01'

#dateStart='2014-03-18'
#dateEnd='2019-04-22'

dateStart='2019-04-13'
dateEnd='2019-05-24'

echo "Running DPRtoGR matchups from $dateStart to $dateEnd" | tee -a $LOG_FILE

# GET THE LIST OF QUALIFYING 'RAINY' DATES FOR THIS MATCHUP CONFIGURATION.
# We ignore the usual clause "left outer join geo_match_product" since
# SWATH="All" has no meaning to the entries in this table and the returned
# pathname would always be null.  Meaning that we don't know if one or more of
# the intended GRtoDPR netCDF output files already exists based on the entries
# in the "geo_match_product" table.  Exclude events for orbit subsets where we
# have no routine ground radar acquisition (probably need to add to this list
# of excluded subsets!).

DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c \
"SELECT DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
from eventsatsubrad_vw c JOIN orbit_subset_product o \
  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
   and o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
   and c.subset NOT IN ('KOREA','KORA') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' > '${dateStart}' \
   and c.overpass_time at time zone 'UTC' < '${dateEnd}' \
JOIN rainy100inside100 r on (c.event_num=r.event_num) order by 1;"`

#echo "2014-03-19" > $datelist   # edit/uncomment to just run a specific date
#echo "2015-01-08" > $datelist   # edit/uncomment to just run a specific date
#echo "2015-01-06" > $datelist   # edit/uncomment to just run a specific date

#cat /home/tberendes/snowrate/darwin_dates.txt > $datelist

# darw test
#echo "2014-12-29" > $datelist

echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates one at a time, build an IDL control file for each date,
# and run the day's matchups.

for thisdate in `cat $datelist`
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`

   # Define files to hold the delimited output from the database queries needed for
   # the control files driving the matchup data file creation in the IDL routines.
   # ['filelist'] ('outfile') gets overwritten each time psql is called in the
   # loop over the [dates] (files for a date), so their content is copied in
   # append manner to 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/DPR_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/DPR_files_sites4geoMatch_temp.txt

   # tag is used to distinguish the type and date of matchups to be executed
    tag=${ALGORITHM}.${SWATH}.${PPS_VERSION}.${yymmdd}
   # define the pathname of the final control file for the date and type
    outfileall=${TMP_DIR}/DPR_files_sites4geoMatch.${tag}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of this date's 2Axxx files to process and their control file
   # metadata, format the partial file paths, and write to intermediate file
   # $filelist as '|' delimited data.  These lines of data will comprise the
   # satellite-product-specific lines in the control file.
   # -- Corresponding 2B-DPRGMI file is ignored for now
   # We leave out the usual clause "left outer join geo_match_product",
   # since SWATH="All" has no meaning to the entries in this table,
   # and the returned pathname would always be null

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
       '${yymmdd}', c.subset, d.version, '${INSTRUMENT_ID}', '${SWATH}', \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename\
       as file2a \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
        AND d.version = '$PPS_VERSION' \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
     group by 1,3,4,5,6,7,8 \
     order by c.orbit"`  | tee -a $LOG_FILE 2>&1

#echo ''
#echo "filelist:"
#cat $filelist
#echo ''

   # - Step through the satellite-specific control metadata and, for each line,
   #   get the ground-radar-specific control file metadata for the site overpass
   #   events where precip is occurring for this satellite/orbit/subset.
   # - We now use temp tables and sorting by time difference between overpass_time and
   #   radar nominal time (nearest minute) to handle where the same radar_id comes up
   #   more than once for an orbit.  We also exclude UF file matches for RHI scans.
   # - Again, we leave out the usual clause "left outer join geo_match_product",
   #   since SWATH="All" has no meaning to the entries in this table and the
   #   returned pathname would always be null

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
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num\
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
            and c.version = '$PPS_VERSION' \
          order by 3,9;
          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
            from timediftmp group by 1 order by 1;
          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
        | tee -a $LOG_FILE 2>&1

# this was at end of middle where clause, caused error in control file
#            AND C.FILE1CUF NOT LIKE '%rhi%' \

#        date | tee -a $LOG_FILE 2>&1

       # Append the satellite-product-specific line followed by the
       # ground-radar-specific control file line(s) to this date's control file
       # ($outfileall) as instructions for IDL to do DPR-GR matchup file creation.
        echo ""  | tee -a $LOG_FILE
        echo "Control file additions:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
        echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

echo ""
echo "Output control file:"
ls -al $outfileall
#exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper script, do_DPR2GR_geo_matchup4date_snow.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_DPR2GR_geo_matchup4date_snow.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_DPR2GR_geo_matchup4date_snow.sh -f $FORCE_MATCH $yymmdd $outfileall

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_DPR2GR_geo_matchup4date_snow.sh"\
             | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_DPR2GR_geo_matchup4date_snow.sh
            DBCATALOGFILE=${TMP_DIR}/do_DPR2GR_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                if [ "$SKIP_CATALOG" = "0" ]
                  then
                	 catalog_to_db $DBCATALOGFILE
                  else
                     echo "Skipping Cataloging of matchup file for testing..."| tee -a $LOG_FILE
                fi
              else
                echo "but no matchup files listed in $DBCATALOGFILE !"\
                 | tee -a $LOG_FILE
                #exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_DPR2GR_geo_matchup4date_snow.sh, quitting!"\
             | tee -a $LOG_FILE
            exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_DPR2GR_geo_matchup4date_snow.sh, do nothing!"\
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

# Block of code to allow us to step through the matchups one day at a time with
# the option to quit.  Currently disabled, does all dates w/o prompting.

#    echo "Continue to next date? (Y or N):"
#    read -r go_on
    go_on=Y
    if [ "$go_on" != 'Y' -a "$go_on" != 'y' ]
      then
         if [ "$go_on" != 'N' -a "$go_on" != 'n' ]
           then
             echo "Illegal response: ${go_on}, exiting." | tee -a $LOG_FILE
         fi
         echo "Quitting on user command." | tee -a $LOG_FILE
         exit
    fi

done

exit
