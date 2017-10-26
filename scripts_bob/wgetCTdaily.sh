#!/bin/sh
#
################################################################################
#
#  wgetCTdaily.sh     Morris/SAIC/GPM GV     August 2006
#
#  DESCRIPTION
#    Retrieves latest TRMM coincidence file from PPS site:
#
#       pps.gsfc.nasa.gov
#
#    CT file for a given date is posted at around 1502 UTC on the following day.
#    CT file pattern is "CT.yyyymmdd.7" and they are located in the subdirectory 
#    trmmdata/shortTermAuxiliary/CT.
#    Following the successful download of the CT file(s), RidgeMosaicCTMatch.sh
#    is invoked to identify those NWS 'Ridge' NEXRAD reflectivity mosaic images
#    coincident with the PR overpasses.
#
#  ROUTINES CALLED
#    CT_to_DB.sh           - Reformats and subsets "CT.yyyymmdd.7" files for
#                            loading into database.
#    RidgeMosaicCTMatch.sh - Matches up NWS "Ridge" reflectivity mosaic images
#                            to PR coincidence times.
#
#  FILES
#    CT.yyyymmdd.7    - CT file retrieved from TSDIS ftp site.  Date yyyymmdd
#                       is determined by time script is run, and is either
#                       yesterday or day-before-yesterday.
#    CT.${yymmdd}.unl - Data from matching file CT.yyyymmdd.7, converted into a
#                       delimited format suitable for loading to PostGRESQL
#                       data table (ct_temp).
#    CTsToGet         - Temporary file listing the 'yymmdd' values of all the
#                       CT.yyyymmdd.7 files we want to get in the current run.
#    CT_dbtempfile    - Temporary file holding appstatus table output from a
#                       query.
#
#  DATABASE
#    Loads data into 'ct_temp' table in 'gpmgv' database in PostGRESQL via call
#    to psql utility.  Tracks status of CT file retrieval in 'appstatus' table.
#    See RidgeMosaicCTMatch.sh for additional database usage.
#
#  LOGS
#    Output for day's script run logged to daily log file wgetCTdaily.YYMMDD.log
#    in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table "ct_temp". 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $CT_DATA, $LOG_DIR directories
#
#  HISTORY
#    May 2008 - Morris - Modified to look for and download either CT.yymmdd.6
#                        or CT.yymmdd.6l files from TSDIS.  CT file names
#                        will have the CT.yymmdd.6l convention as of 6/1/08.
#    Jun 2008 - Morris - Modified URL/path/password to get to new PPS ftp site.
#    Oct 2010 - Morris - Removed username:password to PPS in wget ftp command,
#                        now looks to .netrc file for these defaults.
#    Mar 2011 - Morris - Fixed bug in how return values from 'ls' were checked,
#                        now always uses 'if [ $? = 0 ]' since 'ls' was
#                        returning a value of 2 for file not found!!
#    Jul 2011 - Morris - Modified to look for and download CT.yyyymmdd.7
#                        files from PPS.  CT file names have the CT.yymmdd.7
#                        convention as of V7 cutover.
#    Nov 2013 - Morris - Using >> rather than "| tee -a" to capture any psql
#                        error output in data load query (\copy).
#
################################################################################

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_table
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wgetCTdaily.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=1800

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${CT_DATA}/CT_dbtempfile
# file listing all yymmdd processed this run
FILES2DO=${CT_DATA}/CTsToGet
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
echo "===================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence file on $today." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wgetCTdaily.sh cron job on ${thistime}:" \
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

echo "Checking whether we have an entry for this CT date in database."\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';" | psql -a -d gpmgv \
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
      ('wgetCTdaily','$yymmdd','$UNTRIED');" | psql -a -d gpmgv \
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
      WHERE app_id = 'wgetCTdaily' AND status IN ('$MISSING','$UNTRIED') \
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
# in the database, and the current attempt date

STAMPLAST=`psql -q -t -d gpmgv -c "SELECT MAX(datestamp) FROM appstatus WHERE \
 app_id = 'wgetCTdaily' AND datestamp != '$yymmdd';"`
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
      ('wgetCTdaily','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
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
     echo "Need to retry downloads for missing CT file dates below:" \
       | tee -a $LOG_FILE
     cat ${DBTEMPFILE} | cut -f3 -d '|' | tee -a $LOG_FILE
     have_retries='t'
  else
     echo "" | tee -a $LOG_FILE
     echo "No missing prior CT dates found." | tee -a $LOG_FILE
     if [ $status = $SUCCESS ]
       then
	  echo "All CT acquisition seems up-to-date, exiting."\
	   | tee -a $LOG_FILE
	  exit 0
     fi
fi

# increment the ntries column in the appstatus table for $MISSING and $UNTRIED
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'wgetCTdaily' AND \
 status IN ('$MISSING','$UNTRIED');" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

# Get the missing old files first, if needed
if [ $have_retries = 't' ]
  then
     echo "Getting old missing CT files." | tee -a $LOG_FILE
     for file in `cat ${DBTEMPFILE} | cut -f3 -d '|'`
     do
       echo "Get CT.20${file}.7 from PPS ftp site." | tee -a $LOG_FILE
       ctunlfile=${CT_DATA}/CT.${file}.unl
       ctfile=`ls ${CT_DATA}/CT.20${file}.7`
       if [ $? = 0 ]
         then
	    echo "WARNING: Already have file ${ctfile}, not downloading again."\
	      | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
	      app_id = 'wgetCTdaily' AND datestamp = '$file';"\
	      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
            if [ ! -s $ctunlfile ]
	      then
	         echo "PROBLEM:  File $ctunlfile not found!" | tee -a $LOG_FILE
                 echo "Exiting with warnings/errors." | tee -a $LOG_FILE
                 exit 1
            fi
         else
            wget -P ${CT_DATA} \
              ftp://pps.gsfc.nasa.gov/./trmmdata/shortTermAuxiliary/CT/CT.20${file}.7
            ctfile=`ls ${CT_DATA}/CT.20${file}.7`
            if [ $? = 0 ]
              then
	         # - PROBABLY NEED TO MOVE FILES FROM trashedmosaic TO holding
		 #   AND RE-ENTER THEIR INFO IN THE heldmosaic TABLE
		 #   (but ONLY if we get all our old missing CT files?)
		 # - COULD BE A JOB FOR RidgeMosaicCTMatch.sh, IF GIVEN THE
		 #   NECESSARY CONTROL INFORMATION
		 echo "$file" >> $FILES2DO
                 echo "Got prior missing file CT.20${file}.7" | tee -a $LOG_FILE
		 echo "UPDATE appstatus SET status='$SUCCESS' WHERE \
		   app_id = 'wgetCTdaily' AND datestamp = '$file';"\
		   | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	      else
	         deletemove='m'
		 echo "Failed to retrieve CT.20${file}.7 from PPS ftp site!" \
		   | tee -a $LOG_FILE
	    fi
       fi
     done
fi

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 5 times.  Don't want to continue 'moving' rather than 'deleting' 
# non-coincident mosaic files for too many days if a CT file is missing.
echo "Set status to FAILED where this is the 5th failure for any downloads:"\
 | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'wgetCTdaily' AND \
 status='$MISSING' AND ntries > 4;" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1

# Next, get the current file if needed.  We will make multiple attempts at it as
# it might just be late, whereas we will only try once each to get other missing
# files.

if [ $status != $SUCCESS ]
  then
     echo ""  | tee -a $LOG_FILE
     echo "Download current file CT.20${yymmdd}.7 from PPS"  | tee -a $LOG_FILE
     # variables for output file pathnames, pre- and post-processing
     ctunlfile=${CT_DATA}/CT.${yymmdd}.unl
     ctfile=`ls ${CT_DATA}/CT.20${yymmdd}.7`

     # If desired file was already downloaded and processed, report problems
     if [ $? = 0 ]
       then
          runagain='n'
          echo "WARNING:  File $ctfile already exists, not downloading again." \
	    | tee -a $LOG_FILE
	  echo "UPDATE appstatus SET status='$DUPLICATE' WHERE \
	    app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';"\
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

     # Use wget to download coincidence file CT.yyyymmdd.7 from PPS ftp site. 
     # Repeat attempts at intervals of $ZZZ seconds if file is not retrieved in
     # first attempt.  If file is still not found, record the failure in the
     # database to try to get in again in the next days' run(s) of the script.
     # Place downloaded file in coincidence_table subdirectory

     declare -i tries=0

     until [ "$runagain" = 'n' ]
       do
          tries=tries+1
          echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
          wget -P ${CT_DATA} \
            ftp://pps.gsfc.nasa.gov/./trmmdata/shortTermAuxiliary/CT/CT.20${yymmdd}.7
          ctfile=`ls ${CT_DATA}/CT.20${yymmdd}.7`
          if [ $? = 0 ]
            then
               runagain='n'
               ls ${CT_DATA}/CT.20${yymmdd}.7 | tee -a $LOG_FILE
               echo "$yymmdd" >> $FILES2DO
               echo "Got it!  Mark success in database:" | tee -a $LOG_FILE
               echo "" | tee -a $LOG_FILE
	       echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
	        app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';"\
		| psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
            else
               if [ $tries -eq 5 ]
                 then
                    runagain='n'
                    echo "Failed after 5 tries, giving up." | tee -a $LOG_FILE
	            echo "UPDATE appstatus SET status = '$MISSING' WHERE\
		      app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';"\
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

#  Check for presence of downloaded files, process if any

if [ -s $FILES2DO ]
  then
     if [ ! -x ${BIN_DIR}/CT_to_DB.sh ]
       then
          echo "Executable file '${BIN_DIR}/CT_to_DB.sh' not found!" \
            | tee -a $LOG_FILE
          exit 1
     fi
     
     echo "Calling CT_to_DB.sh to process file(s):" | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     for iofile in `cat $FILES2DO`
       do
          ctfile=`ls ${CT_DATA}/CT.20${iofile}.7`
          ctunlfile=${CT_DATA}/CT.${iofile}.unl
          echo "Reformat this CT file for loading into ct_temp table in DB:" \
	    | tee -a $LOG_FILE
          ls -al $ctfile | tee -a $LOG_FILE
	  echo "" | tee -a $LOG_FILE
          ${BIN_DIR}/CT_to_DB.sh  $ctfile $ctunlfile | tee -a $LOG_FILE

          echo "Load following .unl file from CT_to_DB.sh to database:" \
           | tee -a $LOG_FILE
          ls -al $ctunlfile | tee -a $LOG_FILE
          echo "" | tee -a $LOG_FILE

          echo "\copy ct_temp FROM '${ctunlfile}' WITH DELIMITER '|'" \
            | psql -a -d gpmgv >> $LOG_FILE 2>&1
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
