#!/bin/sh
###############################################################################
#
# do_GMI_GeoMatch_v5.sh    Morris/SAIC/GPM GV    October 2014
#
# DESCRIPTION
# -----------
# Wrapper to do GPROF-GR NetCDF geometric matchups for 2A-GPROF and 1C-R-XCAL# files in the GV data system, for cases meeting predefined criteria.  This# script drives volume matches between GPROF and ground radar (GR) data to
# produce the baseline "GRtoGPROF" matchup netCDF files.  Queries the 'gpmgv'
# database to find rainy site overpass events between a specified start and end
# date and assembles a series of date-specific control files to run matchups for
# those dates.  By default, the GPM GMI 2A-GPROF and 1C-R-XCAL data are used in
# the volume matching, but this script and its called procedures have the
# capability to do matchups against these product types for any constellation
# satellite, since the file formats are the same.  In practice this is not
# feasible, since the matching ground radar data typically are not available
# except for the GPM and TRMM satellites.
## For each date, calls the child script do_GMI_geo_matchup4date_v5.sh, which# invokes IDL to generate the GRtoGPROF volume match netCDF files for that day's# rainy overpass events as listed in the daily control file.  Ancillary output# from the script is a series of 'control files', one per day in the range of# dates to be processed, listing 2A-GPROF, 1C-R-XCAL (if available), and ground
# radar data files to be processed for rainy site overpass events for that# calendar date, as well as metadata parameters related to the GPROF and GR# data and the site overpass events.# # Volume matches are done using the 2A-GPROF data products, and will also# include equivalent blackbody temperature data from the matching (i.e., same# satellite, orbit, orbit subset, and version) 1C-R-XCAL product, if available.# Completed geometry match files are cataloged in the 'gpmgv' database table
# 'geo_match_product'.
# # The script has logic to compute the start and end dates over which to attempt# volume match runs.  The end date is the current calendar day, and the start# date is 30 day prior to the current date.  These computed values exist to# support routine (cron-scheduled) runs of the script.  The computed values# are overridden in practice by specifying override values for the variables# 'startDate' and 'endDate' in the main script itself, and these values must be# updated each time the script is to be (re)run manually.# # Only those site overpasses within the user-specified date range which are# identified as 'rainy' will be configured in the daily control files to be run.# Event criteria are as defined in the table "rainy100inside100" in the "gpmgv"# database, whose contents are updated by an SQL query command file run in this# script as a default option.  Event definition includes cases where the DPR# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar# within the 4km gridded 2A-DPR product.  See the SQL command file# ${BIN_DIR}/'rainCases100kmAddNewEvents.sql'.#
#
# SYNOPSIS
# --------
#
#    do_GMI_GeoMatch.sh [OPTION]...
#
#
#    OPTIONS/ARGUMENTS:
#    -----------------
#    -s SAT_ID              Override default SAT_ID (GPM) to the specified SAT_ID.
#                           This, along with INSTRUMENT_ID, determines which type
#                           of 2AGPROF product will be processed in the matchups.
#                           STRING type.
#
#    -i INSTRUMENT_ID       Override default INSTRUMENT_ID (GMI) to the specified
#                           INSTRUMENT_ID that pertains to the specified SAT_ID.
#                           This determines which type of 2AGPROF product will be
#                           processed in the matchups.  STRING type.
#
#    -v PPS_VERSION         Override default PPS_VERSION to the specified PPS_VERSION.
#                           This determines which version of the 2A/1C products will be
#                           processed in the matchups.  STRING type.
#
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET
#                           This tracks which version of IDL batch file was used in
#                           processing matchups, when changes are made to the batch file.
#                           This value does not actually control anything, but it gets
#                           written to the geo_match_product table in the gpmgv database
#                           as a descriptive attribute.  It's up to the user to keep track
#                           of its use and meaning.  INTEGER type.
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
#	-s	"YYYY-MM-DD" 	    Specify starting date				
#	-e	"YYYY-MM-DD" 	    Specify ending date				
#
# # NOTE:  When running dates that might have already had GPROF-GR matchup sets#         run, the called script will skip these dates, as the 'appstatus' table#         will say that the date has already been done.  Delete the entries#         from this table where app_id='geo_match_gmi', either for the date(s)#         to be run, or for all dates.  EXCEPTION:  If script is called with the#         -f option (e.g., "do_GMI_GeoMatch.sh -f"), then the status of prior#         runs for the set of dates configured in the script will be ignored and#         the matchups will be re-run, possibly overwriting the existing files.# 
#
# 10/7/2014   Morris        Created from doGeoMatch4NewRainCases.sh and
#                           do_DPR_GeoMatch.sh.
# 6/30/2016   Morris        Modified to include 1C-R-XCAL file path on the
#                           satellite data lines.
#                           Do only subsets 'AKradars','CONUS','KWAJ'.
# 7/17/2017   Morris        Changed default PPS_VERSION to V05A.
# 11/6/2018   Berendes	    Added BrazilRadars and Hawaii to subsets
# 3/2/2021	Berendes		 Added NPOL logic
#							 Added starting and ending date parameters
#
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

#PPS_VERSION=V05A        # controls which GMI products we process
PPS_VERSION=V05B        # controls which GMI products we process
PPS_XCAL_VERSION=V05A        # controls which GMI XCAL products we process
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
ALGORITHM2A="2AGPROF"
export ALGORITHM2A
ALGORITHM1C="1CRXCAL"
export ALGORITHM1C
GEO_MATCH_VERSION=1.2
export GEO_MATCH_VERSION

NPOL_SITE=""
DO_NPOL=0
DO_START_DATE=0
DO_END_DATE=0
SITE_ID=""
DO_SITE=0

# override coded defaults with user-specified values
while getopts s:i:v:p:r:n:m:s:e: option
  do
    case "${option}"
      in
#        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
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
    esac
done

# extract the first character of the PPS_VERSION and set and export it as a
# flag for the IDL batch script to determine whether we are processing ITE or
# operational data, and set the top-level path to the data files accordingly

ITE_or_Operational=`echo $PPS_VERSION | cut -c1`
export ITE_or_Operational

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/do_${SAT_ID}${INSTRUMENT_ID}_GeoMatch.${PPS_VERSION}.${rundate}.log

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2tmi procedure, as
# listed in the do_GMI_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_GMI_geo_matchup4date_v5.sh by examining the do_GMI_geo_matchup4date_v5.yymmdd.log 
# file. Formats catalog entry for the geo_match_product table in the gpmgv
# database, and loads the entries to the database.

YYMMDD=$1
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
    radar_id=`echo ${ncfile} | cut -f4 -d '.'`
    orbit=`echo ${ncfile} | cut -f6 -d '.'`
    PR_VERSION=`echo ${ncfile} | cut -f7 -d '.'`
   # GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|1.2|1|${INSTRUMENT_ID}|${SAT_ID}|NA"
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
echo "Starting ${SAT_ID}/${INSTRUMENT_ID}-GR matchups on $rundate." | tee $LOG_FILE
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
# - Excludes orbits whose GMI-GR matchup has already been created/cataloged,
#   and those for which 2A-5x products have not been received yet.

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doGMIGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`
dateEnd=`echo $ymd | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`

# get YYYYMMDD for 90 days ago
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
site_filter=""
if [ "$DO_NPOL" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${NPOL_SITE}')"	
fi
if [ "$DO_SITE" = "1" ]
  then
	site_filter="AND C.RADAR_ID IN ('${SITE_ID}')"	
fi

#dateStart='2020-01-13'
#dateEnd='2020-01-28'

#echo "Running GRtoGMI matchups for dates since $dateStart" | tee -a $LOG_FILE
echo "Running GRtoGMI matchups from $dateStart to $dateEnd" | tee -a $LOG_FILE

# here's a much faster query pair with the "LEFT OUTER JOIN geo_match_product"
# connected to a simple temp table
DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c \
"SELECT DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
from eventsatsubrad_vw c JOIN orbit_subset_product o \
  ON c.orbit = o.orbit AND c.subset = o.subset AND c.sat_id = o.sat_id \
 AND o.product_type = '${ALGORITHM2A}' and o.version='${PPS_VERSION}' and o.sat_id='${SAT_ID}' \
   and c.subset IN ('AKradars','CONUS','KWAJ','BrazilRadars','Hawaii') and c.nearest_distance<=${MAX_DIST} \
   and c.overpass_time at time zone 'UTC' >= '${dateStart}' \
   and c.overpass_time at time zone 'UTC' < '${dateEnd}' ${site_filter} \
JOIN rainy100inside100 r on (c.event_num=r.event_num) \
LEFT OUTER JOIN geo_match_product g on c.event_num=g.event_num \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET} and g.geo_match_version=${GEO_MATCH_VERSION} \
order by 1;"`

# TAB remove null pathname check to allow repeats
#WHERE g.pathname is null order by 1;"`

#echo 'DBOUT: ' $DBOUT

#   and c.subset IN ('AKradars','CONUS','KWAJ') and c.nearest_distance<=${MAX_DIST} \
#echo "2014-09-07" > $datelist
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
   # files to hold the delimited output from the database queries comprising the
   # control files for the GMI-GR matchup file creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${TMP_DIR}/GMI_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/GMI_files_sites4geoMatch_temp.txt
    outfileall=${TMP_DIR}/GMI_files_sites4geoMatch_v5.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of GMI 1CRXCAL and 2AGPROF files to process, put in file $filelist
# TAB 4/4/19, added PPS_XCAL_VERSION that can be different from PPS_VERSION since 
# latest XCAL are still V05A and GPROF are V05B

# here's a much faster query pair with the "LEFT OUTER JOIN geo_match_product"
# connected to a simple temp table
    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select c.orbit, count(*), \
       '${yymmdd}'::text as datestamp, c.subset, d.version, \
       '${INSTRUMENT_ID}'::text as instrument, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM2A}/${PPS_VERSION}/'||d.subset||'/'||to_char(d.filedate,'YYYY')||'/'\
||to_char(d.filedate,'MM')||'/'||to_char(d.filedate,'DD')||'/'||d.filename as file2a, \
'${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM1C}/${PPS_XCAL_VERSION}/'||x.subset||'/'||to_char(x.filedate,'YYYY')||'/'\
||to_char(x.filedate,'MM')||'/'||to_char(x.filedate,'DD')||'/'||x.filename as file1c  \
       from eventsatsubrad_vw c \
     JOIN orbit_subset_product d ON c.sat_id=d.sat_id and c.orbit = d.orbit\
        AND c.subset = d.subset AND c.sat_id='$SAT_ID' \
        AND c.subset IN ('AKradars','CONUS','KWAJ','BrazilRadars','Hawaii') \
        AND d.product_type = '${ALGORITHM2A}' and c.nearest_distance<=${MAX_DIST} ${site_filter} \
       JOIN orbit_subset_product x ON x.sat_id=d.sat_id and x.orbit = d.orbit\
            AND x.subset = d.subset AND x.product_type = '1CRXCAL' and x.version='${PPS_XCAL_VERSION}' \
       LEFT OUTER JOIN geo_match_product b on ( c.event_num=b.event_num \
        and x.version=b.pps_version and b.instrument_id = 'GMI' \
        and b.geo_match_version=${GEO_MATCH_VERSION} and b.parameter_set=${PARAMETER_SET} ) \
       JOIN rainy100inside100 r on (c.event_num=r.event_num) \
      where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
        and d.version = '$PPS_VERSION' \
   group by 1,3,4,5,6,7,8 order by c.orbit;"`

# TAB removed the pathaname null check to allow repeats of date
#        and b.pathname is null and d.version = '$PPS_VERSION' \

#
# TAB 7/8/19, not sure why this was hardcoded originally, changed to varaible
#        and b.geo_match_version=${GEO_MATCH_VERSION} and b.parameter_set=0 ) \

#       AND x.subset = d.subset AND x.product_type = '1CRXCAL' and x.version=d.version \
 #  group by 1,3,4,5,6,7,8 order by c.orbit;"`  | tee -a $LOG_FILE 2>&1
#   echo $DBOUT2   | tee -a $LOG_FILE 2>&1
#        AND c.subset IN ('AKradars','CONUS','KWAJ') \
#echo "Contents of ${TMP_DIR}/GMI_filelist4geoMatch_temp.txt:"
#cat ${TMP_DIR}/GMI_filelist4geoMatch_temp.txt
#echo "End listing."
#exit
   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do GMI-GR matchup file creation.
   #  We now use temp tables and sorting by time difference between overpass_time and
   #  radar nominal time (nearest minute) to handle where the same radar_id
   #  comes up more than once for an orbit.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f1 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`
#        echo "${orbit}, $subset, ${INSTRUMENT_ID}, $PPS_VERSION, ${thisdate}"

	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC') as ovrptime, \
            extract(EPOCH from date_trunc('second', a.overpass_time)) as ovrpticks, \
            b.latitude, b.longitude, trunc(b.elevation/1000.,3) as elev, c.file1cuf, c.tdiff \
          into temp timediftmp
          from overpass_event a, fixed_instrument_location b, rainy100inside100 r, \
	    ${collate} c \
            LEFT OUTER JOIN geo_match_product e on \
              ( c.event_num=e.event_num and c.version=e.pps_version \
                and e.instrument_id = '${INSTRUMENT_ID}' \
                and e.parameter_set=${PARAMETER_SET} \
                and e.geo_match_version=${GEO_MATCH_VERSION}) \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id  \
            and a.orbit = c.orbit  and c.sat_id='$SAT_ID' and a.event_num=r.event_num \
            and a.orbit = ${orbit} and c.subset = '${subset}'
            and cast(a.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            AND c.product_type = '${ALGORITHM2A}' and a.nearest_distance <= ${MAX_DIST} \
            and c.version = '$PPS_VERSION' ${site_filter} \
	        AND C.FILE1CUF NOT LIKE '%rhi%' \
          order by 3,9;
          select radar_id, min(tdiff) as mintdiff into temp mintimediftmp \
            from timediftmp group by 1 order by 1;
          select a.event_num, a.orbit, a.radar_id, a.ovrptime, a.ovrpticks, \
                 a.latitude, a.longitude, a.elev, a.file1cuf from timediftmp a, mintimediftmp b
                 where a.radar_id=b.radar_id and a.tdiff=b.mintdiff order by 3,9;"` \
        | tee -a $LOG_FILE 2>&1

# TAB removed null pathname check to allow repeats
#            and pathname is null and c.version = '$PPS_VERSION' \
       # copy the temp file outputs from psql to the daily control file

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

        	echo $new_row >> $outfileall
        	cat $outfile >> $outfileall
        fi
    done

    echo ""
    echo "Control file ${outfileall} contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE
#    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_GMI_geo_matchup4date_v5.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_GMI_geo_matchup4date_v5.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_GMI_geo_matchup4date_v5.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_GMI_geo_matchup4date_v5.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date_v5.sh
            DBCATALOGFILE=${TMP_DIR}/do_GMI_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE, quitting!"\
	         | tee -a $LOG_FILE
#                exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_GMI_geo_matchup4date_v5.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_GMI_geo_matchup4date_v5.sh, do nothing!"\
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
