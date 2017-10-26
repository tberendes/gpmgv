#!/bin/sh
###############################################################################
#
# TestVariableTimeCoincidence.sh    Morris/SAIC/GPM GV    September 2010
#
# Wrapper to do PR-GV coincidence computations for 1C21/2A25/2B31/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which created and populated the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See file 'rainCases100.sql'.
#
# 2/24/2011   Morris         Created from doGeoMatch_KMLB_multiVols.sh
#
###############################################################################


GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

RADARID=KMLB
SUBSETID=sub-GPMGV1

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
#satid="PR"

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/TestVariableTimeCoincidence.${rundate}.log
export rundate

umask 0002

echo "Starting PR and GV coincidence generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the subquery to just run for specific date range.

datelist=${DATA_DIR}/tmp/doCoincidences4SelectedDates_temp.txt
echo "\t \a \f '|' \o $datelist \
  \\\select distinct date(date_trunc('day', overpass_time at time zone 'UTC')) \
  from collatedprproductswsub where orbit in \
  (select distinct orbit from rainy100inside100 where radar_id = '${RADARID}' \
   and date( date_trunc('day', overpass_time at time zone 'UTC') ) between \
   '2007-02-01' and '2007-03-01' ) order by 1;" | psql gpmgv | tee -a $LOG_FILE 2>&1

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build a coincidence file for each date.

for thisdate in `cat $datelist`
do
yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 1C21/2A25/2B31 PR files.
# 'outfile' gets overwritten each time psql is called in the loop over the new
# dates, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/PR_filelist4Coincidence_temp.txt
outfile=${DATA_DIR}/tmp/PR_files_sites4Coincidence_temp.txt
outfileall=${DATA_DIR}/tmp/PR_files_sites4Coincidence.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of PR 1C21/2A25/2B31 files to process, put in file $filelist
# -- 2B31 file presence is considered optional for now

# Added "and file1c21 is not null" to WHERE clause to eliminate duplicate rows
# for RGSN's mapping to two subsets. Morris, 12/2008

echo "\t \a \f '|' \o $filelist \
     \\\ select file1c21, file2a25, \
     COALESCE(file2b31, 'no_2B31_file') as file2b31, \
     a.orbit, count(*), '${yymmdd}', subset \
     from collatedPRproductswsub a, rainy100inside100 b, radarcatalog c \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
     and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id=c.radar_id \
     and file1c21 is not null and a.radar_id = '${RADARID}' and a.subset='${SUBSETID}' \
     and c.valid between b.overpass_time-interval '30 minutes' and b.overpass_time+interval '30 minutes' \
     group by file1c21, file2a25, file2b31, a.orbit, subset \
     order by a.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

# - Get a list of ground radars where precip is occurring for each included orbit,
#  and prepare this date's GR file coincidences for a specified interval relative
#  to the PR nearest approach time.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f4 -d '|'`
        subset=`echo $row | cut -f7 -d '|'`
	echo "\t \a \f '|' \o $outfile \\\ select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
            extract(EPOCH from date_trunc('second', d.overpass_time)), \
            b.latitude, b.longitude, \
            trunc(b.elevation/1000.,3), COALESCE(c.filepath, 'no_1CUF_file') \
            from overpass_event a, fixed_instrument_location b, \
	    radarcatalog c, rainy100inside100 d \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	    and a.radar_id = d.radar_id and a.radar_id = '${RADARID}' \
	    and a.orbit = d.orbit and a.orbit = ${orbit} \
            and c.valid between d.overpass_time-interval '30 minutes' and d.overpass_time+interval '30 minutes'
          order by 3;" \
      | psql -q gpmgv | tee -a $LOG_FILE 2>&1

date | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | sed 's[/1CUF/[/1CUF-cal/[' | tee -a $outfileall  | tee -a $LOG_FILE
    done

done
exit 0
