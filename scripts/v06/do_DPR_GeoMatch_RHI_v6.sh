#!/bin/sh
###############################################################################
#
# do_DPR_GeoMatch_NPOL_MD_rules.sh    Morris/SAIC/GPM GV    March 2015
#
# Wrapper to do DPR-GR geometric matchups for 2ADPR/2AKa/2AKu and NPOL 1CUF
# files already received and cataloged, for cases meeting predefined criteria.
#
# This script only does volume matches for between the NPOL radar and the GPM
# DPR product types, for GPM overpass cases of the NPOL installation at Wallops,
# indicated by a GR site ID "NPOL_MD".  This site ID is hard-coded and cannot be
# overridden.
#
# This version of the script uses the 'gpmgv' database VIEW collate_npol_md_1cuf
# to find the matching 1CUF ground radar data file for the event.  These files
# are all cataloged under the site ID "NPOL", while the overpass and rain event
# criteria are cataloged under the site ID "NPOL_MD".  The view attempts to
# account for the site ID disconnect between the different database tables
# involoved in generating the control files, but does not always succeed in
# finding the correct matching NPOL 1CUF file for the event.  To handle this,
# this "special" script brings up each new control file in the editor 'gedit'
# and waits while the user makes any required manual changes to the control file
# to replace missing or incorrect NPOL 1CUF file placeholders with the correct
# matching 1CUF filenames. Once editing is complete and the editor is dismissed# the script will allow the user to choose either to proceed with the matchups# for this control file or skip the matchup step and go to the next date.
## This script drives volume matches between DPR and ground radar (GR) data for
# a single user-specified DPR scan type to produce the baseline "GRtoDPR"
# matchup netCDF files.  This script queries the 'gpmgv' database to find rainy
# site overpass events between a specified start and end date and assembles a
# series of date-specific control files to run matchups for those dates.  For
# each date, calls the child script do_DPR_geo_matchup4date_v6.sh, which in turn
# invokes IDL to generate the GRtoDPR volume match netCDF files for that day's
# rainy overpass events as listed in the daily control file.  Ancillary output
# from the script is a series of 'control files', one per day in the range of
# dates to be processed, listing DPR and ground radar data files to be processed
# for rainy site overpass events for that calendar date, as well as metadata
# parameters related to the DPR and GR data and the site overpass events.
#
# Volume matches are done for only one DPR 2A file type (2A-DPR, 2A-Ka, or
# 2A-Ku) at a time, and for only one scan type in that 2A data type.  The
# 2A-DPR contains 3 scan types (HS, MS, NS), the 2A-Ka contains 2 (HS, MS),
# and the 2A-Ku only contains the NS scan type.
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
#    do_DPR_GeoMatch_NPOL_MD_rules.sh [OPTION]...
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
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET.
#                           This defines which version "V" of the IDL batch file
#                           polar2dpr_V.bat is to be used in processing matchups.
#                           This value also gets written to the geo_match_product table
#                           in the gpmgv database as a descriptive attribute.  It's up
#                           to the user to keep track of its use and meaning in relation
#                           to the configured parameters in the polar2dpr_V.bat files.
#                           See do_DPR_geo_matchup4date_v6.sh for details.  INTEGER type.
#
#    -w SWATH               Override the default DPR scan type (NS) to another
#                           scan type (either MS or HS), as applicable to the current
#                           INSTRUMENT_ID.  See the COMBO variable in the script.
#
#    -m GEO_MATCH_VERSION   Override default GEO_MATCH_VERSION to the specified
#                           GEO_MATCH_VERSION.  This only changes if the IDL code that
#                           produces the output netCDF file now produces a new or
#                           different version of the matchup file.  If the value of
#                           GEO_MATCH_VERSION is not the same as the version encoded in
#                           the output netCDF filename an error is noted.  FLOAT type.
#	-n	NPOL_MD or NPOL_WA	Specify NPOL MD or WA
#   -r  SITE_ID             Limit to specific radar site					
#
#	-s	"YYYY-MM-DD" 	    Specify starting date				
#	-e	"YYYY-MM-DD" 	    Specify ending date				
#
#    -k                     If specified, skip the step of updating the rain events in
#                           the rainy100inside100 table.  Takes no argument value.
#
#
# NOTE:  When running dates that might have already had DPR-GR matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match_IISS', where II is the value
#        of $INSTRUMENT and SS is the value of $SWATH, either for the date(s)
#        to be run, or for all dates.  EXCEPTION:  If script is called with the
#        -f option (e.g., "do_DPR_GeoMatch_NPOL_MD_rules.sh -f"), then the status
#        of prior runs for the dates configured in the script will be ignored and
#        the matchups will be re-run, possibly overwriting the existing files.
#
#        - By default, processes matchups for the site ID 'NPOL_MD' only.
#          This cannot be changed unless a different VIEW than 
#          collate_npol_md_1cuf is coded in SQL and defined in the 'gpmgv'
#          database.
#
# late 2014    Morris      - Created from do_DPR_GeoMatch.sh.
# 3/27/2014    Morris      - Modified to bring up each new control file in the
#                            'gedit' editor and pause to allow the user to
#                            manually fix missing radar file pathnames before
#                            proceeding to do_DPR_geo_matchup4date.sh to run
#                            the matchups in IDL.
# 2/14/2017   Morris       - Added definition and export of ITE_or_Operational
#                            environment variable, and expanded prologue.
# 8/8/2017    Morris       - Changed default PPS_VERSION value to V05A.
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
        GV_BASE_DIR=/home/tberendes/v6_geomatch
  elif [ "$USER_ID" = "dberendes" ]
      then
        GV_BASE_DIR=/home/dberendes/v6_geomatch
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

PPS_VERSION="V06A"    # default for version of DPR products to process
export PPS_VERSION
PARAMETER_SET=1       # set of polar2dpr parameters (polar2dpr.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="DPR"   # default product to match up, can override to Ka or Ku
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
SWATH="NS"   # default scan type to match up, can override to HS or MS (if Ka or DPR)
GEO_MATCH_VERSION=1.21

SKIP_NEWRAIN=0   # if 1, skip call to psql with SQL_BIN
# hardcode to ignore previous runs, otherwise, no-rhi matchups will be seen as previously run 
# and the rhi runs will not work
FORCE_MATCH=1    # if 1, ignore appstatus for date(s) and (re)run matchups
DO_RHI=1         # if 1, then matchup to RHI UF files
NULL_SKIP=0      # if 1, then disable NULL check for geo_match_product
NPOL_SITE=""
DO_NPOL=0
DO_START_DATE=0
DO_END_DATE=0
SITE_ID=""
DO_SITE=0

# override coded defaults with user-specified values
#while getopts i:v:p:d:w:m:kfrn option
while getopts i:v:p:s:e:d:r:n:w:m:kf option
  do
    case "${option}"
      in
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        w) SWATH=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        k) SKIP_NEWRAIN=1;;
        f) FORCE_MATCH=1
           NULL_SKIP=1;;
#        r) DO_RHI=1;;
        r) SITE_ID=${OPTARG}
           DO_SITE=1;;
        n) NPOL_SITE=${OPTARG}
           DO_NPOL=1;;
        s) starting_date=${OPTARG}
           DO_START_DATE=1;;
        e) ending_date=${OPTARG}
           DO_END_DATE=1;;
#        n) NULL_SKIP=1;;
    esac
done

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
echo "SAT_ID: $SAT_ID" | tee -a $LOG_FILE
export SAT_ID
echo "INSTRUMENT_ID: $INSTRUMENT_ID" | tee -a $LOG_FILE
export INSTRUMENT_ID
echo "PPS_VERSION: $PPS_VERSION" | tee -a $LOG_FILE
export PPS_VERSION
echo "PARAMETER_SET: $PARAMETER_SET" | tee -a $LOG_FILE
export PARAMETER_SET
echo "ALGORITHM: $ALGORITHM" | tee -a $LOG_FILE
echo "SWATH: $SWATH" | tee -a $LOG_FILE
export SWATH
echo "GEO_MATCH_VERSION: $GEO_MATCH_VERSION" | tee -a $LOG_FILE
export GEO_MATCH_VERSION
echo "SKIP_NEWRAIN: $SKIP_NEWRAIN" | tee -a $LOG_FILE
echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE
echo "DO_RHI: $DO_RHI" | tee -a $LOG_FILE
echo "NULL_SKIP: $NULL_SKIP" | tee -a $LOG_FILE
echo "ITE_or_Operational: $ITE_or_Operational" | tee -a $LOG_FILE
echo "COMBO: $COMBO" | tee -a $LOG_FILE
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

echo "Max Dist: $MAX_DIST" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

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

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the query to just run grids for range of dates/orbits.  Limit ourselves
# to the past 30 days.

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
#echo $dateStart

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
	
	
	echo "psql -a -A -t -o $datelist -d gpmgv -c \
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
	${previous_match_filter} order by 1 ;"
	

#echo "2014-09-07" > $datelist   # edit/uncomment to just run a specific date

echo ""
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

   # files to hold the delimited output from the database queries comprising the
   # control files for the 2ADPR/Ka/Ku-GR matchup creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/DPR_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/DPR_files_sites4geoMatch_temp.txt
    tag=RHI.${ALGORITHM}.${SWATH}.${PPS_VERSION}.${yymmdd}
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
	            AND C.FILE1CUF LIKE '%rhi%' \
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
  			echo "Filtered non-rhi files from orbit ${orbit}"
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
        	cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
		fi
    done

	if [ -s $outfileall ]
	   	then
			echo ""
			echo "Output control file:"
			ls -al $outfileall
		else
			echo ""
			echo "No RHI files for date ${yymmdd}, skipping..."
	fi
#exit  # if uncommented, creates the control file for first date, and exits
# invoke editor to allow user to supply a radar file manually if none can
# be found within the time window (allows for larger "slop" in time interval)
# gedit $outfileall

#   echo "Continue to IDL matchup step? (Y or N):"
#    read -r bail
#    if [ "$bail" != 'Y' -a "$bail" != 'y' ]
#      then
#        if [ "$bail" != 'N' -a "$bail" != 'n' ]
#          then
#            echo "Illegal response: ${bail}, skipping." | tee -a $LOG_FILE
#        fi
#        echo "Skipping IDL matchup step on user command." | tee -a $LOG_FILE
#      else
        if [ -s $outfileall ]
          then
           # Call the IDL wrapper script, do_DPR_geo_matchup4date_v6.sh, to run
           # the IDL .bat files.  Let each of these deal with whether the yymmdd
           # has been done before.

            echo "" | tee -a $LOG_FILE
            start1=`date -u`
            echo "Calling do_DPR_geo_matchup4date_v6.sh $yymmdd on $start1" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
#            ${BIN_DIR}/do_DPR_geo_matchup4date_v6.sh -f $FORCE_MATCH -r $DO_RHI $yymmdd $outfileall
            ${BIN_DIR}/do_DPR_geo_matchup4date_v6.sh -f 1 -r $DO_RHI $yymmdd $outfileall

            case $? in
              0 )
                echo ""
                echo "SUCCESS status returned from do_DPR_geo_matchup4date_v6.sh"\
                 | tee -a $LOG_FILE
               # extract the pathnames of the matchup files created this run, and 
               # catalog them in the geo_matchup_product table.  The following file
               # must be identically defined here and in do_DPR_geo_matchup4date_v6.sh
#  Skip catalog since RHI scans are not unique from PPI scans
#                DBCATALOGFILE=${TMP_DIR}/do_DPR_geo_matchup_catalog.${yymmdd}.txt
#                if [ -s $DBCATALOGFILE ] 
#                  then
##                    catalog_to_db $yymmdd $DBCATALOGFILE
#                  else
#                    echo "but no matchup files listed in $DBCATALOGFILE !"\
#                     | tee -a $LOG_FILE
#                    #exit 1
#                fi
              ;;
              1 )
                echo ""
                echo "FAILURE status returned from do_DPR_geo_matchup4date_v6.sh, quitting!"\
                 | tee -a $LOG_FILE
                exit 1
              ;;
              2 )
                echo ""
                echo "REPEAT status returned from do_DPR_geo_matchup4date_v6.sh, do nothing!"\
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
#    fi
#
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
