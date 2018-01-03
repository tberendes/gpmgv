#!/bin/sh
###############################################################################
#
# doGeoMatch4SelectCases.sh    Morris/SAIC/GPM GV    September 2008
#
# Wrapper to do PR-GV NetCDF geometric matchups for 1C21/2A25/2B31/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which created and populated the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See file 'rainCases100.sql'.
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
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
#satid="PR"

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/doGrids4SelectCases.${rundate}.log
export rundate

umask 0002

echo "Starting PR and GV netCDF grid generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the orbit number in the subquery to just run grids for new dates/orbits.
# (Is now done inside the script with the smarts below!) Morris, 12/2008
#cd $GEO_NC_DIR
#ncfilemaxorbit=`ls | cut -f4 -d '.' | sort -run | head -1`
#echo "" | tee -a $LOG_FILE
#echo "Last orbit in existing geo_match netCDF file set = $ncfilemaxorbit"\
# | tee -a $LOG_FILE
#echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doGeoMatchSelectedDates_temp.txt
echo "\t \a \f '|' \o $datelist \
  \\\select distinct date(date_trunc('day', overpass_time at time zone 'UTC')) from \
  collatedprproductswsub where orbit in \
  (select distinct orbit from rainy100inside100 where radar_id = 'KWAJ' and orbit > 49184) \
  order by 1;" | psql gpmgv | tee -a $LOG_FILE 2>&1

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

for thisdate in `cat $datelist`
do
yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 1C21/2A25/2B31 grid creation in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# dates, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/PR_filelist4geoMatch_temp.txt
outfile=${DATA_DIR}/tmp/PR_files_sites4geoMatch_temp.txt
outfileall=${DATA_DIR}/tmp/PR_files_sites4geoMatch.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of PR 1C21/2A25/2B31 files to process, put in file $filelist
# -- 2B31 file presence is considered optional for now

# HAVE SET "LIMIT 1" FOR GENERATING TEST CONTROL FILE
# Added "and file1c21 is not null" to WHERE clause to eliminate duplicate rows
# for RGSN's mapping to two subsets. Morris, 12/2008

echo "\t \a \f '|' \o $filelist \
     \\\ select file1c21, file2a25, \
     COALESCE(file2b31, 'no_2B31_file') as file2b31, \
     a.orbit, count(*), '${yymmdd}', subset \
     from collatedPRproductswsub a, rainy100inside100 b \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
     and a.orbit=b.orbit and a.radar_id=b.radar_id and file1c21 is not null \
     and a.radar_id = 'KWAJ'\
     group by file1c21, file2a25, file2b31, a.orbit, subset \
     order by a.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

# - Get a list of ground radars where precip is occurring for each included orbit,
#  and prepare this date's control file for IDL to do PR and GV grid file creation.

# 09/2008    Morris         - How to limit last query to 1 row for each event due to
#                             ARMOR 1CUF volumes, where Walt provided more than
#                             one UF volume file for some overpass events, which causes
#                             collatedGVproducts to produce duplicate/multiple rows?
#                             For now will order by radar_id and have IDL handle where
#                             the same radar_id comes up more than once for a case.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f4 -d '|'`
        subset=`echo $row | cut -f7 -d '|'`
	echo "\t \a \f '|' \o $outfile \\\ select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
            extract(EPOCH from date_trunc('second', d.overpass_time)), \
            b.latitude, b.longitude, \
            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
            from overpass_event a, fixed_instrument_location b, \
	  collatedGVproducts c, rainy100inside100 d \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	    and a.radar_id = d.radar_id and a.radar_id = 'KWAJ' \
	    and a.orbit = c.orbit  and a.orbit = d.orbit \
            and a.orbit = ${orbit} and c.subset = '${subset}'
          order by 3;" \
      | psql -q gpmgv | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

#exit

if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, do_geo_matchup.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.

    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling do_geo_matchup.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/do_geo_matchup.sh $yymmdd

    if [ $? = 0 ]
      then
        echo ""
        echo "SUCCESS status returned from do_geo_matchup.sh"\
	 | tee -a $LOG_FILE
      else
        echo ""
        echo "FAILURE status returned from do_geo_matchup.sh, quitting!"\
	 | tee -a $LOG_FILE
#	exit 1
    fi

    echo "" | tee -a $LOG_FILE
    end=`date -u`
    echo "Gridding scripts for $yymmdd completed on $end"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "=================================================================="\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

done

exit
