#!/bin/sh
#
# getPPSftpListings_wget.sh    Morris/SAIC/GPM GV    April 2014
#
# DESCRIPTION:
#
# Uses wget to create a local mirror of the PPS ftp location
# where ftp_url_YYMMDDHHMM.txt listing files are located.  Makes up to 10
# attempts to access the ftps site and download all the files not present in the
# local directory, $MIR_DATA_DIR.  Examines MIR_LOG_FILE to determine whether
# any errors occurred in the last run of mirror, and if so, makes a retry after
# a sleep period.
#
# FILES:
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
#    07/29/2020     - Berendes
#    - Replaced mirror package with wget
#    1/21/21	   - Berendes changed to new ftps setup from PPS
#
################################################################################


GV_BASE_DIR=/home/gvoper
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
BIN_DIR=${GV_BASE_DIR}/scripts

# Following two variables must be the same as specified in the "package" file!
MIR_DATA_DIR=${TMP_DIR}/PPS_ITE
MIR_LOG_FILE=${MIR_DATA_DIR}/pps_ftp_lists.log

USER=todd.a.berendes@nasa.gov
PW=todd.a.berendes@nasa.gov
AUTH="--user=todd.a.berendes@nasa.gov --password='todd.a.berendes@nasa.gov'"
#FTPS=ftps://arthurhou.pps.eosdis.nasa.gov/gpmuser/gpmgv/scripts/
FTPS=ftps://arthurhou.pps.eosdis.nasa.gov/itedata/iteorder/todd.a.berendes@nasa.gov/scripts/

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
LOG_FILE=${LOG_DIR}/getPPSftpListings_ITE.${rundate}.log
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
    echo "Message from getPPSftpListings_ITE.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ${HOST}' \
      -c "todd.a.berendes@nasa.gov,denise.a.berendes@nasa.gov" \
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
 WHERE app_id = 'get_ITE_List' AND datestamp = '${rundate}';" \
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
         echo "PRIOR RUN SUCCESSFUL.  SCRIPT getPPSftpListings_ITE.sh COMPLETE, EXITING." \
	       | tee -a $LOG_FILE
         echo "See log file $LOG_FILE for information."
         exit 0
     fi
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus (app_id, datestamp, status) VALUES \
       ('get_ITE_List', '${rundate}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# increment the ntries column in the appstatus table for $rundate
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'get_ITE_List' AND \
 datestamp = '$rundate';" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

# mirror (apparently) must be run from its home directory
#cd ${MIR_BIN_DIR}

#if [ ! -x ${MIR_BIN} ]
#  then
#     echo "Executable file '${MIR_BIN}' not found in `pwd`, exiting." \
#          | tee -a $LOG_FILE
#     echo "UPDATE appstatus SET status = '$FAILED' \
#           WHERE app_id = 'getPPSftpList' AND datestamp = '$rundate';" \
#           | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
#     exit 1
#fi
#
#MIRCMD=./${MIR_BIN}' '${MIR_PACKAGE}

# start here

runagain='y'
timedout='n'
declare -i tries=0

until [ "$runagain" = 'n' ]
  do
     tries=tries+1
     echo "Try = ${tries}, max = 10." | tee -a $LOG_FILE
     #echo "Running following command from `pwd` :"
     #echo wget --user=${USER} --password="${PW}" --ftps-fallback-to-ftp -nv --mirror -P ${MIR_DATA_DIR} -o ${MIR_LOG_FILE} -nH --no-parent --cut-dirs=3 -A "ftp_url*" ${FTPS}

# ******* run mirror command here ********
     #${MIRCMD} | tee -a $LOG_FILE
     #wget --user=${USER} --password="${PW}" -nv --mirror -P ${MIR_DATA_DIR} -o ${MIR_LOG_FILE} -nH --no-parent --cut-dirs=3 -A "ftp_url*" ${FTPS} | tee -a $LOG_FILE

     wget --user=${USER} --password="${PW}" --ftps-fallback-to-ftp -nv --mirror -P ${MIR_DATA_DIR} -o ${MIR_LOG_FILE} -nH --no-parent --cut-dirs=3 -A "ftps_url*" ${FTPS}
	 status = $?
	 
# bailout mechanism for testing
#     echo "Enter q to quit or hit return to continue:"
#     read -r bail
#     if [ "$bail" = 'q' ]
#       then
#          exit
#     fi

# need to extract filenames from wget output and insert them into the main log file for parsing in get_PPS_CS_data
# old mirror script used
#Mirrored ppsftpurlfiles (arthurhou.pps.eosdis.nasa.gov:./gpmuser/gpmgv/scripts -> /data/tmp/PPS_CS) Get ftp_url listings files for GPM GV from the PPS @ 27 Jul 120 15:20
#Got ftp_url_202007271445.txt 13758 0
#Got ftp_url_202007271245.txt 35281 0
#Got ftp_url_202007271045.txt 15960 0
#Got ftp_url_202007270845.txt 994 1
#Got ftp_url_202007270645.txt 1188 0
#Got ftp_url_202007270445.txt 1194 0
#Got ftp_url_202007270245.txt 396 0
#Got ftp_url_202007270045.txt 596 0
#Got ftp_url_202007262245.txt 3824 0
#Got ftp_url_202007262045.txt 3805 0
#Got ftp_url_202007261845.txt 11842 0
#Got ftp_url_202007261645.txt 3010 0

# new format from wget
#Server does not support AUTH TLS. Falling back to FTP.
#2020-07-31 10:17:56 URL: ftps://arthurhou.pps.eosdis.nasa.gov/gpmuser/gpmgv/scripts/ [63035] -> "/home/dhis/wgettest/tmp/PPS_CS/.listing" [1]
#2020-07-31 10:17:57 URL: ftps://arthurhou.pps.eosdis.nasa.gov/gpmuser/gpmgv/scripts/ftp_url_202007150845.txt [5023] -> "/home/dhis/wgettest/tmp/PPS_CS/ftp_url_202007150845.txt" [1]
#FINISHED --2020-07-31 10:19:01--
#Total wall clock time: 1m 7s
#Downloaded: 194 files, 1.3M in 6.3s (207 KB/s)

length=${#FTPS}
((length=$length+1))
                        
# cat list of downloaded ftp_url files to main log file
cat $MIR_LOG_FILE | fgrep ${FPTS}ftps_url | cut -f4 -d" " | cut -c$length- >> $LOG_FILE

# check exit status of wget 

#     if [ $? != 0 ]
     if [ $status != 0 ]
     then
        echo "Error returned in wget!" | tee -a $LOG_FILE
        echo "status = " $status | tee -a $LOG_FILE
        if [ $tries -eq 10 ]
          then
             timedout='y'
             runagain='n'
             echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
 #            echo "UPDATE appstatus SET status = '$FAILED' \
 #              WHERE app_id = 'get_ITE_List' AND datestamp = '$rundate';" \
 #              | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
          else
             echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
             sleep $ZZZ
        fi
     else if [ -s $MIR_LOG_FILE ] # exists and contains data
       then
          #  THIS WAS MODIFIED TO NOT JUST LOOK AT THE ENTIRE LOG FILE, ELSE
          #  WE END UP RE-TRYING AFTER A SUCCESSFUL TRANSFER IF THERE WAS AN
	  #  EARLIER FAILURE INDICATED "HIGHER UP" IN THE LOG FILE.
          #  (FOUND WHEN RUN 1ST TIME AS 'gvoper' AND HAD PERMISSION ISSUES)
          grep -E '(Fatal|Failed|failed)' ${MIR_LOG_FILE} > /dev/null
          if [ $? = 0 ]
          then
             # check the last line only of the mirror log file to see if we had
	     # a successful transfer ("Got" in the text) or no files were found
	     # to transfer ("successful" in the last line) since the prior error
	     tail -n 1 $MIR_LOG_FILE | grep '(Got|successful|Downloaded)'  > /dev/null
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
       else if [ -f $MIR_LOG_FILE ] # exists but empty
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
    mail -s 'mirror update ITE' -c "denise.a.berendes@nasa.gov" todd.a.berendes@nasa.gov < $MIR_LOG_FILE
    echo "" | tee -a $LOG_FILE
    # see if any data files were actually downloaded, exit now if none
    grep ftps_url ${MIR_LOG_FILE} > /dev/null
    if [ $? != 0 ]
      then
        echo "No ftp listings files downloaded; exit." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        if [ "$timedout" = 'y' ]
	  then
            echo "Timed out after $tries failed tries." | tee -a $LOG_FILE
	         echo "UPDATE appstatus SET status = '$FAILED' \
             WHERE app_id = 'get_ITE_List' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	  else
            echo "UPDATE appstatus SET status = '$MISSING' \
             WHERE app_id = 'get_ITE_List' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	fi
        echo "" | tee -a $LOG_FILE
        echo "See log file $LOG_FILE for script output."
        mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListingsBAD_ITE.${rundate}.log \
             | tee -a $LOG_FILE 2>&1
        exit 1
      else
        echo "UPDATE appstatus SET status = '$SUCCESS' \
          WHERE app_id = 'get_ITE_List' AND datestamp = '$rundate';" \
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi
    echo ""  | tee -a $LOG_FILE
    echo "Renaming mirror log file to unique/datestamped:"  | tee -a $LOG_FILE
    mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListings_ITE.${rundate}.log | tee -a $LOG_FILE 2>&1
fi

#cat $LOG_FILE
echo ""  | tee -a $LOG_FILE
echo "SCRIPT getPPSftpListings_ITE.sh COMPLETE, EXITING." | tee -a $LOG_FILE
echo "See log file $LOG_FILE for script output."
echo "" | tee -a $LOG_FILE
exit
