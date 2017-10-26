#!/bin/sh
###############################################################################
#
# doMissingMetadata_wSub.sh    Morris/SAIC/GPM GV    March 2007
#
# Wrapper to do metadata extraction for overpass events where metadata is
# missing.  Takes into account the PR product subset to which the overpassed
# site is mapped.
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
rundate=MsgMta                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/doMissingMetadata.${rundate}.log
export rundate

umask 0002

echo "Starting missing metadata run for PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

yymmdd=$rundate
# files to hold the delimited output from the database queries comprising the
# control files for the 2A23 RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2A23 files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
filelist=${DATA_DIR}/tmp/files2a23_temp.txt
outfile=${DATA_DIR}/tmp/file2a23sites_temp.txt
#outfileall=${DATA_DIR}/tmp/file2a23sites.${infiledate}.txt
outfileall=${DATA_DIR}/tmp/file2a23sites.${yymmdd}.txt

if [ -s $outfileall ]
  then
    rm -v $outfileall | tee -a $LOG_FILE 2>&1
fi

# Get a listing of 2A23/2A25 files to be processed, put in file $filelist
# There should be 11 metadata items for each overpass, 6 from 2A25, 5 from 2A23
# If less, just add the event to the list and let the duplicate rejection take
# care of any redundant database inserts.

# Added an orbit-specific file exclude list to keep 'bad' HDF files from killing
# the IDL program - 12/26/07, 54647, 56785, 56786, 57425
#       and a.orbit not in (53778, 53519, 54067, 55840, 58846, 59044)

# and a.orbit > 61978 -- replaced with < 2000 for MELB v7 stuff
echo "\t \a \f '|' \o $filelist \
     \\\ select 'no2a23file', b.filename, b.orbit, count(*), b.subset\
     from orbit_subset_product b,\
          overpass_event c, siteproductsubset d\
     where b.orbit = c.orbit and b.product_type = '2A25'\
       and b.subset = d.subset\
       and c.radar_id = d.radar_id  and b.orbit < 2000  \
       and 18 > (select count(*) from event_meta_numeric \
       where event_num=c.event_num) \
       group by 1, b.filename, b.orbit, b.subset \
     order by b.orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

# - Prepare the control file for IDL to do 2A23/2A25 file metadata extraction.

    for row in `cat $filelist`
      do
        orbit=`echo $row | cut -f3 -d '|'`
	subset=`echo $row | cut -f5 -d '|'`
	echo "\t \a \f '|' \o $outfile \
          \\\ select a.event_num, a.radar_id, b.latitude, b.longitude \
          from overpass_event a, fixed_instrument_location b, \
	       siteproductsubset d \
         where a.radar_id = b.instrument_id and a.radar_id = d.radar_id \
	 and a.orbit = ${orbit} and d.subset = '${subset}' \
          and 18 > (select count(*) from event_meta_numeric where
	  event_num=a.event_num);" | psql gpmgv  | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Output file contents:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file outputs from psql to the daily control file
	echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done
#exit  # uncomment to just produce the control file for IDL and quit

if [ -s $outfileall ]
  then
#   reset the database for running of missing metadata.  Re-uses a fixed yymmdd,
#   so we need to remove all values with this special tag from appstatus table.
    echo "delete from appstatus where datestamp = '${yymmdd}';" \
       | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    
    # Call the IDL wrapper scripts, get2A23Meta.sh and get2A25Meta.sh, to run
    # the IDL .bat files.  Let each of these deal with whether the yymmdd
    # has been done before.
    echo "" | tee -a $LOG_FILE
    start1=`date -u`
    echo "Calling get2A23Meta.sh $yymmdd on $start1" | tee -a $LOG_FILE
    ${BIN_DIR}/get2A23Meta.sh $yymmdd
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
    ${BIN_DIR}/get2A25Meta.sh $yymmdd
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

exit
