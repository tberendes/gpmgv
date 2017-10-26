#!/bin/sh
###############################################################################
#
# doAllMetadataKWAJ.sh    Morris/SAIC/GPM GV    October 2006
#
# Wrapper to do metadata extraction for all 2A23/2A25 files already received
# and cataloged for the KWAJ subset.  Like in getPRdaily.sh, but for all files,
# not just the new ones.
#
# May want to limit the file dates in the first query so that a limited # of
# files are processed at a time, as the IDL processing is intense.  Ideally,
# we want to add logic to loop over dates and do separate output files for
# each date.
#
###############################################################################

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
LOG_FILE=${META_LOG_DIR}/doAllMetadataKWAJ.${rundate}.log
export rundate

umask 0002

echo "Starting metadata extract run for PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doAllMeta_dates_temp.txt
echo "\t \a \f '|' \o $datelist \
     \\\select distinct a.filedate from orbit_subset_product a,\
     orbit_subset_product b where a.orbit=b.orbit and a.sat_id=b.sat_id\
     and a.sat_id = 'PR' and a.product_type='2A23' and b.product_type = '2A25'\
     and a.subset=b.subset and a.subset = 'KWAJ' and a.filedate>'2008-12-06' \
     order by filedate;" | psql gpmgv | tee -a $LOG_FILE 2>&1

for thisdate in `cat $datelist`
do
# In normal runs driven by getPRdaily.sh, the date of the data files is
# two days behind the date of the run (and of the log and temp files, and the
# datestamp in the appstatus database).  Increment $thisdate (the data files'
# date) by two days to get the datestamp we want for all these other files and
# database records.
YYYYMMDD=`echo $thisdate | sed 's/-//g'`
#logdate=`offset_date $YYYYMMDD 2`
logdate=$YYYYMMDD
yymmdd=`echo $logdate | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 2A23 RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2A23 files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/files2a23_temp.txt
outfile=${DATA_DIR}/tmp/file2a23sites_temp.txt
#outfileall=${DATA_DIR}/tmp/file2a23sites.${infiledate}.txt
outfileall=${DATA_DIR}/tmp/file2a23_KWAJ.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

echo ""; echo "Date to do = ${thisdate}"

# Get a listing of 2A23/2A25 files to be processed, put in file $filelist
echo "\t \a \f '|' \o $filelist \
     \\\ select a.filename, b.filename, b.orbit, count(*)\
     from orbit_subset_product a, orbit_subset_product b, overpass_event c\
     where a.orbit = b.orbit and a.subset = b.subset and a.product_type = '2A23'\
       and b.orbit = c.orbit and a.sat_id=b.sat_id and a.sat_id = 'PR' and b.product_type = '2A25'\
       and a.filedate = '${thisdate}' and a.subset = 'KWAJ' and c.radar_id = 'KWAJ'\
     group by a.filename, b.filename, b.orbit \
     order by b.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 2A23/2A25 file metadata extraction.

    for row in `cat $filelist`
      do

echo "----------------------"; echo ""

        orbit=`echo $row | cut -f3 -d '|'`
	echo "\t \a \f '|' \o $outfile \
          \\\ select a.event_num, a.radar_id, b.latitude, b.longitude \
          from overpass_event a, fixed_instrument_location b \
          where a.radar_id = b.instrument_id and a.radar_id = 'KWAJ'\
          and a.orbit = ${orbit};" | psql gpmgv  | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, get2A23Meta.sh and get2A25Meta.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.
    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling get2A23Meta.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/get2A23MetaKWAJ.sh $yymmdd
    if [ $? ]
      then
        echo "SUCCESS status returned from get2A23Meta.sh" | tee -a $LOG_FILE
      else
        echo "FAILURE status returned from get2A23Meta.sh, quitting now!"\
	 | tee -a $LOG_FILE
	exit 1
    fi
    echo "" | tee -a $LOG_FILE
    start2=`date -u`
    echo "Calling get2A25Meta.sh $yymmdd on $start2" | tee -a $LOG_FILE
    ${BIN_DIR}/get2A25MetaKWAJ.sh $yymmdd
    if [ $? ]
      then
        echo "SUCCESS status returned from get2A25Meta.sh" | tee -a $LOG_FILE
      else
        echo "FAILURE status returned from get2A25Meta.sh, quitting now!"\
	 | tee -a $LOG_FILE
	exit 1
    fi
    echo "" | tee -a $LOG_FILE
    end=`date -u`
    echo "Metadata scripts for $yymmdd completed on $end,"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "=================================================================="\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

done

exit
