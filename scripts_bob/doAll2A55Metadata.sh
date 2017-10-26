#!/bin/sh
###############################################################################
#
# doAll2A55Metadata.sh    Morris/SAIC/GPM GV    November 2006
#
# Wrapper to do metadata extraction for all 2A55 files already received and
# cataloged.  Like in catalogQCradar.sh, but for all files, not just the new
# ones.
#
###############################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts

#rundate=`date -u +%y%m%d`
rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/doAll2A55Metadata.${rundate}.log
export rundate

umask 0002

echo "Starting metadata extract run for 2A55 HDFs for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doAll2A55Meta_dates_temp.txt
echo "\t \a \f '|' \o $datelist \
     \\\select distinct cast(nominal at time zone 'UTC' as date) from gvradar\
     where product = '2A55' order by 1;" | psql gpmgv \
      | tee -a $LOG_FILE 2>&1

for thisdate in `cat $datelist`
do
#YYYYMMDD=`echo $thisdate | sed 's/-//g'`
yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 2A55 RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2A55 files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/files2a55_temp.txt
outfile=${DATA_DIR}/tmp/file2a55sites_temp.txt
#outfileall=${DATA_DIR}/tmp/file2a23sites.${infiledate}.txt
outfileall=${DATA_DIR}/tmp/file2a55sites.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of 2A55 files to be processed, put in file $filelist
echo "\t \a \f '|' \o $filelist \
     \\\ select radar_id || '/' || filepath || '/' || filename from gvradar\
     where product = '2A55'\
     and cast(nominal at time zone 'UTC' as date) = '${thisdate}';" \
     | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 2A55 file metadata extraction.

echo ""  | tee -a $LOG_FILE
echo "Output file contents:"  | tee -a $LOG_FILE
echo ""  | tee -a $LOG_FILE
# copy the temp file outputs from psql to the daily control file
cat $filelist | tee -a $outfileall  | tee -a $LOG_FILE

if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, get2A55Meta.sh, to run
    # the IDL .bat file.  Let this deal with whether the yymmdd
    # has been done before.
    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling get2A55Meta.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/get2A55Meta.sh $yymmdd
    if [ $? ]
      then
        echo "SUCCESS status returned from get2A55Meta.sh" | tee -a $LOG_FILE
      else
        echo "FAILURE status returned from get2A55Meta.sh, quitting now!"\
	 | tee -a $LOG_FILE
	exit 1
    fi
    echo "" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    end=`date -u`
    echo "Metadata script for $yymmdd completed on $end,"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "=================================================================="\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

done

exit
