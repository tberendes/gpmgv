#!/bin/sh
#
################################################################################
#
#  wget_GT7_GPM.sh     Morris/SAIC/GPM GV     May 2015
#
#  DESCRIPTION
#    Retrieves GPM satellite 1-s, 7-day ground track files from PPS site:
#
#       arthurhou.eosdis.nasa.gov
#
#    GT file pattern is "GT-7.GPM.yyyymmdd.jjj.txt" and they are located in the
#    subdirectory gpmdata/coincidence in a day-specific directory structure.
#    Downloaded files are stored in year-specific directories under the top
#    level directory GT_DATA defined in this script.
#
#    The GT file naming convention is GT-7.SSSS.yyyymmdd.jjj.txt, where:
#
#        GT-7 - literal characters 'GT-7'
#        SSSS - ID of the satellite ('GPM' only for this script)
#    yyyymmdd - year (4-digit), month, and day of the overpass data
#         jjj - day of year (Julian day), zero-padded to 3 digits
#         txt - literal characters 'txt'
#
#  FILES
#    GT-7.SSSS.yyyymmdd.jjj.txt
#      - GT-7 files to be retrieved from PPS ftp site.  Date yyyymmdd
#        is determined by time script is run, and is either
#        yesterday or day-before-yesterday.
#
#    GTsToGet
#       - Temporary file listing the 'yymmdd' values of all the
#         GT-7.SSSS.yyyymmdd.jjj.txt files we want to get in the current run.
#
#    GT_dbtempfile
#       - Temporary file holding appstatus table output from a query.
#
#  LOGS
#    Output for day's script run logged to daily log file wget_GT7_GPM.YYMMDD.log
#    in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table "ct_temp". 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $GT_DATA, $LOG_DIR directories
#
#  HISTORY
#    May 2015 - Morris - Created from wgetCTdailies.sh.
#    Jun 2016 - Morris - Fixed argument to mkdir for current day GT block.
#    08/06/20 - Berendes - Changed wget to ftps and user to todd.a.berendes@nasa.gov
#
################################################################################

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/tmp
  else
    DATA_DIR=/data/tmp
fi

export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
GT_DATA=${DATA_DIR}/ground_track_7day
TMP_DIR=/data/tmp
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wget_GT7_GPM.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=1
#USERPASS=kenneth.r.morris@nasa.gov
USERPASS=todd.a.berendes@nasa.gov
#FIXEDPATH='ftp://arthurhou.pps.eosdis.nasa.gov/gpmdata/coincidence'
FIXEDPATH='ftps://arthurhou.pps.eosdis.nasa.gov/gpmdata/coincidence'

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/GT_dbtempfile
# listing of all files retrieved in this run
FILES2DO=${TMP_DIR}/GTsToGet
rm -f $FILES2DO

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired GT file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error

have_retries='f'  # indicates whether we have missing prior GT filedates to retry
status=$UNTRIED   # assume we haven't yet tried to get current GT file

today=`date -u +%Y%m%d`
echo "====================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence files on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wget_GT7_GPM.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c todd.a.berendes@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

#  Get the date string for desired day's date by calling offset_date.
#  $switchtime is UTC HHMM after which yesterday's GT file is expected to
#  be available in TSDIS ftp directory.
switchtime=1503
now=`date -u "+%H%M"`

if [ `expr $now \> $switchtime` = 1 ]
  then
#    yesterday's file should be ready, get it
     ctdate=`offset_date $today -1`
  else
#    otherwise get file from two days back
     ctdate=`offset_date $today -2`
fi

#  Trim date string to use a 2-digit year, as in DB timestamp convention
yymmdd=`echo $ctdate | cut -c 3-8`

echo "Time is $now UTC, getting GT file for date $yymmdd" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# HANDLE EACH SATELLITE SEPARATELY, ONE AT A TIME

for sat in GPM
  do
    echo "Checking whether we have $sat entries for GT date in database."\
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
     app_id = 'wgetGT${sat}' AND datestamp = '$yymmdd';" | psql -a -d gpmgv \
     | tee -a $LOG_FILE 2>&1

    if [ -s ${DBTEMPFILE} ]
      then
         # We've tried to get this GT file before, check our past status.
         status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
         echo "" | tee -a $LOG_FILE
         echo "Have status=${status} from prior attempt." | tee -a $LOG_FILE
      else
         # Empty file indicates no row exists for this file datestamp, so insert one
         # now with defaults for first_attempt and ntries columns
         echo "" | tee -a $LOG_FILE
         echo "No prior attempt, initialize status in database:" | tee -a $LOG_FILE
         echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
          ('wgetGT${sat}','$yymmdd','$UNTRIED');" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
    fi

    echo "" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "Checking whether we have prior missing GT datestamps to process."\
      | tee -a $LOG_FILE

    echo "Check for actual prior attempts which failed for external reasons:"\
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
          WHERE app_id = 'wgetGT${sat}' AND status IN ('$MISSING','$UNTRIED') \
          AND datestamp != '$yymmdd';" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
    if [ -s ${DBTEMPFILE} ]
      then
        echo "Dates of prior MISSING:" | tee -a $LOG_FILE
        cat ${DBTEMPFILE} | cut -f3 -d '|' | tee -a $LOG_FILE
      else
        echo "No prior dates with status MISSING." | tee -a $LOG_FILE
    fi

    echo "" | tee -a $LOG_FILE
    echo "Check for prior dates never attempted due to local problems:"\
      | tee -a $LOG_FILE
    # Do so by looking for a gap in dates of >1 between last attempt registered
    # in the database, and the current attempt date.  If no entries for this GT
    # exists (1st time run for this GTsat), then substitute $yymmdd for the last
    # attempt's date via COALESCE in SQL to prevent script errors

    STAMPLAST=`psql -q -t -d gpmgv -c "SELECT COALESCE(MAX(datestamp),'$yymmdd')\
     FROM appstatus WHERE app_id = 'wgetGT${sat}' AND datestamp != '$yymmdd';"`
    echo "" | tee -a $LOG_FILE
    echo "Last date previously attempted was $STAMPLAST" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    DATELAST=`echo 20$STAMPLAST | sed 's/ //'`
    DATEGAP=`grgdif $ctdate $DATELAST`

    while [ `expr $DATEGAP \> 1` = 1 ]
      do
        DATELAST=`offset_date $DATELAST 1`
        yymmddNever=`echo $DATELAST | cut -c 3-8`
        echo "No prior attempt of $yymmddNever, initialize status in database:"\
          | tee -a $LOG_FILE
        echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
          ('wgetGT${sat}','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
        # add this date to the temp file, preceded by bogus '|'-delimited values
        # so the format is compatible with the MISSING dates query output
        echo "bogus1|bogus2|"$yymmddNever >> ${DBTEMPFILE}
        DATEGAP=`grgdif $ctdate $DATELAST`
        echo "" | tee -a $LOG_FILE
    done

    if [ -s ${DBTEMPFILE} ]
      then
         echo "" | tee -a $LOG_FILE
         echo "Need to retry $sat downloads for missing GT file dates below:" \
           | tee -a $LOG_FILE
         cat ${DBTEMPFILE} | cut -f3 -d '|' | tee -a $LOG_FILE
         have_retries='t'
      else
         echo "" | tee -a $LOG_FILE
         echo "No missing prior GT dates found." | tee -a $LOG_FILE
         if [ $status = $SUCCESS ]
           then
              echo "All $sat GT acquisition seems up-to-date."\
                  | tee -a $LOG_FILE
#              exit 0
         fi
    fi
#exit
    # increment the ntries column in the appstatus table for $MISSING and $UNTRIED
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'wgetGT${sat}' AND \
     status IN ('$MISSING','$UNTRIED');" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE

    # Get the missing old files first, if needed
    if [ $have_retries = 't' ]
      then
         echo "Getting old missing $sat GT files." | tee -a $LOG_FILE
         for file in `cat ${DBTEMPFILE} | cut -f3 -d '|'`
         do
           ctdate=20$file
           #  Get the subdirectory on the ftp site under which our day's data are located,
           #  in the format YYYY/MM/DD
           daydir=`echo $ctdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
           # make the new year-specific directory as required
           yeardir=`echo $daydir | cut -f1 -d '/'`
           mkdir -p -v ${GT_DATA}/${yeardir} | tee -a $LOG_FILE
           #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
           juldatelast=`ymd2yd $ctdate`
           jjj=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
           TARGET_GT=GT-7.${sat}.${ctdate}.${jjj}.txt
           echo "Get $TARGET_GT from PPS ftp site." | tee -a $LOG_FILE
           ctfile=`ls ${GT_DATA}/${yeardir}/${TARGET_GT}`
           if [ $? = 0 ]
             then
                echo "WARNING: Already have file ${ctfile}, not downloading again."\
                  | tee -a $LOG_FILE
                echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
                  app_id = 'wgetGT${sat}' AND datestamp = '$file';"\
                  | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
             else
                wget -P ${GT_DATA}/${yeardir}  --user=$USERPASS --password=$USERPASS --ftps-fallback-to-ftp \
                  $FIXEDPATH/${daydir}/${TARGET_GT}
                ctfile=`ls ${GT_DATA}/${yeardir}/${TARGET_GT}`
                if [ $? = 0 ]
                  then
                     echo "${ctfile}" >> $FILES2DO
                     echo "Got prior missing file ${ctfile}" | tee -a $LOG_FILE
                     echo "UPDATE appstatus SET status='$SUCCESS' WHERE \
                       app_id = 'wgetGT${sat}' AND datestamp = '$file';"\
                       | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
                  else
                     echo "Failed to retrieve missing file ${TARGET_GT} from PPS ftp site!" \
                       | tee -a $LOG_FILE
                fi
           fi
         done
    fi

    # set status to $FAILED in the appstatus table for $MISSING rows where ntries
    # reaches 10 times.  Don't want to continue 'moving' rather than 'deleting' 
    # non-coincident mosaic files for too many days if a GT file is missing.
    echo "Set status to FAILED where this is the 10th failure for any downloads:"\
     | tee -a $LOG_FILE
    echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'wgetGT${sat}' AND \
     status='$MISSING' AND ntries > 9;" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1

    # Next, get the current file if needed.  We will make multiple attempts at it as
    # it might just be late, whereas we will only try once each to get other missing
    # files.

    if [ $status != $SUCCESS ]
      then
         ctdate=20$yymmdd
         #  Get the subdirectory on the ftp site under which our day's data are located,
         #  in the format YYYY/MM/DD
         daydir=`echo $ctdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
         # make the new year-specific directory as required
         yeardir=`echo $daydir | cut -f1 -d '/'`
         mkdir -p -v ${GT_DATA}/${yeardir} | tee -a $LOG_FILE
         #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
         juldatelast=`ymd2yd $ctdate`
         jjj=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
         TARGET_GT=GT-7.${sat}.${ctdate}.${jjj}.txt
         echo ""  | tee -a $LOG_FILE
         echo "Download current file ${TARGET_GT} from PPS"  | tee -a $LOG_FILE

         ctfile=`ls ${GT_DATA}/${yeardir}/${TARGET_GT}`
         # If desired file was already downloaded and processed, report problems
         if [ $? = 0 ]
           then
              runagain='n'
              echo "WARNING:  File $ctfile already exists, not downloading again." \
                | tee -a $LOG_FILE
              echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
                app_id = 'wgetGT${sat}' AND datestamp = '$yymmdd';"\
                | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
           else
              runagain='y'
         fi

         # Otherwise, use wget to download coincidence file from PPS ftp site. 
         # Repeat attempts at intervals of $ZZZ seconds if file is not retrieved in
         # first attempt.  If file is still not found, record the failure in the
         # database to try to get in again in the next days' run(s) of the script.
         # Place downloaded file in ground_track_7day/$yeardir subdirectory

         declare -i tries=0

         until [ "$runagain" = 'n' ]
           do
              tries=tries+1
              echo "Try = ${tries}, max = 2." | tee -a $LOG_FILE
              wget -P ${GT_DATA}/${yeardir}  --user=$USERPASS --password=$USERPASS --ftps-fallback-to-ftp \
                $FIXEDPATH/${daydir}/${TARGET_GT}
              ctfile=`ls ${GT_DATA}/${yeardir}/${TARGET_GT}`
              if [ $? = 0 ]
                then
                   runagain='n'
                   #ls ${GT_DATA}/${yeardir}/${TARGET_GT} | tee -a $LOG_FILE
                   echo "${ctfile}" >> $FILES2DO
                   echo "Got current file ${ctfile}" | tee -a $LOG_FILE
                   echo "Mark success in database:" | tee -a $LOG_FILE
                   echo "" | tee -a $LOG_FILE
                   echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
                    app_id = 'wgetGT${sat}' AND datestamp = '$yymmdd';"\
                    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
                else
                   if [ $tries -eq 2 ]
                     then
                        runagain='n'
                        echo "Failed to get current file ${ctfile}" \
                             | tee -a $LOG_FILE
                        echo "UPDATE appstatus SET status = '$MISSING' WHERE\
                          app_id = 'wgetGT${sat}' AND datestamp = '$yymmdd';"\
                          | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
                     else
                        echo "Failed to get file, sleeping $ZZZ s before next try."\
                          | tee -a $LOG_FILE
                        sleep $ZZZ
                   fi
              fi
         done
    fi
    echo "" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

done     # end of the big for loop over each satellite ID

#  Check for presence of downloaded files, process if any

if [ -s $FILES2DO ]
  then
     #cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     echo "Calling extract_daily_predicts.sh $FILES2DO" | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     extract_daily_predicts.sh $FILES2DO | tee -a $LOG_FILE 2>&1
  else
    echo "File $FILES2DO not found, no new GT files or downloads failed." \
      | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
