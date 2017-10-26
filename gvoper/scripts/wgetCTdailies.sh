#!/bin/sh
#
################################################################################
#
#  wgetCTdailies.sh     Morris/SAIC/GPM GV     February 2014
#
#  DESCRIPTION
#    Retrieves core/constellation satellite coincidence files from PPS site:
#
#       arthurhou.eosdis.nasa.gov
#
#    CT files for a given date get posted at around 1502 UTC on the next day.
#    CT file pattern is "CT.SSSS.yyyymmdd.jjj.txt" and they are located in the
#    subdirectory TBD.
#
#    The CT file naming convntion is CT.SSSS.yyyymmdd.jjj.txt, where:
#
#          CT - literal characters 'CT'
#        SSSS - ID of the satellite, variable length character field
#    yyyymmdd - year (4-digit), month, and day of the overpass data
#         jjj - day of year (Julian day), zero-padded to 3 digits
#         txt - literal characters 'txt'
#
#    Following the successful download of the CT file(s), RidgeMosaicCTMatch.sh
#    is invoked to identify those NWS 'Ridge' NEXRAD reflectivity mosaic images
#    coincident with the PR overpasses.
#
#  ROUTINES CALLED
#    new_CT_to_DB.sh       - Reformats and subsets "CT" files for loading
#                            into 'gpmgv' database.
#    RidgeMosaicCTMatch.sh - Matches up NWS "Ridge" reflectivity mosaic images
#                            to PR/DPR coincidence times.
#
#  FILES
#    CT.SSSS.yyyymmdd.jjj.txt
#      - CT files to be retrieved from PPS ftp site.  Date yyyymmdd
#        is determined by time script is run, and is either
#        yesterday or day-before-yesterday.
#
#    CT.SSSS.yyyymmdd.jjj.unl
#       - Data from matching file CT.SSSS.yyyymmdd.jjj.txt, converted into a
#         delimited format suitable for loading to PostGRESQL data table ct_temp
#
#    CTsToGet
#       - Temporary file listing the 'yymmdd' values of all the
#         CT.SSSS.yyyymmdd.jjj.txt files we want to get in the current run.
#
#    CT_dbtempfile
#       - Temporary file holding appstatus table output from a query.
#
#  DATABASE
#    Loads data into 'ct_temp' table in 'gpmgv' database in PostGRESQL via call
#    to psql utility.  Tracks status of CT file retrieval in 'appstatus' table.
#    See RidgeMosaicCTMatch.sh for additional database usage.
#
#  LOGS
#    Output for day's script run logged to daily log file wgetCTdailies.YYMMDD.log
#    in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table "ct_temp". 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $CT_DATA, $LOG_DIR directories
#
#  HISTORY
#    Mar 2014 - Morris - Created from wgetCTdaily.
#    04/18/14 - Morris - Modified to fail after 10 attempts rather than 5.
#    08/06/14 - Morris - Moved CT_dbtempfile and CTsToGet from CT_DATA to
#                        TMP_DIR so that they aren't mirrored on ftp site.
#    08/26/14 - Morris - Changed LOG_DIR to /data/logs, TMP_DIR to /data/tmp
#    09/05/14 - Morris - Changed FIXEDPATH directory to /gpmdata/coincidence
#    10/29/14 - Morris - Belatedly added METOPB to the satellite list
#    09/11/15 - Morris - Removing TRMM and F15 from satellite list
#    07/26/16 - Morris - Added F19 and NPP to satellite list
#
################################################################################

GV_BASE_DIR=/home/gvoper
MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
CT_DATA=${DATA_DIR}/coincidence_tables
TMP_DIR=/data/tmp
SAT_LIST=${CT_DATA}/SATELLITES_FOR_CT.txt
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wgetCTdailies.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=10
USERPASS=kenneth.r.morris@nasa.gov
FIXEDPATH='ftp://arthurhou.pps.eosdis.nasa.gov/gpmdata/coincidence'

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/CT_dbtempfile
# file listing all yymmdd processed this run
FILES2DO=${TMP_DIR}/CTsToGet
rm -f $FILES2DO

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired CT file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error

have_retries='f'  # indicates whether we have missing prior CT filedates to retry
status=$UNTRIED   # assume we haven't yet tried to get current CT file
deletemove='d'    # controls whether non-coincident mosaics will be deleted (d)
                  # or just moved (m).  If we still have missing CT downloads 
		  # from previous attempts, we will ask RidgeMosaicCTMatch.sh
		  # to move instead of delete so that we can attempt matchups at
		  # a later date when CT file is available.

today=`date -u +%Y%m%d`
echo "====================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence files on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wgetCTdailies.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

#  Get the date string for desired day's date by calling offset_date.
#  $switchtime is UTC HHMM after which yesterday's CT file is expected to
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

echo "Time is $now UTC, getting CT file for date $yymmdd" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# HANDLE EACH SATELLITE SEPARATELY, ONE AT A TIME

for sat in GPM GCOMW1 F16 F17 F18 F19 METOPA METOPB NOAA18 NOAA19 NPP
  do
    echo "Checking whether we have $sat entries for CT date in database."\
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
     app_id = 'wgetCT${sat}' AND datestamp = '$yymmdd';" | psql -a -d gpmgv \
     | tee -a $LOG_FILE 2>&1

    if [ -s ${DBTEMPFILE} ]
      then
         # We've tried to get this CT file before, check our past status.
         status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
         echo "" | tee -a $LOG_FILE
         echo "Have status=${status} from prior attempt." | tee -a $LOG_FILE
      else
         # Empty file indicates no row exists for this file datestamp, so insert one
         # now with defaults for first_attempt and ntries columns
         echo "" | tee -a $LOG_FILE
         echo "No prior attempt, initialize status in database:" | tee -a $LOG_FILE
         echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
          ('wgetCT${sat}','$yymmdd','$UNTRIED');" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
    fi

    echo "" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "Checking whether we have prior missing CT datestamps to process."\
      | tee -a $LOG_FILE

    echo "Check for actual prior attempts which failed for external reasons:"\
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
          WHERE app_id = 'wgetCT${sat}' AND status IN ('$MISSING','$UNTRIED') \
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
    # in the database, and the current attempt date.  If no entries for this CT
    # exists (1st time run for this CTsat), then substitute $yymmdd for the last
    # attempt's date via COALESCE in SQL to prevent script errors

    STAMPLAST=`psql -q -t -d gpmgv -c "SELECT COALESCE(MAX(datestamp),'$yymmdd')\
     FROM appstatus WHERE app_id = 'wgetCT${sat}' AND datestamp != '$yymmdd';"`
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
          ('wgetCT${sat}','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
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
         echo "Need to retry $sat downloads for missing CT file dates below:" \
           | tee -a $LOG_FILE
         cat ${DBTEMPFILE} | cut -f3 -d '|' | tee -a $LOG_FILE
         have_retries='t'
      else
         echo "" | tee -a $LOG_FILE
         echo "No missing prior CT dates found." | tee -a $LOG_FILE
         if [ $status = $SUCCESS ]
           then
              echo "All $sat CT acquisition seems up-to-date."\
    	      | tee -a $LOG_FILE
#	      exit 0
         fi
    fi

    # increment the ntries column in the appstatus table for $MISSING and $UNTRIED
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'wgetCT${sat}' AND \
     status IN ('$MISSING','$UNTRIED');" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE

    # Get the missing old files first, if needed
    if [ $have_retries = 't' ]
      then
         echo "Getting old missing $sat CT files." | tee -a $LOG_FILE
         for file in `cat ${DBTEMPFILE} | cut -f3 -d '|'`
         do
           ctdate=20$file
           #  Get the subdirectory on the ftp site under which our day's data are located,
           #  in the format YYYY/MM/DD
           daydir=`echo $ctdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
           # make the new date-specific directory as required
           mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE
           #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
           juldatelast=`ymd2yd $ctdate`
           jjj=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
           TARGET_CT=CT.${sat}.${ctdate}.${jjj}.txt
           echo "Get $TARGET_CT from PPS ftp site." | tee -a $LOG_FILE
           ctunlfile=${CT_DATA}/${daydir}/CT.${sat}.${ctdate}.${jjj}.unl
           ctfile=`ls ${CT_DATA}/${daydir}/${TARGET_CT}`
           if [ $? = 0 ]
             then
	        echo "WARNING: Already have file ${ctfile}, not downloading again."\
	          | tee -a $LOG_FILE
	        echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
	          app_id = 'wgetCT${sat}' AND datestamp = '$file';"\
	          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
                if [ ! -s $ctunlfile ]
	          then
	             echo "PROBLEM:  File $ctunlfile not found!" | tee -a $LOG_FILE
                     echo "Exiting with warnings/errors." | tee -a $LOG_FILE
                     exit 1
                fi
             else
                wget -P ${CT_DATA}/${daydir}  --user=$USERPASS --password=$USERPASS \
                  $FIXEDPATH/${daydir}/${TARGET_CT}
                ctfile=`ls ${CT_DATA}/${daydir}/${TARGET_CT}`
                if [ $? = 0 ]
                  then
	             # - PROBABLY NEED TO MOVE FILES FROM trashedmosaic TO holding
		     #   AND RE-ENTER THEIR INFO IN THE heldmosaic TABLE
		     #   (but ONLY if we get all our old missing CT files?)
		     # - COULD BE A JOB FOR RidgeMosaicCTMatch.sh, IF GIVEN THE
		     #   NECESSARY CONTROL INFORMATION
		     echo "${ctfile}|${ctunlfile}" >> $FILES2DO
                     echo "Got prior missing file ${ctfile}" | tee -a $LOG_FILE
		     echo "UPDATE appstatus SET status='$SUCCESS' WHERE \
		       app_id = 'wgetCT${sat}' AND datestamp = '$file';"\
		       | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	          else
	             deletemove='m'
		     echo "Failed to retrieve ${TARGET_CT} from PPS ftp site!" \
		       | tee -a $LOG_FILE
	        fi
           fi
         done
    fi

    # set status to $FAILED in the appstatus table for $MISSING rows where ntries
    # reaches 10 times.  Don't want to continue 'moving' rather than 'deleting' 
    # non-coincident mosaic files for too many days if a CT file is missing.
    echo "Set status to FAILED where this is the 10th failure for any downloads:"\
     | tee -a $LOG_FILE
    echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'wgetCT${sat}' AND \
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
         # make the new date-specific directory as required
         mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE
         #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
         juldatelast=`ymd2yd $ctdate`
         jjj=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
         TARGET_CT=CT.${sat}.${ctdate}.${jjj}.txt
         echo ""  | tee -a $LOG_FILE
         echo "Download current file ${TARGET_CT} from PPS"  | tee -a $LOG_FILE
         # variables for output file pathnames, pre- and post-processing
         ctunlfile=${CT_DATA}/${daydir}/CT.${sat}.${ctdate}.${jjj}.unl
         ctfile=`ls ${CT_DATA}/${daydir}/${TARGET_CT}`

         # If desired file was already downloaded and processed, report problems
         if [ $? = 0 ]
           then
              runagain='n'
              echo "WARNING:  File $ctfile already exists, not downloading again." \
	        | tee -a $LOG_FILE
	      echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
	        app_id = 'wgetCT${sat}' AND datestamp = '$yymmdd';"\
	        | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
              if [ ! -s $ctunlfile ]
                then
                   echo "PROBLEM:  File $ctunlfile not found!" \
                     | tee -a $LOG_FILE
                   echo "Exiting with warnings/errors." | tee -a $LOG_FILE
                   exit 1
              fi
           else
              runagain='y'
         fi

         # Otherwise, use wget to download coincidence file from PPS ftp site. 
         # Repeat attempts at intervals of $ZZZ seconds if file is not retrieved in
         # first attempt.  If file is still not found, record the failure in the
         # database to try to get in again in the next days' run(s) of the script.
         # Place downloaded file in coincidence_table subdirectory

         declare -i tries=0

         until [ "$runagain" = 'n' ]
           do
              tries=tries+1
              echo "Try = ${tries}, max = 2." | tee -a $LOG_FILE
              wget -P ${CT_DATA}/${daydir}  --user=$USERPASS --password=$USERPASS \
                $FIXEDPATH/${daydir}/${TARGET_CT}
              ctfile=`ls ${CT_DATA}/${daydir}/${TARGET_CT}`
              if [ $? = 0 ]
                then
                   runagain='n'
                   #ls ${CT_DATA}/${daydir}/${TARGET_CT} | tee -a $LOG_FILE
                   echo "${ctfile}|${ctunlfile}" >> $FILES2DO
                   echo "Got it!  Mark success in database:" | tee -a $LOG_FILE
                   echo "" | tee -a $LOG_FILE
	           echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
	            app_id = 'wgetCT${sat}' AND datestamp = '$yymmdd';"\
		    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
                else
                   if [ $tries -eq 2 ]
                     then
                        runagain='n'
                        echo "Failed after 2 tries, giving up." | tee -a $LOG_FILE
	                echo "UPDATE appstatus SET status = '$MISSING' WHERE\
		          app_id = 'wgetCT${sat}' AND datestamp = '$yymmdd';"\
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
     if [ ! -x ${BIN_DIR}/new_CT_to_DB.sh ]
       then
          echo "Executable file '${BIN_DIR}/new_CT_to_DB.sh' not found!" \
            | tee -a $LOG_FILE
          exit 1
     fi
     
     echo "Calling new_CT_to_DB.sh to process file(s):" | tee -a $LOG_FILE
     #cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     for iofile in `cat $FILES2DO`
       do
          ctfile=`echo $iofile | cut -f1 -d '|'`
          ctunlfile=`echo $iofile | cut -f2 -d '|'`
          echo "Reformat this CT file for loading into ct_temp table in DB:" \
	    | tee -a $LOG_FILE
          ls -al $ctfile | tee -a $LOG_FILE
	  echo "" | tee -a $LOG_FILE
          ${BIN_DIR}/new_CT_to_DB.sh  $ctfile $ctunlfile | tee -a $LOG_FILE

          echo "Load following .unl file from new_CT_to_DB.sh to database:" \
           | tee -a $LOG_FILE
          ls -al $ctunlfile | tee -a $LOG_FILE
          echo "" | tee -a $LOG_FILE

          echo "\copy ct_temp(orbit,proximity,overpass_time,radar_id,radar_name)\
             FROM '${ctunlfile}' WITH DELIMITER '|'" | psql -a -d gpmgv >> $LOG_FILE 2>&1
          echo "" | tee -a $LOG_FILE
     done
     
     echo "Calling RidgeMosaicCTMatch.sh to match/clean up Ridge mosaic files" \
       | tee -a $LOG_FILE
     echo "and load coincident event and mosaic metadata to overpass_event" \
       | tee -a $LOG_FILE
     echo "and coincident_mosaic database tables, respectively."\
       | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     echo "Mosiac file delete/move instruction = $deletemove" | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     echo "See log file RidgeMosaicCTMatch.${rundate}.log."\
       | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     if [ ! -x ${BIN_DIR}/RidgeMosaicCTMatch.sh ]
       then
          echo "Executable file '${BIN_DIR}/RidgeMosaicCTMatch.sh' not found!" \
            | tee -a $LOG_FILE
          exit 1
       else
          ${BIN_DIR}/RidgeMosaicCTMatch.sh $deletemove > /dev/null 2>&1
	  if [ $? = 1 ]
	    then
	       echo "Fatal error in RidgeMosaicCTMatch.sh, exiting!" \
	         | tee -a $LOG_FILE
	       exit 1
	  fi
     fi
  else
    echo "File $FILES2DO not found, no new CT files or downloads failed." \
      | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
