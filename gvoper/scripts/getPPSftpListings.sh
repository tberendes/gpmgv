#!/bin/sh
#
# getPPSftpListings.sh    Morris/SAIC/GPM GV    April 2014
#
# DESCRIPTION:
#
# Uses Perl script 'mirror' to create a local mirror of the PPS ftp location
# where ftp_url_YYMMDDHHMM.txt listing files are located.  Makes up to 10
# attempts to access the ftp site and download all the files not present in the
# local directory, $MIR_DATA_DIR.  Examines MIR_LOG_FILE to determine whether
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
# arthurhou.pps.eosdis.nasa.gov - Package file, holds configuration for mirror
#                           script to mirror files from ftp site with this name.
#
#        pps_ftp_lists.log - Log file of mirror script.  Is examined to determine
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
#    getPPSftpListings.YYYYMMDD.log in data/logs subdirectory. 
#    YYYYMMDD is replaced by the current date.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and INSERT privileges on table.  Utility 'psql' must
#      be in user's $PATH.
#    - User must have write privileges in $MIR_DATA_DIR, $LOG_DIR directories
#
#  HISTORY
#    04/14/2014, Morris, SAIC, GPM GV
#    - Created from getPRdata.sh.
#    08/26/2014      - Morris
#    - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
#
################################################################################


GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/emdata      # not used in script
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
BIN_DIR=${GV_BASE_DIR}/scripts

# Following two variables must be the same as specified in the "package" file!
MIR_DATA_DIR=${TMP_DIR}/PPS_CS
MIR_LOG_FILE=${MIR_DATA_DIR}/pps_ftp_lists.log

MIR_BIN=mirror
MIR_BIN_DIR=${BIN_DIR}/mirror
# The following are specified relative to MIR_BIN_DIR, as mirror expects:
MIR_PACKAGES_DIR=packages
MIR_PACKAGE=${MIR_PACKAGES_DIR}/arthurhou.pps.eosdis.nasa.gov

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired data files, if any
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
INCOMPLETE='I' # could not complete all steps, could be external problem

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getPPSftpListings_dbtempfile

# ZZZ is number of seconds to sleep between repeat mirror attempts if problems/errors
ZZZ=300
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getPPSftpListings.${rundate}.log
export rundate

umask 0002

echo "Starting mirroring run for PPS FTP listings for $rundate." | tee -a $LOG_FILE
echo "=======================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    HOST=`hostname`
    thistime=`date -u`
    echo "Message from getPPSftpListings.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ${HOST}' \
      -c kenneth.r.morris@nasa.gov,todd.a.berendes@nasa.gov \
      makofski@radar.gsfc.nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

# initialize the appstatus table entry for this run's yymmdd
echo "Checking whether we have an entry for this yymmdd in database:"\
 | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT status FROM appstatus \
 WHERE app_id = 'getPPSftpList' AND datestamp = '${rundate}';" \
  | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1

echo "" | tee -a $LOG_FILE
if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to do this yymmdd before, get our past status.
     status=`cat ${DBTEMPFILE}`
     echo "Rundate ${rundate} has been attempted before with status = $status."\
     | tee -a $LOG_FILE
     if [ $status = $SUCCESS ]
       then
         echo "PRIOR RUN SUCCESSFUL.  SCRIPT getPPSftpListings.sh COMPLETE, EXITING." \
	       | tee -a $LOG_FILE
         echo "See log file $LOG_FILE for information."
         exit 0
     fi
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus (app_id, datestamp, status) VALUES \
       ('getPPSftpList', '${rundate}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# increment the ntries column in the appstatus table for $rundate
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'getPPSftpList' AND \
 datestamp = '$rundate';" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

# mirror (apparently) must be run from its home directory
cd ${MIR_BIN_DIR}

if [ ! -x ${MIR_BIN} ]
  then
     echo "Executable file '${MIR_BIN}' not found in `pwd`, exiting." \
          | tee -a $LOG_FILE
     echo "UPDATE appstatus SET status = '$FAILED' \
           WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
           | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
     exit 1
fi

MIRCMD=./${MIR_BIN}' '${MIR_PACKAGE}
runagain='y'
timedout='n'
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

# If mirror cannot make connection, it does not create a log file; so we first
# need to check its direct output, as piped to this script's log

     tail -n 3 $LOG_FILE | grep -E 'Cannot connect' > /dev/null
     if [ $? = 0 ]
     then
        echo "Connect failure in mirror!" | tee -a $LOG_FILE
        if [ $tries -eq 10 ]
          then
             timedout='y'
             runagain='n'
             echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
             echo "UPDATE appstatus SET status = '$FAILED' \
               WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
               | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
          else
             echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
             sleep $ZZZ
        fi
     else if [ -s $MIR_LOG_FILE ]
       then
          #  THIS WAS MODIFIED TO NOT JUST LOOK AT THE ENTIRE LOG FILE, ELSE
          #  WE END UP RE-TRYING AFTER A SUCCESSFUL TRANSFER IF THERE WAS AN
	  #  EARLIER FAILURE INDICATED "HIGHER UP" IN THE LOG FILE.
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
                   timedout='y'
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
            # the 'EMPTY FILE' condition probably can't happen, mirror log
	    # file always exists and has content >IF< mirror gets a connection
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
    echo "" | tee -a $LOG_FILE
    # see if any data files were actually downloaded, exit now if none
    grep ftp_url ${MIR_LOG_FILE} > /dev/null
    if [ $? != 0 ]
      then
        echo "No ftp listings files downloaded; exit." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        if [ "$timedout" = 'y' ]
	  then
            echo "Timed out after $tries failed tries." | tee -a $LOG_FILE
	         echo "UPDATE appstatus SET status = '$FAILED' \
             WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	  else
            echo "UPDATE appstatus SET status = '$MISSING' \
             WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	fi
        echo "" | tee -a $LOG_FILE
        echo "See log file $LOG_FILE for script output."
        mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListingsBAD.${rundate}.log \
             | tee -a $LOG_FILE 2>&1
        exit 1
      else
        echo "UPDATE appstatus SET status = '$SUCCESS' \
          WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi
    echo ""  | tee -a $LOG_FILE
    echo "Renaming mirror log file to unique/datestamped:"  | tee -a $LOG_FILE
    mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListings.${rundate}.log | tee -a $LOG_FILE 2>&1
fi

#cat $LOG_FILE
echo ""  | tee -a $LOG_FILE
echo "SCRIPT getPPSftpListings.sh COMPLETE, EXITING." | tee -a $LOG_FILE
echo "See log file $LOG_FILE for script output."
echo "" | tee -a $LOG_FILE
exit
