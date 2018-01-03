#!/bin/sh
###############################################################################
#
# doAllMetadata.sh    Morris/SAIC/GPM GV    October 2006
#
# Wrapper to do metadata extraction for all 2A23/2A25 files already received
# and cataloged.  Like in getPRdaily.sh, but for all files, not just the new
# ones.
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
BIN_DIR=${GV_BASE_DIR}/scripts

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
#satid="PR"

#rundate=`date -u +%y%m%d`
rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/doAllMetadata.${rundate}.log
export rundate

# files to hold the delimited output from the database queries comprising the
# control files for the 2A23 RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2A23 files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/files2a23_temp.txt
outfile=${DATA_DIR}/tmp/file2a23sites_temp.txt
#outfileall=${DATA_DIR}/tmp/file2a23sites.${infiledate}.txt
outfileall=${DATA_DIR}/tmp/file2a23sites.${rundate}.txt

umask 0002

echo "Starting metadata extract run for PR subsets for $rundate." | tee $LOG_FILE
echo "========================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of 2A23/2A25 files to be processed, put in file $filelist
echo "\t \a \f '|' \o $filelist \
     \\\ select a.filename, b.filename, b.orbit, count(*)\
     from orbit_subset_product a, orbit_subset_product b, overpass_event c\
     where a.orbit = b.orbit and a.product_type = '2A23'\
       and b.orbit = c.orbit and b.product_type = '2A25'\
     group by a.filename, b.filename, b.orbit \
     order by b.orbit limit 5;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 2A23/2A25 file metadata extraction.

    for row in `cat $filelist`
      do
        orbit=`echo $row | cut -f3 -d '|'`
	echo "\t \a \f '|' \o $outfile \
          \\\ select a.event_num, a.radar_id, b.latitude, b.longitude \
          from overpass_event a, fixed_instrument_location b \
          where a.radar_id = b.instrument_id and \
          a.orbit = ${orbit};" | psql gpmgv  | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done


if [ -s $outfileall ]
  then
    # Call the IDL wrapper script, get2A23Meta.sh, to run the IDL .bat file.
    # It's slow, so run it in the background so that this script can complete.
    echo "" | tee -a $LOG_FILE
    echo "Calling get2A23Meta.sh to extract RainType metadata for overpasses:"\
      | tee -a $LOG_FILE
    
#    ${BIN_DIR}/get2A23Meta.sh $rundate &
    
    echo "See log file ${LOG_DIR}/get2A23Meta.${rundate}.log" \
    | tee -a $LOG_FILE
fi

exit
