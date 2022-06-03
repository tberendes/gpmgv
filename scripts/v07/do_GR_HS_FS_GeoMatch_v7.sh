#!/bin/sh
###############################################################################
#
# do_GR_HS_FS_GeoMatch_v7.sh    Morris/SAIC/GPM GV    March 2016
#
# Wrapper to do GR geometric matchups to HS, FS scans in 2A-DPR files V7 and greater
# already received and cataloged, for cases meeting predefined criteria.  This
# script drives volume matches of GR data to DPR footprint locations for all
# of the DPR scan types.  The DPR-matched GR data are written to event-specific
# "GRtoDPR_HS_FS" netCDF files that hold the GR matchups for all three types
# of DPR scans in a single file.  These matchup files are specific to GR site,
# GPM orbit, PPS processing version of the input 2A-DPR data, and matchup file
# definition version (currently 7.0).  Output of this script and its called
# processes consists of a set of intermediate netCDF files containing ground
# radar data only, volume-matched to all (HS, FS) DPR scan types.
# Ancillary output is a series of 'control files', one per day in the range of
# dates to be processed, listing DPR and ground radar data files to be processed
# for rainy site overpass events for that calendar date, as well as metadata
# parameters related to the DPR and GR data and the site overpass events.
#
# A run of this script should be followed up with one or more runs of
# do_DPR2GR_GeoMatch.sh for the same range of dates to complete the creation of
# baseline GRtoDPR netCDF files containing both volume-matched DPR and GR data.
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
#    do_GR_HS_FS_GeoMatch_v7.sh [OPTION]...
#
#
#    OPTIONS/ARGUMENTS:
#    -----------------
#    -v PPS_VERSION         Override default PPS_VERSION to the specified PPS_VERSION.
#                           This determines which version of the 2ADPR product will be
#                           processed in the matchups.  STRING type.
#
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET.
#                           This defines which version "V" of the IDL batch file
#                           polar2dpr_hs_fs_V.bat is to be used in processing matchups.
#                           This value also gets written to the geo_match_product table
#                           in the gpmgv database as a descriptive attribute.  It's up
#                           to the user to keep track of its use and meaning in relation#                           to the configured parameters in the polar2dpr_hs_fs_V.bat#                           files. See do_GR_HS_FS_geo_matchup4date_v7.sh for details.#                           INTEGER type.
#
#    -m GEO_MATCH_VERSION   Override default GEO_MATCH_VERSION to the specified
#                           GEO_MATCH_VERSION.  This only changes if the IDL code that
#                           produces the output netCDF file now produces a new or
#                           different version of the matchup file.  If the value of
#                           GEO_MATCH_VERSION is not the same as the version encoded in
#                           the output netCDF filename a fatal error occurs.  FLOAT type.
#
#    -k                     If specified, skip the step of updating the rain events in
#                           the rainy100inside100 table.  Takes no argument value.
#
#    -f                     If specified, then instruct matchup programs to create
#                           and overwrite any existing matchups for a date even if
#                           the database says they have been run already (see NOTE).
#                           Takes no argument value.
#
#	-n	NPOL_MD or NPOL_WA	Specify NPOL MD or WA
#   -r  SITE_ID             Limit to specific radar site					
#
#	-s	"YYYY-MM-DD" 	    Specify starting date				
#	-e	"YYYY-MM-DD" 	    Specify ending date				
#    
#
# NOTE:  When running dates that have already had GR->DPR matchup sets run,
#        the child script do_GR_HS_FS_geo_matchup4date_v7.sh will skip
#        processing for these dates, as its query of the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match_GRx3', either for the date(s)
#        to be run, or for all dates.  EXCEPTION:  If script is called with the
#        -f option (e.g., "do_GR_HS_FS_GeoMatch_v7.sh -f"), then the status of
#        prior runs for the set of dates configured in the script is ignored and
#        the matchups will be re-run, possibly overwriting the existing files.
#
# 3/17/2016   Morris       - Created from do_DPR_GeoMatch.sh.
# 8/30/2016   Morris       - Modified queries to eliminate temp tables where
#                            possible now that schema has changed.
# 10/5/2016   Morris       - Cleanup and additional documentation.
#                          - Dropped the unused yymmdd argument to function
#                            catalog_to_db().
#                          - Dropped the useless -s SAT_ID option.
# 2/14/2017   Morris       - Added definition and export of ITE_or_Operational
#                            environment variable.
# 9/13/2018   Berendes 	   - Fixed behaviour of -f to force re-run dates and files
#						     when defining the day list and filelists, now all files
# 							 on the specified days will be reprocessed regardless
#                            of their previous states as I think this was originally
#							 intended, the left outer join and "g.pathname is null"
#							 clauses caused the flag to be ignored
# 3/2/2021	Berendes		 Added NPOL logic
#							 Added starting and ending date parameters
# 5/18/2021 Berendes		 Changed names and logic for V7 GPM scans and new format
# 4/29/2022 Berendes	  - set Force_flag to true, ignoring command line arg
#                           and the appstatus check.  The check just added confusion
#	                        for our processing workflow and since dates are now 
#                           always specified this check is really unnecessary.
# 5/31/2022 Berendes		Added freezing level function and code to append freezing level
#                           to the control file
#
###############################################################################

echo ''
echo ''
echo '***************************************'
echo ' ***  STARTING' $0  '***'
date
echo '***************************************'
echo ''


USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
  elif [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
  elif [ "$USER_ID" = "tberendes" ]
      then
        GV_BASE_DIR=/home/tberendes/v7_geomatch
  elif [ "$USER_ID" = "dberendes" ]
      then
        GV_BASE_DIR=/home/dberendes/v7_geomatch
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
SOUNDINGS_TOP_DIR=/data/gpmgv/soundings

SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V07A"   # specifies which PPS version of products to process
#PPS_VERSION="ITE757"   # specifies which PPS version of products to process
export PPS_VERSION
PARAMETER_SET=1  # set of polar2dpr_hs_fs parameters (polar2dpr_hs_fs.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="DPR"       # type of DPR 2A products to process: DPR only, herein
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID

SWATH="All3"   # do not change this
export SWATH
# - Note that appstatus table entries for the child script do_GR_HS_FS_geo_matchup4date_v7.sh
#   use the fixed app_id value 'geo_match_GRx3', not something based on $SWATH.

GEO_MATCH_VERSION=2.1     # current GRtoDPR_HS_FS netCDF matchup file definition version, 
# must match version in gen_gr_hsfs_geo_match_netcdf_v7.pro
export GEO_MATCH_VERSION

SKIP_NEWRAIN=0   # if 1, skip call to psql with SQL_BIN to update "rainy" events

# *************  UNSET THIS! *******************
SKIP_CATALOG=0   # if 1, skip call to catalog_to_db, THIS IS FOR TESTING PURPOSES ONLY

# If $FORCE_MATCH is set to 1, ignore appstatus for date(s) and force (re)run of
# matchups by child script do_GR_HS_FS_geo_matchup4date_v7.sh:
FORCE_MATCH=0
NPOL_SITE=""
DO_NPOL=0
DO_START_DATE=0
DO_END_DATE=0
SITE_ID=""
DO_SITE=0

# override coded defaults with any optional user-specified values
while getopts v:p:m:n:r:s:e:kf option
  do
    case "${option}"
      in
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        n) NPOL_SITE=${OPTARG}
           DO_NPOL=1;;
        r) SITE_ID=${OPTARG}
           DO_SITE=1;;
        s) starting_date=${OPTARG}
           DO_START_DATE=1;;
        e) ending_date=${OPTARG}
           DO_END_DATE=1;;
        k) SKIP_NEWRAIN=1;;
        f) FORCE_MATCH=1;;
        *) echo "Usage: "
           echo "do_GR_HS_FS_GeoMatch.sh -v PPS_Version -p Parameter_Set " \
                "-m GeoMatchVersion -n (NPOL_MD or NPOL_WA) " \
                " -s \"YYYY-MM-DD\" -e \"YYYY-MM-DD\" -[k|f]"
           exit 1
    esac
done

FORCE_MATCH=1    # ignore appstatus for date(s) and (re)run matchups, this is done now to avoid confusion

ALGORITHM=2A$INSTRUMENT_ID
export ALGORITHM

# extract the first character of the PPS_VERSION and set and export it as a
# flag for the IDL batch script to determine whether we are processing ITE or
# operational data and set the top-level path to the data files accordingly

ITE_or_Operational=`echo $PPS_VERSION | cut -c1`
export ITE_or_Operational

COMBO=${SAT_ID}_${INSTRUMENT_ID}_${ALGORITHM}_${SWATH}

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/do_GR_HS_FS_GeoMatch_v7.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2dpr_hs_fs procedure
# as listed in the do_GR_HS_FS_geo_matchup_catalog.yymmdd.txt file, which was
# produced by do_GR_HS_FS_geo_matchup4date_v7.sh by examining its own log file,
# do_GR_HS_FS_geo_matchup4date_v7.yymmdd.log, for the date yymmdd.  Parses the
# output netCDF file names to extract individual identifying fields, formats
# the 'geo_match_product' table in the 'gpmgv' database, and loads the entries
# fields into a row of data for to the database by calling the 'psql' utility
# with the fixed SQL command file catalog_geo_match_products.sql.

DBCATALOGFILE=$1
SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql
echo "Cataloging new matchup files listed in $DBCATALOGFILE"

# This same file definition (loadfile, below) is also used in the ad-hoc script
# catalog_geo_match_products.sh, and also has the same definition in an SQL
# command in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the path, name, or format must be coordinated in all
# three files AND IN ANY OTHER SCRIPTS THAT CALL psql TO EXECUTE
# catalogGeoMatchProducts.unl.  For instance, in do_DPR2GR_GeoMatch.sh.

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
    VERSION_FILENAME=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
#echo "GEO_MATCH_VERSION ${GEO_MATCH_VERSION}  VERSION_FILENAME ${VERSION_FILENAME}"
    # check for mismatch between input/coded geo_match_version and matchup file version
    if [ `expr $VERSION_FILENAME = $GEO_MATCH_VERSION` = 0 ]
      then
        echo "Mismatch between script GEO_MATCH_VERSION ("${GEO_MATCH_VERSION}\
") and file GEO_MATCH_VERSION ("${VERSION_FILENAME}")"
#      exit 1
    fi
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${VERSION_FILENAME}|1|${INSTRUMENT_ID}|${SAT_ID}|${SWATH}"
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
    echo "\i $SQL_BIN2" | psql -a -d gpmgv >> $LOG_FILE 2>&1
    tail $LOG_FILE | grep INSERT
fi

return
}
################################################################################
function findfreezinglevel() {

  havebotm=0
  while read sndlevel
    do
      echo $sndlevel | grep '\.' > /dev/null
      if [ $? = 1 ]
        then
          continue
      fi
      hgttemp=`echo $sndlevel | grep '\.' | sed 's/  */ /g' | cut -f2-3 -d ' '`
      hgt=`echo $hgttemp | cut -f1 -d ' '`
      temp=`echo $hgttemp | cut -f2 -d ' '`
      echo $temp | grep '-' > /dev/null
      if [ $? = 1 ]
        then
          botmhgt=$hgt
          botmtemp=$temp
          havebotm=1
        else
          tophgt=$hgt
          toptemp=$temp
          break
      fi
  done < $1
  if [ $havebotm = 1 ]
    then
#      echo botmhgt, botmtemp, tophgt, toptemp: $botmhgt, $botmtemp, $tophgt, $toptemp
      dh=$(echo "scale = 4; $tophgt-$botmhgt" | bc)
      dt=$(echo "scale = 4; $toptemp-$botmtemp" | bc)
      bbHeight_km=$(echo "scale = 2; $tophgt - $toptemp * $dh / $dt" | bc)
      bbHeight=$(echo "scale = 2; $bbHeight_km / 1000.0" | bc)
    else
#      echo tophgt, toptemp: $tophgt, $toptemp
      bbHeight=$(echo "scale = 2; $tophgt / 1000.0" | bc)
  fi
#  echo bbHeight: $bbHeight
  local theHeight=$bbHeight
  echo "$theHeight"
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
echo "SWATH: $SWATH" | tee -a $LOG_FILE
echo "SKIP_NEWRAIN: $SKIP_NEWRAIN" | tee -a $LOG_FILE
echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE
echo "ITE_or_Operational: $ITE_or_Operational" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""
case $COMBO
  in
    GPM_DPR_2ADPR_All3)  echo "$COMBO OK" 
                         MAX_DIST=250
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

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`
dateEnd=`echo $ymd | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -30`
dateStart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

if [ "$DO_START_DATE" = "1" ]
  then
     dateStart=$starting_date
fi
if [ "$DO_END_DATE" = "1" ]
  then
     dateEnd=$ending_date
fi

# OK, override the automatic date setup above and just specify the start
# and end dates here in the code for an ad-hoc run.  Or to use the automatic
# dates (such as running this script on a cron or in a data-driven mode), just
# comment out the next 2 lines.

#dateStart='2020-02-01'
#dateEnd='2020-02-02'
#dateStart='2016-07-13'
#dateEnd='2016-07-14'

echo "Running GR to DPR matchups from $dateStart to $dateEnd" | tee -a $LOG_FILE

# GET THE LIST OF QUALIFYING 'RAINY' DATES FOR THIS MATCHUP CONFIGURATION.
# Exclude events for orbit subsets where we have no routine ground radar
# acquisition (probably need to add to this list of excluded subsets!),
# and events where the entries in the geo_match_product table indicate that the
# corresponding output matchup file (pathname attribute) already exists.

site_filter=""
if [ "$DO_NPOL" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${NPOL_SITE}')"	
fi
if [ "$DO_SITE" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${SITE_ID}')"	
fi

# TAB MODIFIED 9/13/18, changed the date check to select dates even when the
# previous matchups are found on a date when using the -f (FORCE_MATCH) option

if [ "$FORCE_MATCH" = "1" ]
  then
     previous_match_filter=""
else
     previous_match_filter="WHERE g.pathname is null"
fi
  
	DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c \
	"SELECT DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
	from eventsatsubrad_vw c JOIN orbit_subset_product o \
	  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
	   and o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
	   and c.subset NOT IN ('KOREA','KORA') and c.nearest_distance<=${MAX_DIST} \
	   and c.overpass_time at time zone 'UTC' >= '${dateStart}' \
	   and c.overpass_time at time zone 'UTC' < '${dateEnd}' ${site_filter} \
	LEFT OUTER JOIN geo_match_product g on (c.event_num=g.event_num and \
	   o.version=g.pps_version and g.instrument_id='${INSTRUMENT_ID}' and \
	   g.parameter_set=${PARAMETER_SET} and g.scan_type='${SWATH}' and g.geo_match_version=${GEO_MATCH_VERSION} ) \
	JOIN rainy100inside100 r on (c.event_num=r.event_num) \
	${previous_match_filter} order by 1 ;"`
	
#	echo ''
#	echo "SELECT DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
#	from eventsatsubrad_vw c JOIN orbit_subset_product o \
#	  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
#	   and o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
#	   and c.subset NOT IN ('KOREA','KORA') and c.nearest_distance<=${MAX_DIST} \
#	   and c.overpass_time at time zone 'UTC' >= '${dateStart}' \
#	   and c.overpass_time at time zone 'UTC' < '${dateEnd}' ${site_filter} \
#	LEFT OUTER JOIN geo_match_product g on (c.event_num=g.event_num and \
#	   o.version=g.pps_version and g.instrument_id='${INSTRUMENT_ID}' and \
#	   g.parameter_set=${PARAMETER_SET} and g.scan_type='${SWATH}' and g.geo_match_version=${GEO_MATCH_VERSION} ) \
#	JOIN rainy100inside100 r on (c.event_num=r.event_num) \
#	${previous_match_filter} order by 1 ;"
	
echo ''

#echo "2014-03-18" > $datelist   # edit/uncomment to just run a specific date

#echo "2014-03-18" > $datelist   # edit/uncomment to just run a specific date
#echo "2015-07-18 2017-10-24 2017-12-01 2017-12-05 2018-01-05 2018-01-25 2018-02-10 2018-02-25 2018-03-06" > $datelist

echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

    
if [ "$DO_NPOL" = "0" ]
  then
   collate="collate_satsubprod_1cuf"	
else
   if [ $NPOL_SITE = "NPOL_WA" ]
     then
 	   collate="collate_npol_wa_1cuf"	       
   else
 	   collate="collate_npol_md_1cuf"	
   fi
fi
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

   # 'tag' is used to distinguish the type and date of matchups to be executed
    tag=${ALGORITHM}.${SWATH}.${PPS_VERSION}.${yymmdd}
   # define the pathname of the final control file for the date and type
    outfileall=${TMP_DIR}/DPR_files_sites4geoMatch.${tag}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of this date's DPR files to process and their control file
   # metadata, format the partial file paths, and write to intermediate file
   # $filelist as '|' delimited data.  These lines of data will comprise the
   # satellite-product-specific lines in the control file.
   # -- 2B-DPRGMI file is left out for now

# TAB MODIFIED 9/13/18, changed the date check to select dates even when the
# previous matchups are found when using the -f (FORCE_MATCH) option

if [ "$FORCE_MATCH" = "1" ]
  then
     previous_match_filter=""
else
     previous_match_filter="and b.pathname is null"
fi

	    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
	       '${yymmdd}', c.subset, d.version, '${INSTRUMENT_ID}', '${SWATH}', \
	'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
	||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename\
	       as file2a \
	       from eventsatsubrad_vw c \
	     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
	        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
	        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
	        AND d.version = '$PPS_VERSION' ${site_filter} \
	     left outer join geo_match_product b on \
	      ( c.event_num=b.event_num and d.version=b.pps_version \
	        and b.instrument_id = '${INSTRUMENT_ID}' and b.parameter_set=${PARAMETER_SET} \
	        and b.geo_match_version=${GEO_MATCH_VERSION} and b.scan_type='${SWATH}' ) \
	       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
	     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' ${previous_match_filter} \
	     group by 1,3,4,5,6,7,8 \
	     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1
	
#	echo "select c.orbit, count(*), \
#	       '${yymmdd}', c.subset, d.version, '${INSTRUMENT_ID}', '${SWATH}', \
#	'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
#	||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename\
#	       as file2a \
#	       from eventsatsubrad_vw c \
#	     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
#	        AND c.subset = d.subset AND c.sat_id='$SAT_ID' and c.subset NOT IN ('KOREA','KORA') \
#	        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST}\
#	        AND d.version = '$PPS_VERSION' ${site_filter} \
#	     left outer join geo_match_product b on \
#	      ( c.event_num=b.event_num and d.version=b.pps_version \
#	        and b.instrument_id = '${INSTRUMENT_ID}' and b.parameter_set=${PARAMETER_SET} \
#	        and b.geo_match_version=${GEO_MATCH_VERSION} and b.scan_type='${SWATH}' ) \
#	       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
#	     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' ${previous_match_filter} \
#	     group by 1,3,4,5,6,7,8 \
#	     order by c.orbit;" 
     
echo "filelist:"
cat $filelist
echo ''

   # - Step through the satellite-specific control metadata and, for each line,
   #   get the ground-radar-specific control file metadata for the site overpass
   #   events where precip is occurring for this satellite/orbit/subset.
   # - We now use temp tables and sorting by time difference between overpass_time
   #   and radar nominal time (nearest minute) to handle where the same radar_id
   #   comes up more than once for an orbit.  We also exclude UF file matches for RHI scans.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f1 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`

	# TAB MODIFIED 9/13/18, changed the date check to select dates even when the
	# previous matchups are found when using the -f ($FORCE_MATCH) option
	
if [ "$FORCE_MATCH" = "1" ]
  then
     previous_match_filter=""
else
     previous_match_filter="and e.pathname is null"
fi

		DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
	            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
	            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
	            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
	          into temp timediftmp \
	          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
		    ${collate} c \
	            left outer join geo_match_product e on \
	              (c.radar_id=e.radar_id and c.orbit=e.orbit and \
	               c.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}' \
	               and e.parameter_set=${PARAMETER_SET} and e.sat_id='${SAT_ID}' \
	               and e.geo_match_version=${GEO_MATCH_VERSION}) and e.scan_type='${SWATH}' \
	          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
	            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num \
	            and a.orbit = ${orbit} and c.subset = '${subset}' \
	            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}' \
	            and c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
	            and c.version = '$PPS_VERSION' ${previous_match_filter} ${site_filter} \
	            AND C.FILE1CUF NOT LIKE '%rhi%' \
	          order by 3,9; \
	          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
	            from timediftmp group by 1 order by 1; \
	          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
	                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b \
	                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
	        | tee -a $LOG_FILE 2>&1
	        
# this clause will cause some files to be filtered out of list returned by query, and count 
# returned in the first psql query (DBOUT2) will not be correct.  
#	            AND C.FILE1CUF NOT LIKE '%rhi%' \

		# when we add in filtering by filename pattern, i.e. eliminate rhi GR scans, need to reset the count
		# in the current "row" to the number of files returned, if there is not a non-rhi file within the time interval,
	    # then the "count" in the "DBOUT2" query will not match the count of the entries returned by the "DBOUT3" query
	    # and the control file will not parse properly.  Therefore, we need to update the count after the new list is 
	    # returned from DBOUT3 query, and handle if the list is empty, need to skip row if file count is zero after filtering
		# e.g. row="38725|3|201221|AUS-East|V06A|DPR|All3|GPM/DPR/2ADPR/V06A/AUS-East/2020/12/21/2A-CS-AUS-East.GPM.DPR.V8-20180723.20201221-S232856-E233753.038725.V06A.HDF5"
		
		cnt=`cat $outfile | wc -l`
		#echo "filtered count = " $cnt
     	orbit=`echo $row | cut -d"|" -f "1"`
     	orig_cnt=`echo $row | cut -d"|" -f "2"`
		if [ "$cnt" != "$orig_cnt" ]
  		then
  			echo "Filtered rhi files from orbit ${orbit}"
  			echo "original radar file count = $orig_cnt new count = $cnt"
  		fi
     	
		if [ "$cnt" = "0" ]
  		then
     		echo "All radar files filtered for orbit ${orbit}, skipping..."
		else
     		f3_8=`echo $row | cut -d"|" -f "3-8"`
     		new_row=`echo ${orbit}"|"${cnt}"|"${f3_8}`
     		#echo $new_row
#        date | tee -a $LOG_FILE 2>&1

       		# Append the satellite-product-specific line followed by the
       		# ground-radar-specific control file line(s) to this date's control file
       		# ($outfileall) as instructions for IDL to do GR-to-DPR matchup file creation.
        	echo ""  | tee -a $LOG_FILE
        	echo "Control file additions:"  | tee -a $LOG_FILE
        	echo ""  | tee -a $LOG_FILE
        	echo $new_row | tee -a $outfileall  | tee -a $LOG_FILE
        	# TAB 5/27/22
        	# add in processing to append freezing level info to control file:
        	while read outline
        	  do
        		orbit=`echo $outline | cut -f2 -d '|'`
        		site=`echo $outline | cut -f3 -d '|'`
        		datetime=`echo $outline | cut -f4 -d '|'`
    			if [ "$site" = "KWAJ" ] # round to nearest day at zero Z
    			   then
    			   	  NEXT_DATE=$(date +"%Y-%m-%d %H:%M:%S" -ud "${datetime} UTC + 12 hour")
    			   	  year=`echo $NEXT_DATE | cut -f1 -d '-'`
    			   	  mmdd=`echo $NEXT_DATE | cut -f2-3 -d '-' | sed 's/-//' | cut -f1 -d' '`
    			   	  hh="00"
    			      # format the matching sounding's file pathname
    				  sndfile=${SOUNDINGS_TOP_DIR}/${year}/${mmdd}/${site}/${site}_${year}_${mmdd}_${hh}UTC.txt
    				  ls -al $sndfile > /dev/null
    				  if [ $? -ne 0 ] # check to see if file exists, if not set date to truncated previous date
    				     then
			               #echo "Notice: Missing sounding file for ${site} ${orbit} ${datetime}" | tee -a $LOG_FILE
			               #echo "Trying previous date..."
    			   	       year=`echo $datetime | cut -f1 -d '-'`
    			   	       mmdd=`echo $datetime | cut -f2-3 -d '-' | sed 's/-//' | cut -f1 -d' '`				        
    				  fi
    			   else # round to nearest hour
    			   	  NEXT_DATE=$(date +"%Y-%m-%d %H:%M:%S" -ud "${datetime} UTC + 30 minute")
    			   	  year=`echo $NEXT_DATE | cut -f1 -d '-'`
    			   	  mmdd=`echo $NEXT_DATE | cut -f2-3 -d '-' | sed 's/-//' | cut -f1 -d' '`
    			   	  hh=`echo $NEXT_DATE | cut -f2 -d ' ' | cut -f1 -d ':'`
    			      # format the matching sounding's file pathname
    				  sndfile=${SOUNDINGS_TOP_DIR}/${year}/${mmdd}/${site}/${site}_${year}_${mmdd}_${hh}UTC.txt
    				  ls -al $sndfile > /dev/null
    				  if [ $? -ne 0 ] # check to see if file exists, if not set date to truncated previous date
    				     then
			               #echo "Notice: Missing sounding file for ${site} ${orbit} ${datetime}" | tee -a $LOG_FILE
			               #echo "Trying previous date..."
    			   	       year=`echo $datetime | cut -f1 -d '-'`
    			   	       mmdd=`echo $datetime | cut -f2-3 -d '-' | sed 's/-//' | cut -f1 -d' '`				        
    			   	  	   hh=`echo $datetime | cut -f2 -d ' ' | cut -f1 -d ':'`
    				  fi
    			   
    			   fi    			   
    			# format the matching sounding's file pathname
    			sndfile=${SOUNDINGS_TOP_DIR}/${year}/${mmdd}/${site}/${site}_${year}_${mmdd}_${hh}UTC.txt
    			ls -al $sndfile > /dev/null
    			if [ $? -eq 0 ]
			      then
			        # call function to compute the freezing level height (m)
			        freezing_level=`findfreezinglevel $sndfile`
			        #echo "site, orbit, freezing level: ${site}|${orbit}|${freezing_level}"
			        echo $freezing_level | grep '\.' > /dev/null
			        if [ $? -eq 0 ]
			          then
			            # write site, orbit, and freezing level Height to $bbfile as delimited text
			            #echo "freezing level height: $freezing_level km for ${site} ${orbit} ${datetime}" | tee -a $LOG_FILE
			            echo "${outline}|${freezing_level}" | tee -a $outfileall | tee -a $LOG_FILE
			          else
			            #echo "Notice: freezing level height could not be computed from sounding file for ${site} ${orbit} ${datetime}"| tee -a $LOG_FILE
			            echo "${outline}|-9999." | tee -a $outfileall | tee -a $LOG_FILE
			          fi
			      else
			            #echo "Notice: Missing sounding file for ${site} ${orbit} ${datetime}" | tee -a $LOG_FILE
			            echo "${outline}|-9999." | tee -a $outfileall | tee -a $LOG_FILE			      
			      fi
        	done < $outfile
        	
        	#cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
		fi
    done

echo ""
echo "Output control file:"
ls -al $outfileall
echo "Exiting for test..."
cat $outfileall
exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper script, do_GR_HS_FS_geo_matchup4date_v7.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_GR_HS_FS_geo_matchup4date_v7.sh $yymmdd on $start1" | tee -a $LOG_FILE
# default do_GR_HS_FS_geo_matchup4date_v7.sh to set $FORCE_MATCH to 1 so every date is processed by default
#        ${BIN_DIR}/do_GR_HS_FS_geo_matchup4date_v7.sh -f $FORCE_MATCH $yymmdd $outfileall
        ${BIN_DIR}/do_GR_HS_FS_geo_matchup4date_v7.sh -f 1 $yymmdd $outfileall

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_GR_HS_FS_geo_matchup4date_v7.sh"\
             | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_GR_HS_FS_geo_matchup4date_v7.sh
            DBCATALOGFILE=${TMP_DIR}/do_GR_HS_FS_geo_matchup_catalog.${yymmdd}.txt
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
            echo "FAILURE status returned from do_GR_HS_FS_geo_matchup4date_v7.sh, quitting!"\
             | tee -a $LOG_FILE
            exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_GR_HS_FS_geo_matchup4date_v7.sh, do nothing!"\
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

echo ''
echo ''
echo '***************************************'
echo ' ***  DONE' $0  '***'
date
echo '***************************************'
echo ''

exit
