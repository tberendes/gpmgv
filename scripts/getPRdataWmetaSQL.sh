#!/bin/sh
#
# getPRdata.sh    Morris/SAIC/GPM GV    August 2006
#
# DESCRIPTION:
#
# Uses Perl script 'mirror' to create a local mirror of the TSDIS ftp site
# where GPM PR subset data products are located.  Makes up to 10 attempts to
# access the ftp site and download all the files not present in the local
# directory, $MIR_DATA_DIR.  Examines MIR_LOG_FILE to determine whether
# any errors occurred in the last run of mirror, and if so, makes a retry after
# a sleep period.
#
# FILES:
#
#                  mirror - Perl script to perform the directory mirroring via
#                           ftp.  Freeware download.
#
#         mirror.defaults - Default configuration items for mirror script.  Used
#                           by mirror but not referenced in this script.  May be
#                           augmented and/or overridden by package file.
#
# ftp-tsdis.gsfc.nasa.gov - Package file, holds configuration for mirror script
#                           to mirror files from ftp site of the same name.
#
#        gpmprsubsets.log - Log file of mirror script.  Is examined to determine
#                           if download errors require mirror to be re-run.
#                           Is renamed mirror.YYMMDD.log and moved from
#                           $MIR_DATA_DIR to $LOG_DIR at end of script run.
#
#  DATABASE
#    Catalogs PR subset file metadata in orbit_subset_product table in 'gpmgv'
#    database in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    getPRdata.YYYYMMDD.log in data/logs subdirectory.  YYYYMMDD is replaced by
#    the current date.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and INSERT privileges on table.  Utility 'psql' must
#      be in user's $PATH.
#    - User must have write privileges in $MIR_DATA_DIR, $LOG_DIR directories
#
################################################################################


GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

# Following two variables must be the same as specified in the "package" file!
MIR_DATA_DIR=${DATA_DIR}/prsubsets
MIR_LOG_FILE=${MIR_DATA_DIR}/gpmprsubsets.log

MIR_BIN=mirror
MIR_BIN_DIR=${BIN_DIR}/mirror
# The following are specified relative to MIR_BIN_DIR, as mirror expects:
MIR_PACKAGES_DIR=packages
MIR_PACKAGE=${MIR_PACKAGES_DIR}/ftp-tsdis.gsfc.nasa.gov

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
satid="PR"

# ZZZ is number of seconds to sleep between repeat mirror attempts if problems/errors
ZZZ=300
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getPRdata.${rundate}.log
export rundate

# files to hold the delimited output from the database queries comprising the
# control files for the 2A23 RainType metadata extraction in the IDL routines:
# 'outfile' gets overwritten each time psql is called in the loop over the new
# 2A23 files, so its output is copied in append manner to 'outfileall', which
# is run-date-specific.
outfile=${DATA_DIR}/tmp/file2a23sites_temp.txt
outfileall=${DATA_DIR}/tmp/file2a23sites.${rundate}.txt

umask 0002

echo "Starting mirroring run for PR subsets for $rundate." | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE

# mirror (apparently) must be run from its home directory
cd ${MIR_BIN_DIR}

if [ ! -x ${MIR_BIN} ]
  then
     echo "Executable file '${MIR_BIN}' not found in `pwd`, exiting." \
       | tee -a $LOG_FILE
     exit 1
fi

MIRCMD=./${MIR_BIN}' '${MIR_PACKAGE}
runagain='y'
declare -i tries=0

until [ "$runagain" = 'n' ]
  do
     tries=tries+1
     echo "Try = ${tries}, max = 10." | tee -a $LOG_FILE
     echo "Running following command from `pwd` :"
     echo ${MIRCMD}

# ******* run mirror command here ********
     ${MIRCMD} | tee -a $LOG_FILE

# bailout mechanism for testing
#     echo "Enter q to quit or hit return to continue:"
#     read -r bail
#     if [ "$bail" = 'q' ]
#       then
#          exit
#     fi

# If mirror cannot make connection, it does not create a log file. so need
# to check its direct output, as piped to this script's log

     tail -n 3 $LOG_FILE | grep -E 'Cannot connect' > /dev/null
     if [ $? = 0 ]
     then
        echo "Connect failure in mirror!" | tee -a $LOG_FILE
        if [ $tries -eq 10 ]
          then
             runagain='n'
             echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
          else
             echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
             sleep $ZZZ
        fi
     else if [ -s $MIR_LOG_FILE ]
       then
          #  THIS WAS MODIFIED TO NOT JUST LOOK AT THE ENTIRE FILE, ELSE
          #  WE END UP RE-TRYING AFTER A SUCCESS IF THERE WAS AN EARLIER FAILURE
          #  (FOUND WHEN RUN 1ST TIME AS 'gvoper' AND HAD PERMISSION ISSUES)
          grep -E '(Fatal|Failed)' ${MIR_LOG_FILE} > /dev/null
          if [ $? = 0 ]
          then
             # check the last line only of the mirror log file to see if we had
	     # a successful transfer ("Got" in the text) or no files were found
	     # to transfer ("successful" in the last line) since the prior error
	     tail -n 1 $MIR_LOG_FILE | grep '(Got|successful)'  > /dev/null
	     if [$? = 0 ]
	     then
                echo "Transfer succeeded after earlier error.  Continuing." \
	           | tee -a $LOG_FILE
                runagain='n'
	     else
	        echo "Transfer failures in mirror log file!" | tee -a $LOG_FILE
                if [ $tries -eq 10 ]
                then
                   runagain='n'
                   echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
                else
                   echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
                   sleep $ZZZ
                fi
	     fi
          else
             echo "No error found in mirror log file." | tee -a $LOG_FILE
             runagain='n'
          fi
       else if [ -f $MIR_LOG_FILE ]
         then
            # this doesn't actually happen, mirror log file always has some
	    # content if mirror gets a connection
	    echo "Empty mirror log file, no new data to transfer this run."
            runagain='n'
         else
            echo "No log file found!" | tee -a $LOG_FILE
            runagain='n'
         fi
       fi
     fi

done

# could be more efficient than calling psql in a loop to insert 1 row at a time!
if [ -s $MIR_LOG_FILE ]
  then
    # see if any data files were actually downloaded, exit now if none
    grep -E '(1C21|2A23|2A25)' ${MIR_LOG_FILE} > /dev/null
    if [ $? != 0 ]
      then
        echo "No PR subset files downloaded; skip metadata steps and exit."\
	 | tee -a $LOG_FILE
        echo "See log file $LOG_FILE for script output."
        exit
    fi
    
    # catalog the files in the database
    for type in 1C21 2A23 2A25
      do
        for file in `grep $type $MIR_LOG_FILE | cut -f2 -d '/' | cut -f1 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
            #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo "INSERT INTO orbit_subset_product \
	    VALUES('${satid}',${orbit},'${type}','${dateString}','${file}');" \
	    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        done
    done

# - Prepare the control file for IDL to do new 2A23 file metadata extraction.
# - NOW we added the matching 2A25 filename to the 'orbit' lines of the groups,
#   and the overpass 'event_num' to the overpass event lines of the groups.
# - STILL NEED logic to check yesterday's getCTdaily.sh run status, or
#   else we run the risk of getting no matching overpass_events for files we
#   just downloaded today when yesterday's getCTdaily run times out or fails!

    echo "" | tee -a $LOG_FILE
    echo "Generating orbit/file and site overpass metadata control file."\
     | tee -a $LOG_FILE

    for file2a23 in `grep 2A23 $MIR_LOG_FILE | cut -f2 -d '/' | cut -f1 -d ' '`
      do
        echo ""  | tee -a $LOG_FILE
        echo "\t \a \f '|' \o $outfile \
         \\\ SELECT b.filename, c.filename, b.orbit, count(*) \
          FROM overpass_event a, orbit_subset_product b, orbit_subset_product c\
          WHERE a.orbit = b.orbit AND b.filename = '${file2a23}'\
          AND a.orbit = c.orbit AND c.product_type = '2A25'
          GROUP BY b.filename, c.filename, b.orbit;\
        SELECT a.event_num, a.radar_id, b.latitude, b.longitude\
          FROM overpass_event a, fixed_instrument_location b\
          WHERE a.radar_id = b.instrument_id AND\
          a.orbit = (SELECT orbit FROM orbit_subset_product\
          WHERE filename='${file2a23}');" | psql gpmgv  | tee -a $LOG_FILE 2>&1

        thisorbit=`echo ${file2a23} | cut -f3 -d '.'`
        echo "Output file additions for orbit ${thisorbit}:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file output from psql to the daily control file
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

    mv $MIR_LOG_FILE ${LOG_DIR}/mirror.${rundate}.log
fi

if [ -s $outfileall ]
  then
    # Call the IDL wrapper script, get2A23-25Meta.sh, to run the IDL .bat files.
    # It's slow, so run it in the background so that this script can complete.
    echo "" | tee -a $LOG_FILE
    echo "Calling get2A23-25Meta.sh to extract RainType PR metadata."\
      | tee -a $LOG_FILE
    
    ${BIN_DIR}/get2A23-25Meta.sh $rundate &
    
    echo "See log files ${LOG_DIR}/get2A23Meta.${rundate}.log," \
     | tee -a $LOG_FILE
    echo "and ${LOG_DIR}/get2A23Meta.${rundate}.log" | tee -a $LOG_FILE
fi

#cat $LOG_FILE
echo ""  | tee -a $LOG_FILE
echo "SCRIPT getPRdata.sh COMPLETE, EXITING." | tee -a $LOG_FILE
echo "See log file $LOG_FILE for script output."
echo "" | tee -a $LOG_FILE
exit
