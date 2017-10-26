#!/bin/sh
###############################################################################
#
# reorderUF_multi.sh    Morris/SAIC/GPM GV    June 2008
#
# Wrapper to do grid generation from 1CUF files for cases meeting criteria
# defined in a prior database query and stored in a database table.
# Derived from reorder1CUF.sh in June 2008, to run more flexible .bat and
# .pro files in IDL.
#
###############################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts
IDL_PRO_DIR=${GV_BASE_DIR}/idl/valnet/gridbyreorder  # change for operational
export IDL_PRO_DIR                 # IDL reorder1CUF.bat needs this
IDL=/usr/local/bin/idl
RAD_DATA_ROOT=${DATA_DIR}/gv_radar/finalQC_in
export RAD_DATA_ROOT              # IDL needs this

#rundate=`date -u +%y%m%d`
rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/reorder1CUF.${rundate}.log
export rundate
ZZZ=300                   # sleep 5 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 40 mins

umask 0002

echo "" | tee -a $LOG_FILE
echo "===================================================================="\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Starting REORDER run for 1CUFs for $rundate."\
 | tee $LOG_FILE
echo "" | tee -a $LOG_FILE

yymmdd=$rundate
# file to hold the delimited output from the database queries comprising the
# control file for the 1CUF-to-netCDF gridding in the IDL routines:
# -file gets overwritten each time psql is called over the new
# 1CUF files, so it is run-date-specific.  Need to export so that IDL can
# pick up the filename from the environment
export REO_1CUF_LIST=${DATA_DIR}/tmp/reorder/file1CUFtodo.${yymmdd}.txt

if [ -s $REO_1CUF_LIST ]
  then
    rm -v $REO_1CUF_LIST | tee -a $LOG_FILE 2>&1
fi

# - Prepare the control file for IDL to do 1CUF file metadata extraction.

echo "\t \a \f '|' \o $REO_1CUF_LIST \\\ set datestyle to postgres, DMY;
 select a.event_num, a.orbit, \
 a.radar_id, c.nominal at time zone 'UTC', b.latitude, b.longitude, \
 trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
 from overpass_event a, fixed_instrument_location b, \
 collatedGVproducts c, rainy100inside100 d \
 where a.radar_id = b.instrument_id and a.radar_id = c.radar_id and \
 a.radar_id = d.radar_id and a.orbit = c.orbit  and a.orbit = d.orbit and a.orbit>60508;" \
 | psql -q gpmgv | tee -a $LOG_FILE 2>&1

if [ ! -s $REO_1CUF_LIST ]
  then
    echo "No cases in control file $REO_1CUF_LIST, exiting."| tee -a $LOG_FILE
    exit 0
fi

# check whether the IDL license manager is running. If not, we are done for,
# and will have to exit and leave the input run date flagged as one to be
# re-run next time
ps -ef | grep "rsi/idl" | grep lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    echo "FATAL: IDL license manager not running!" | tee -a $LOG_FILE
    exit 1
fi

# check that the to-be-called scripts are found and/or executable
if [ ! -s ${IDL_PRO_DIR}/reorderUF_multi.bat ]
  then
     echo "Script ${IDL_PRO_DIR}/reorderUF_multi.bat not found, exiting" \
       | tee -a $LOG_FILE
     echo "with no grids processed." \
       | tee -a $LOG_FILE
     exit 1
fi

# check whether the IDL license is tied up by another user.  Sleep a few times
# until it comes free.  If we time out, then leave the input run date flagged
# as one to be re-run next time, and exit.

ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    idl_free='t'
  else
    idl_free='f'
fi

declare -i napnum=1
until [ "$idl_free" = 't' ]
  do
    echo "" | tee -a $LOG_FILE
    echo "Attempt $napnum, waiting $ZZZ seconds for IDL license to free up."\
     | tee -a $LOG_FILE
    sleep $ZZZ
    #sleep 3         # sleep value for testing
    napnum=napnum+1
    if [ $napnum -gt $naps ]
      then
	echo "" | tee -a $LOG_FILE
	echo "Exiting after $naps attempts to get IDL license."\
	 | tee -a $LOG_FILE
	exit 1
    fi
    ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
    if [ $? = 1 ]
      then
        idl_free='t'
    fi
done

# Call the IDL  .bat file.
echo "" | tee -a $LOG_FILE
start1=`date -u`
echo "Calling IDL with reorderUF_multi.bat on $start1" | tee -a $LOG_FILE
$IDL < ${IDL_PRO_DIR}/reorderUF_multi.bat | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
end=`date -u`
echo "reorder1CUF.sh for $yymmdd completed on $end"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "===================================================================="\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
