#!/bin/sh
###############################################################################
#
# do_DPRGMI_GeoMatch_v7.sh    Morris/SAIC/GPM GV    June 2014
#
# DESCRIPTION
# -----------
# Wrapper to do DPRGMI-GR NetCDF geometric matchups for GPM 2B-DPRGMI files# already received and cataloged, for cases meeting predefined criteria.  This# script drives volume matches between DPRGMI and ground radar (GR) data for# both the MS and NS scan type and Ka and Ku instruments to produce the baseline # "GRtoDPRGMI" matchup netCDF files.  Queries the 'gpmgv' database to find rainy# site overpass events between a specified start and end date and assembles a# series of date-specific control files to run matchups for those dates.  For# each date, calls the child script do_DPRGMI_geo_matchup4date_v7.sh, which in turn# invokes IDL to generate the GRtoDPRGMI volume match netCDF files for that day's# rainy overpass events as listed in the daily control file.  Ancillary output# from the script is a series of 'control files', one per day in the range of# dates to be processed, listing DPR and ground radar data files to be processed# for rainy site overpass events for that calendar date, as well as metadata# parameters related to the DPR and GR data and the site overpass events.# # Volume matches are done for MS and NS scan types for Ku data, and MS only for# the Ka data.  Data for all scan types and frequencies are contained in the# GRtoDPRGMI netCDF matchup data files.  These files are not split out by scan# type and frequency as the 2A-DPR/Ka/Ku matchups are.# # The script has logic to compute the start and end dates over which to attempt# volume match runs.  The end date is the current calendar day, and the start# date is 30 day prior to the current date.  These computed values exist to# support routine (cron-scheduled) runs of the script.  The computed values# are overridden in practice by specifying override values for the variables# 'startDate' and 'endDate' in the main script itself, and these values must be# updated each time the script is to be (re)run manually.# # Only those site overpasses within the user-specified date range which are# identified as 'rainy' will be configured in the daily control files to be run.# Event criteria are as defined in the table "rainy100inside100" in the "gpmgv"# database, whose contents are updated by an SQL query command file run in this# script as a default option.  Event definition includes cases where the DPR# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar# within the 4km gridded 2A-DPR product.  See the SQL command file# ${BIN_DIR}/'rainCases100kmAddNewEvents.sql'.#
#
# SYNOPSIS
# --------
#
#    do_DPRGMI_GeoMatch_v7.sh [OPTION]...
#
#
#    OPTIONS/ARGUMENTS:
#    -----------------
#    -v PPS_VERSION         Override default PPS_VERSION to the specified PPS_VERSION.
#                           This determines which version of the 2B product will be
#                           processed in the matchups.  STRING type.
#
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET
#                           This tracks which version of IDL batch file was used in
#                           processing matchups, when changes are made to the batch file.
#                           This value also gets written to the geo_match_product table
#                           in the gpmgv database as a descriptive attribute.  It's up
#                           to the user to keep track of its use and meaning.
#                           INTEGER type.
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
#                           Option is disabled, but internally set to always skip the
#                           updates under the assumption that updates were already
#                           done by a prerequisite run of do_GR_HS_MS_NS_GeoMatch.sh.
#
#    -f                     If specified, then instruct matchup programs to create
#                           and overwrite any existing matchups for a date even if
#                           the database says they have been run already (see NOTE).
#                           Takes no argument value.
#
#    -c                     If specified, then configure to just create the control
#                           files for the date range and defer running the volume
#                           matches.  This helps support the mode where two
#                           different machines might work simultaneously, running
#                           volume matches for different dates.  See the related
#                           script: do_DPRGMI_GeoMatch_from_ControlFiles.sh
#
#	-n	NPOL_MD or NPOL_WA	Specify NPOL MD or WA					
#   -r  SITE_ID             Limit to specific radar site					
#	-s	"YYYY-MM-DD" 	    Specify starting date				
#	-e	"YYYY-MM-DD" 	    Specify ending date				
#
# # NOTE:  When running dates that might have already had DPRGMI-GR matchup sets#         run, the called script will skip these dates, as the 'appstatus' table#         will say that the date has already been done.  Delete the entries#         from this table where app_id='geo_match_COMB', either for the date(s)#         to be run, or for all dates.  EXCEPTION:  If script is called with the#         -f option (e.g., "do_DPRGMI_GeoMatch_v7.sh -f"), then the status of prior#         runs for the set of dates configured in the script will be ignored and#         the matchups will be re-run, possibly overwriting the existing files.# 
#
# HISTORY
# -------
# 6/3/2014   Morris         Created from do_GMI_GeoMatch4NewRainCases.sh.
# 7/12/2016  Morris         Added '-c' option to skip matchup/cataloging steps.
#                           Changed location of control files to CTL_DIR.
# 10/7/2016  Morris       - Cleanup and additional documentation.
#                         - Dropped the unused yymmdd argument to function
#                           catalog_to_db().
#                         - Removed script options that should never change.
# 2/14/2017   Morris      - Added definition and export of ITE_or_Operational
#                           environment variable.
#                         - Added logic to configure GV_BASE_DIR by user ID.
#                         - Changed BIN_DIR to ${GV_BASE_DIR}/scripts/matchup
#                           for user gvoper's usage.
# 3/2/2021	Berendes		 Added NPOL logic
#							 Added starting and ending date parameters
#
###############################################################################
echo ''
echo ''
echo '***************************************'
echo ' ***  STARTING' $0  '***'
date
echo '***************************************'
echo ''


# set up the default and override configuration parameters

USER_ID=`whoami`

#if [ "$USER_ID" = "morris" ]
#  then
#    GV_BASE_DIR=/home/morris/swdev
#  else
#    if [ "$USER_ID" = "gvoper" ]
#      then
#        GV_BASE_DIR=/home/gvoper
#      else
#        echo "User unknown, can't set GV_BASE_DIR!"
#        exit 1
#    fi
#fi

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

DATA_DIR=/data/gpmgv
export DATA_DIR
TMP_DIR=/data/tmp
export TMP_DIR
LOG_DIR=/data/logs
export LOG_DIR
#BIN_DIR=${GV_BASE_DIR}/scripts/matchup
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR

SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql
# special rainy100inside100 script to get smaller scale events
#SQL_BIN=${BIN_DIR}/rainCases20in100kmAddNewEvents.sql

PPS_VERSION=ITE761        # default DPRGMI product version to be processed
export PPS_VERSION
PARAMETER_SET=1  # default set of polar2dprgmi_v7 parameters (polar2dprgmi_v7 .bat file) in use
export PARAMETER_SET
MAX_DIST=250  # max radar-to-subtrack distance for overlap

# set ids of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="DPRGMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2BDPRGMI"
export ALGORITHM
GEO_MATCH_VERSION=2.0     # should match latest version of GRtoDPRGMI netCDF file
# must match version in gen_dprgmi_geo_match_netcdf_v7.pro
export GEO_MATCH_VERSION

SKIP_NEWRAIN=0   # if 1, skip call to psql with SQL_BIN
FORCE_MATCH=0    # if 1, ignore appstatus for date(s) and (re)run matchups
DO_RHI=0         # if 1, then matchup to RHI UF files
SKIP_MATCHUPS=0  # if 1, then skip matchups and just do control files

FORCE_MATCH=0
NPOL_SITE=""
DO_NPOL=0
DO_START_DATE=0
DO_END_DATE=0
SITE_ID=""
DO_SITE=0

# override coded defaults with user-specified values
#while getopts v:p:d:m:n:s:e:kfrc option # old options for rhi, not working
while getopts v:p:d:m:r:n:s:e:kfc option
  do
    case "${option}"
      in
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        n) NPOL_SITE=${OPTARG}
           DO_NPOL=1;;
        s) starting_date=${OPTARG}
           DO_START_DATE=1;;
        e) ending_date=${OPTARG}
           DO_END_DATE=1;;
        k) SKIP_NEWRAIN=1;;
        f) FORCE_MATCH=1;;
        r) SITE_ID=${OPTARG}
           DO_SITE=1;;
#        r) DO_RHI=1
#           echo "Option -r (do RHI matchups) is not yet supported."
#           exit 1 ;;
        c) SKIP_MATCHUPS=1;;
        *) echo "Usage: "
           echo "do_DPRGMI_GeoMatch_v7.sh -v PPS_Version -p ParmSet -m GeoMatchVersion -[k|f|r|c]" \
                " -n (NPOL_MD or NPOL_WA) -s YYYY-MM-DD -e YYYY-MM-DD"
           exit 1
    esac
done

# extract the first character of the PPS_VERSION and set and export it as a
# flag for the IDL batch script to determine whether we are processing ITE or
# operational data and set the top-level path to the data files accordingly

ITE_or_Operational=`echo $PPS_VERSION | cut -c1`
export ITE_or_Operational

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/doDPRGMIGeoMatch4NewRainCases_v7.${PPS_VERSION}.${rundate}.log

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2dprgmi_v7 procedure, as
# listed in the do_DPRGMI_geo_matchup_catalog.yymmdd.txt file, in turn produced
# by do_DPRGMI_geo_matchup4date_v7.sh by examining the
# do_DPRGMI_geo_matchup4date.yymmdd.log file. Parses the output netCDF file names
# to extract individual identifying fields, formats fields into a row of data for
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
    PR_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
#    GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|1.0|1|${INSTRUMENT_ID}|${SAT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}|NA"
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

# Begin main script
echo "Starting COMB-GR matchups on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE
echo "SKIP_NEWRAIN: $SKIP_NEWRAIN" | tee -a $LOG_FILE
echo "FORCE_MATCH: $FORCE_MATCH" | tee -a $LOG_FILE
echo "DO_RHI: $DO_RHI" | tee -a $LOG_FILE
echo "SKIP_MATCHUPS: $SKIP_MATCHUPS" | tee -a $LOG_FILE
echo "PARAMETER_SET: $PARAMETER_SET" | tee -a $LOG_FILE
echo "PPS_VERSION: $PPS_VERSION" | tee -a $LOG_FILE
echo "ITE_or_Operational: $ITE_or_Operational" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Define the directory to which the date-specific volume-match control files
# will be written. Create it if needed.
CTL_DIR=${DATA_DIR}/netcdf/geo_match/$SAT_ID/$ALGORITHM/$PPS_VERSION/CONTROL_FILES
export CTL_DIR
mkdir -p $CTL_DIR | tee -a $LOG_FILE
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

# Build a list of dates with precip events as defined in rainy100inside100 table
# where the GPM orbit also passes within MAX_DIST km of the ground radar.
# Modify the query to consider a specific range of dates/orbits.  Limit this
# to the past 30 days (unless overridden by specifying dateStart and dateEnd).
# Note that startDate through endDate-1 are inclusive, whereas events for
# endDate itself are (typically) excluded.

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doCOMBGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`
dateEnd=`echo $ymd | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

# get YYYYMMDD for 90 days ago
#ymdstart=`offset_date $ymd -140`
ymdstart=`offset_date $ymd -90`
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

#echo "Running GRtoDPRGMI matchups for dates since $dateStart" | tee -a $LOG_FILE
echo "Running GRtoDPRGMI matchups from $dateStart to $dateEnd" | tee -a $LOG_FILE

# GET THE LIST OF QUALIFYING 'RAINY' DATES FOR THIS MATCHUP CONFIGURATION.
# Exclude events for orbit subsets where we have no routine ground radar
# acquisition (probably need to add to this list of excluded subsets!).

site_filter=""
if [ "$DO_NPOL" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${NPOL_SITE}')"	
fi
if [ "$DO_SITE" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${SITE_ID}')"	
fi

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
	 AND o.product_type = '${ALGORITHM}' and o.version='${PPS_VERSION}' \
	   and o.sat_id='${SAT_ID}' and c.nearest_distance<=${MAX_DIST} \
	   and c.subset NOT IN ('KOREA','KORA') \
	   and c.overpass_time at time zone 'UTC' >= '${dateStart}' \
	   and c.overpass_time at time zone 'UTC' < '${dateEnd}' ${site_filter} \
	LEFT OUTER JOIN geo_match_product g \
	    on ( c.event_num=g.event_num and g.pps_version='${PPS_VERSION}' \
	         and g.instrument_id='${INSTRUMENT_ID}' \
	         and g.PARAMETER_SET=${PARAMETER_SET} \
	         and g.geo_match_version=${GEO_MATCH_VERSION} )
	JOIN rainy100inside100 r on (c.event_num=r.event_num) \
	 ${previous_match_filter} order by 1 ;"`
#	 WHERE pathname is null order by 1 ;"`

# hardcode datelist to specific dates
#echo "2014-03-18" > $datelist   # edit/uncomment to just run a specific date
#echo "2015-07-18 2017-10-24 2017-12-01 2017-12-05 2018-01-05 2018-01-25 2018-02-10 2018-02-25 2018-03-06" > $datelist

echo " "
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

while read thisdate
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
    echo "yymmdd = $yymmdd"

   # Define files to hold the delimited output from the database queries needed for
   # the control files driving the matchup data file creation in the IDL routines.
   # ['filelist'] ('outfile') gets overwritten each time psql is called in the
   # loop over the [dates] (files for a date), so their content is copied in
   # append manner to 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/COMB_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/COMB_files_sites4geoMatch_temp.txt
    outfileall=${CTL_DIR}/COMB_files_sites4geoMatch_v7.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of this date's 2BDPRGMI files to process and their control file
   # metadata, format the partial file paths, and write to intermediate file
   # $filelist as '|' delimited data.  These lines of data will comprise the
   # satellite-product-specific lines in the control file.

# TAB MODIFIED 2/4/19, changed the date check to select dates even when the
# previous matchups are found when using the -f (FORCE_MATCH) option

if [ "$FORCE_MATCH" = "1" ]
  then
     previous_match_filter=""
else
     previous_match_filter="and b.pathname is null"
fi

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
       '${yymmdd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2b \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        and c.subset NOT IN ('KOREA','KORA') \
        AND d.product_type = '${ALGORITHM}' and c.nearest_distance<=${MAX_DIST} ${site_filter} \
     left outer join geo_match_product b on \
       (c.event_num=b.event_num and d.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}' and b.parameter_set=${PARAMETER_SET} and b.geo_match_version=${GEO_MATCH_VERSION}) \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
        ${previous_match_filter} and d.version = '$PPS_VERSION' \
     group by 1,3,4,5,6,7 \
     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1


# echo "Contents of ${TMP_DIR}/COMB_filelist4geoMatch_temp.txt:"
# cat ${TMP_DIR}/COMB_filelist4geoMatch_temp.txt
# echo "End listing."
#exit

   # - Step through the satellite-specific control metadata and, for each line,
   #   get the ground-radar-specific control file metadata for the site overpass
   #   events where precip is occurring for this satellite/orbit/subset.
   # - We now use temp tables and sorting by time difference between overpass_time and
   #   radar nominal time (nearest minute) to handle where the same radar_id comes up
   #   more than once for an orbit.
   # - We also exclude UF file matches for RHI scans, as there is no support yet
   #   for RHI matchups to the DPRGMI product.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f1 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`
#        echo "${orbit}, $subset, ${INSTRUMENT_ID}, $PPS_VERSION, ${thisdate}"

	# TAB MODIFIED 9/13/18, changed the date check to select dates even when the
	# previous matchups are found when using the -f (FORCE_MATCH) option
	
if [ "$FORCE_MATCH" = "1" ]
  then
     previous_match_filter=""
else
     previous_match_filter="and e.pathname is null"
fi

		DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c \
	       "select a.event_num, a.orbit, a.radar_id, \
	               date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
	               extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
	               b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, \
	               c.file1cuf, c.tdiff \
	          into temp timediftmp \
	          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
		       ${collate} c \
	          left outer join geo_match_product e on \
	              ( c.event_num=e.event_num and c.version=e.pps_version \
	                and e.instrument_id = '${INSTRUMENT_ID}' \
	                and e.parameter_set=${PARAMETER_SET} \
	                and e.geo_match_version=${GEO_MATCH_VERSION} ) \
	          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
	            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num \
	            and a.orbit = ${orbit} and c.subset = '${subset}' \
	            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}' \
	            AND c.product_type = '${ALGORITHM}' and a.nearest_distance <= ${MAX_DIST} \
	            and c.version = '$PPS_VERSION' ${previous_match_filter} ${site_filter} \
	            AND C.FILE1CUF NOT LIKE '%rhi%' \
	          order by 3,9; \
	          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
	            from timediftmp group by 1 order by 1; \
	          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
	                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
	                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
	        | tee -a $LOG_FILE 2>&1
# this was at end of middle where clause, caused error in control file
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

	       # Append the satellite-product-specific line followed by the
	       # ground-radar-specific control file line(s) to this date's control file
	       # ($outfileall) as instructions for IDL to do DPRGMI-GR matchup file creation.
	        echo $new_row >> $outfileall      # DPRGMI orbit subset product line
	        cat $outfile >> $outfileall   # matching ground radar line(s)
	    fi
    done

    echo ""
    echo "Control file ${outfileall} contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE

    #exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall -a "$SKIP_MATCHUPS" = "0" ]
      then
       # Call the IDL wrapper script, do_DPRGMI_geo_matchup_v7.sh, to run
       # the IDL .bat file.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_DPRGMI_geo_matchup4date_v7.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_DPRGMI_geo_matchup4date_v7.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_DPRGMI_geo_matchup4date_v7.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_DPRGMI_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_DPRGMI_geo_matchup_catalog_v7.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db  $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE, quitting!"\
	         | tee -a $LOG_FILE
#                exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_DPRGMI_geo_matchup4date_v7.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_DPRGMI_geo_matchup4date_v7.sh, do nothing!"\
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
      else
        echo "" | tee -a $LOG_FILE
        echo "Skipping matchup step for $yymmdd." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
    fi

done < $datelist

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "See log file: $LOG_FILE"

echo ''
echo ''
echo '***************************************'
echo ' ***  DONE' $0  '***'
date
echo '***************************************'
echo ''

exit
