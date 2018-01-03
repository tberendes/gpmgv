#!/bin/sh
###############################################################################
#
# doGrids4Select100in100Cases.sh    Morris/SAIC/GPM GV    July 2008
#
# Wrapper to do NetCDF grid creation for 1C21/2A25/2B31/2A55/2A54/2A53 files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which created and populated the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See file 'rainCases100.sql'.
#
# NOTE:  When running grids for dates that might have already had other grids
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Need to delete the
#        entries from this table where app_id='ncgridPRGV' for the dates to be
#        run, or all dates.
#
# 06/12/2007 Morris         Added 2A54 and 2A53 products to the GV output file
#                           lists.  Now query collatedGVproducts view for these
#                           file pathnames.
# 08/2007    Morris         Added 2B31 product to the PR output file list.
# 05/2008    Morris         Limited last query to 1 row for each orbit for 
#                           ARMOR script version, where Walt provided more than
#                           one volume for some overpass events.
# 07/2008    Morris         Modified to do RGSN cases using full-orbit PR files.
# 07/2008    Morris         Modified 1st query to use CT-based dates rather than
#                           those from the PR product filenames, so that the dates
#                           correspond to the events tallied in other tables in
#                           subsequent queries.
# 07/2008    Morris         - Modified 2nd query to add YYMMDD constant field to
#                           end of row for IDL's parsing/usage for when running
#                           multiple days' grids in one invocation of IDL, and
#                           added subset to the select list for use in the 3rd
#                           query.  Otherwise, count(*) can be wrong for the
#                           number of rows returned in the 3rd query.
#                           - Limited last query to 1 row for each event due to
#                           ARMOR 1CUF volumes, where Walt provided more than
#                           one volume for some overpass events, which causes
#                           collatedGVproducts to produce duplicate/multiple rows;
#                           added subset to the WHERE criteria to fix this 
#                           oversight that caused the same symptom for other sites.
#
###############################################################################

#echo "WARNING:  SCRIPT IS CONFIGURED TO UPDATE EXISTING GRIDS"
#echo "YOU WILL HAVE 10 SECONDS TO KILL SCRIPT WITH CTRL-C"
#sleep 10


GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
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

datelist=${DATA_DIR}/tmp/doGrids4SelectDates_temp.txt
echo "\t \a \f '|' \o $datelist \
  \\\select distinct date(date_trunc('day', overpass_time at time zone 'UTC')) from \
  collatedprproductswsub where orbit in \
  (select distinct orbit from rainy100inside100 where orbit = 53624) \
  order by 1;"\
 | psql gpmgv | tee -a $LOG_FILE 2>&1

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
filelist=${DATA_DIR}/tmp/PR_filelist4gridCases_temp.txt
outfile=${DATA_DIR}/tmp/PR_files_sites4gridCases_temp.txt
outfileall=${DATA_DIR}/tmp/PR_files_sites4gridCases.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of PR 1C21/2A25/2B31 files to process, put in file $filelist
# -- 2B31 file presence is considered optional for now

echo "\t \a \f '|' \o $filelist \
     \\\ select file1c21, file2a25, \
     COALESCE(file2b31, 'no_2B31_file') as file2b31,\
     a.orbit, count(*), '${yymmdd}', subset \
     from collatedPRproductswsub a, rainy100inside100 b\
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}'\
     and a.orbit = b.orbit and a.radar_id = b.radar_id and a.orbit = 53624\
     group by file1c21, file2a25, file2b31, a.orbit, subset\
     order by a.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

# - Get a list of ground radars where precip is occurring for each included orbit,
#  and prepare this date's control file for IDL to do PR and GV grid file creation.

# 07/2008    Morris         - Limited last query to 1 row for each event due to
#                           ARMOR 1CUF volumes, where Walt provided more than
#                           one UF volume file for some overpass events, which causes
#                           collatedGVproducts to produce duplicate/multiple rows.
#                           - Added c.subset to the WHERE criteria.
#
    for row in `cat $filelist`
      do
        orbit=`echo $row | cut -f4 -d '|'`
        subset=`echo $row | cut -f7 -d '|'`
	echo "\t \a \f '|' \o $outfile \
          \\\ select DISTINCT a.event_num, a.radar_id, \
          extract(EPOCH from a.overpass_time), b.latitude, b.longitude, \
	  COALESCE(c.file2a55, 'no_2A55_file'),
	  COALESCE(c.file2a54, 'no_2A54_file'),
	  COALESCE(c.file2a53, 'no_2A53_file')
          from overpass_event a, fixed_instrument_location b, \
	  collatedGVproducts c, rainy100inside100 d \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	  and a.radar_id = d.radar_id \
	  and a.orbit = c.orbit  and a.orbit = d.orbit \
          and a.orbit = ${orbit} and c.subset = '${subset}';" | psql gpmgv | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done


if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, grid_1C21_2A25_2A55.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.

    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling grid_1C21_2A25_2A55.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/grid_1C21_2A25_2A55.sh $yymmdd
#    ${BIN_DIR}/update_1C21_2A25_2A55.sh $yymmdd

    if [ $? ]
      then
        echo "SUCCESS status returned from grid_1C21_2A25_2A55.sh"\
	 | tee -a $LOG_FILE
      else
        echo "FAILURE status returned from grid_1C21_2A25_2A55.sh, quitting!"\
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
