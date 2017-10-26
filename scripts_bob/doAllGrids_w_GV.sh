#!/bin/sh
###############################################################################
#
# doAllMetadata.sh    Morris/SAIC/GPM GV    October 2006
#
# Wrapper to do NetCDF grid creation for all 1C21/2A25 files already received
# and cataloged.
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

#rundate=`date -u +%y%m%d`
rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/doAllGrids5.${rundate}.log
export rundate

umask 0002

echo "Starting metadata extract run for PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doAllGrid_dates_temp.txt
echo "\t \a \f '|' \o $datelist \
     \\\select distinct a.filedate from orbit_subset_product a,\
     orbit_subset_product b where a.orbit=b.orbit and a.product_type='1C21'\
     and b.product_type = '2A25' order by filedate;" | psql gpmgv \
      | tee -a $LOG_FILE 2>&1

for thisdate in `cat $datelist`
do
yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
# files to hold the delimited output from the database queries comprising the
# control files for the 1C21/2A25 grid creation in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# dates, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/PR_filelist4grid_temp.txt
outfile=${DATA_DIR}/tmp/PR_files_sites4grid_temp.txt
outfileall=${DATA_DIR}/tmp/PR_files_sites4grid.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of 1C21/2A25 files to be processed, put in file $filelist
echo "\t \a \f '|' \o $filelist \
     \\\ select file1c21, file2a25, orbit, count(*) from collatedZproducts\
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}'\
     group by file1c21, file2a25, orbit\
     order by orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 1C21/2A25 grid file creation.

    for row in `cat $filelist`
      do
        orbit=`echo $row | cut -f3 -d '|'`
	echo "\t \a \f '|' \o $outfile \
          \\\ select a.event_num, a.radar_id, \
          extract(EPOCH from a.overpass_time), b.latitude, b.longitude, \
	  COALESCE(c.file2a55, 'no_2A55_file')
          from overpass_event a, fixed_instrument_location b, \
	  collatedZproducts c \
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id and \
	  a.orbit = c.orbit and a.orbit = ${orbit};" | psql gpmgv \
	   | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done


if [ -s $outfileall ]
  then
    # Call the IDL wrapper scripts, grid_1C21_2A25.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.
    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling grid_1C21_2A25.sh $yymmdd on $start1" | tee -a $LOG_FILE
#    ${BIN_DIR}/grid_1C21_2A25.sh $yymmdd
    if [ $? ]
      then
        echo "SUCCESS status returned from grid_1C21_2A25.sh"\
	 | tee -a $LOG_FILE
      else
        echo "FAILURE status returned from grid_1C21_2A25.sh, quitting now!"\
	 | tee -a $LOG_FILE
#	exit 1
    fi
    echo "" | tee -a $LOG_FILE
    end=`date -u`
    echo "Gridding scripts for $yymmdd completed on $end,"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "=================================================================="\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

done

exit
