#!/bin/sh
###############################################################################
#
# doGeoMatch4NewRainCases.sh    Morris/SAIC/GPM GV    March 2010
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
# 9/18/2008   Morris         Created from doGrids4Select100in100Cases.sh
# 12/2/2008   Morris         - Added capability to automatically determine the
#                            starting date of new data to process by looking at
#                            what files are in /data/netcdf/geo_match dir.
#                            - Eliminated duplicate no-data-file rows for RGSN
#                            due to the multiple PR subset hits for RGSN.
# 11/11/2010  Morris         Added 2A23 filename to the query/control file.
# 3/14/2011   Morris         - Created from doGeoMatch4SelectCases_w2A23.sh.  This
#                            version is meant to be fully automatable.
#                            - Incorporated PR_VERSION parameter and
#                            geo_match_product table into all the queries to do
#                            matchups only for cases not cataloged already.
# 4/29/2011   Morris         - Changed pr_version column name to pps_version to
#                            match the changes to the geo_match_product table
#                            for TMI matchup product addition and incorporated
#                            new column 'instrument_id' (=PR) into the queries
#                            and the output for new table schema.
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv
export DATA_DIR
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR
TMP_DIR=${DATA_DIR}/tmp
export TMP_DIR
#GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PR_VERSION=7        # controls which PR products we process
export PR_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET

# set id of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="PR"
export INSTRUMENT_ID

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/doGeoMatch4NewRainCases.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2pr procedure, as
# listed in the do_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_geo_matchup4date.sh by examining the do_geo_matchup4date.yymmdd.log file. 
# Formats catalog entry for the geo_match_product table in the gpmgv database,
# and loads the entries to the database.

YYMMDD=$1
MATCHUP_LOG=${LOG_DIR}/do_geo_matchup4date.${YYMMDD}.log
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
   # PR_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
   # GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PR_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
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

echo "Starting PR and GR matchup netCDF generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# update the list of rainy overpasses in database table 'rainy100inside100'
if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
  else
    echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the query to just run grids for range of dates/orbits.  Limit ourselves
# to the past 30 days, else we pick up a lot of unwanted cases for V6 vs V7 
# studies, etc.  Also, filter out sites KMXX, KWAJ, RGSN, RMOR for which we have
# no GR data

datelist=${DATA_DIR}/tmp/doGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -30`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
echo "Running PRtoGR matchups for dates since $datestart" | tee -a $LOG_FILE

DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "select distinct \
  date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
from collatedprproductswsub c left outer join geo_match_product b \
  on (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version \
      and b.instrument_id='${INSTRUMENT_ID}') \
  join rainy100inside100 a on (a.orbit=c.orbit AND a.radar_id=c.radar_id) \
where pathname is null and c.radar_id = 'RJNI' and \
  c.version=$PR_VERSION order by 1;"`
#  c.overpass_time at time zone 'UTC' > '${datestart}' and c.version=$PR_VERSION order by 1;"`

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

for thisdate in `cat $datelist`
#for thisdate in '2012-12-01'
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`

   # files to hold the delimited output from the database queries comprising the
   # control files for the 1C21/2A23/2A25/2B31 grid creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${DATA_DIR}/tmp/PR_filelist4geoMatch_temp.txt
    outfile=${DATA_DIR}/tmp/PR_files_sites4geoMatch_temp.txt
    outfileall=${DATA_DIR}/tmp/PR_files_sites4geoMatch.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of PR 1C21/2A23/2A25/2B31 files to process, put in file $filelist
   # -- 2B31 file presence is considered optional for now

   # Added "and file1c21 is not null" to WHERE clause to eliminate duplicate rows
   # for RGSN's mapping to two subsets. Morris, 12/2008

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select file1c21, \
       COALESCE(file2a23, 'no_2A23_file') as file2a23, file2a25, \
       COALESCE(file2b31, 'no_2B31_file') as file2b31,\
       c.orbit, count(*), '${yymmdd}', subset, version \
     from collatedPRproductswsub c left outer join geo_match_product b on \
       (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}') \
       join rainy100inside100 a on (a.orbit=c.orbit AND a.radar_id=c.radar_id) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
       and file1c21 is not null and pathname is null and version = $PR_VERSION \
       and c.radar_id ='RJNI' \
     group by file1c21, file2a23, file2a25, file2b31, c.orbit, subset, version \
     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1

    date | tee -a $LOG_FILE 2>&1

   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do PR and GV grid file creation.
   #  For now will order by radar_id and have IDL handle where the same radar_id
   #  comes up more than once for a case.
# query using collatedGVproducts_kwajcal1 for orbits during 2008-2009-2010, due to
# different cataloging (product ID is 1CUF-cal for cal version of product).
# Currently includes orbits between 57747 and 74696.  Query using collatedGVproducts
# for orbits prior to this, then modify path from 1CUF to 1CUF-cal with 'sed'

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f5 -d '|'`
        subset=`echo $row | cut -f8 -d '|'`
	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
            extract(EPOCH from date_trunc('second', d.overpass_time)), \
            b.latitude, b.longitude, \
            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
          from overpass_event a, fixed_instrument_location b, \
	    collatedGVproducts c, rainy100inside100 d, collatedprproductswsub p \
            left outer join geo_match_product e on \
              (p.radar_id=e.radar_id and p.orbit=e.orbit and \
               p.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}')
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	    and a.radar_id = d.radar_id and a.radar_id = p.radar_id \
	    and a.orbit = c.orbit and a.orbit = d.orbit and a.orbit = p.orbit \
            and a.orbit = ${orbit} and c.subset = '${subset}' and c.subset=p.subset
            and cast(d.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and a.radar_id ='RJNI' \
            and pathname is null and version = $PR_VERSION order by 3;"` \
        | tee -a $LOG_FILE 2>&1

        date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
       # copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
       # use this option for KWAJ 1CUFs cataloged under 1CUF-cal -- orbit > 577746
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
       # use this option for KWAJ 1CUFs cataloged only under 1CUF, modify dir path to 1CUF-cal
#        cat $outfile | sed 's[/1CUF/[/1CUF-cal/[' | tee -a $outfileall  | tee -a $LOG_FILE
    done

#    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_geo_matchup.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_geo_matchup4date.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_geo_matchup4date.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_geo_matchup_catalog.${yymmdd}.txt
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
            echo "FAILURE status returned from do_geo_matchup4date.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_geo_matchup4date.sh, do nothing!"\
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

done

exit
