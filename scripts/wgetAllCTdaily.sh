#!/bin/sh
#
################################################################################
#
#  wgetAllCTdailyForNMQ.sh     Morris/SAIC/GPM GV     February 2014
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
#    Following the successful download of the CT file(s), the utility script
#    get_Q2_time_matches_from_CTs.sh is invoked to identify those Q2 times
#    coincident with the satellite overpasses.
#
#  ROUTINES CALLED
#    new_CT_to_DB.sh                 - Reformats and subsets CT files for
#                                      loading into database.
#    get_Q2_time_matches_from_CTs.sh - Matches up Q2 product times
#                                      to satellite coincidence times.
#
#  FILES
#    CT.SSSS.yyyymmdd.jjj.txt
#      - CT file retrieved from TSDIS ftp site.  Date yyyymmdd
#        is determined by time script is run, and is either
#        yesterday or day-before-yesterday.
#    CT.SSSS.yyyymmdd.jjj.unl
#      - Data from matching file CT.SSSS.yyyymmdd.jjj.txt, converted into a
#        delimited format suitable for loading to PostGRESQL
#        data table (ct_temp).
#    CTsToGet
#      - Temporary file listing the 'SSSS.yyyymmdd' values of all
#        the PPS CT files we want to get in the current run.
#    CTs_missing
#      - Status file holding a listing the 'SSSS.yyyymmdd' values of all
#        expected CT files that failed to be found and/or downloaded in prior
#        script runs.
#
#  LOGS
#    Output for day's script run logged to daily log file wgetAllCTdaily.YYMMDD.log
#    in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User must have write privileges in $CT_DATA, $LOG_DIR directories
#
#  HISTORY
#    Feb 2014 - Morris - Created from wgetCTdaily.sh.
#
################################################################################

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_tables
SAT_LIST=${CT_DATA}/SATELLITES_FOR_CT.txt
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
today=`date -u +%Y%m%d`
LOG_FILE=${LOG_DIR}/wgetAllCTdaily.${today}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=2
USERPASS=kenneth.r.morris@nasa.gov
#FIXEDPATH='@arthurhou.pps.eosdis.nasa.gov/gpmallversions/coincidence/'
FIXEDPATH='ftp://arthurhou.pps.eosdis.nasa.gov/pub/trmmdata/shortTermAuxiliary/CT'
umask 0002

# file to hold list of SSSS.yyyymmdd values from missed CT download attempts
DBTEMPFILE=${CT_DATA}/CTs_All_missing

# file to hold list of new SSSS.yyyymmdd values for today's CT download attempt
TODAYSFILES=${CT_DATA}/CTs_All_today
rm -fv $TODAYSFILES | tee $LOG_FILE

# temporary file copy of $DBTEMPFILE
TEMPCOPY=${CT_DATA}/CTs_All_missing_COPY

# file to hold list of SSSS.yyyymmdd values from five-time failed CT download attempts
CTFAILURE=${CT_DATA}/CTs_All_FailedAfter5times

# file listing all downloaded SSSS.yyyymmdd to be post-processed this run
FILES2DO=${CT_DATA}/CTs_All_ToGet
rm -fv $FILES2DO | tee -a $LOG_FILE

# Constants for possible status of downloads
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error
INCOMPLETE='I' # got fewer than all configured CT files for a date

status=$SUCCESS

have_retries='f'  # indicates whether we have missing prior CT filedates to retry

deletemove='d'    # controls whether non-coincident mosaics will be deleted (d)
                  # or just moved (m).  If we still have missing CT downloads 
		  # from previous attempts, we will ask RidgeMosaicCTMatch.sh
		  # to move instead of delete so that we can attempt matchups at
		  # a later date when CT file is available.

echo "====================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence files on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
if [ ! -s ${SAT_LIST} ]
  then
    echo "Nonexistent or empty satellite list file: ${SAT_LIST}, exiting with error."\
         | tee -a $LOG_FILE
    exit 1
fi

#  Get the date string for desired day's date by calling offset_date.
#  $switchtime is UTC HHMM after which yesterday's CT files are expected to
#  be available in PPS ftp directory.
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

#  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
julctdate=`ymd2yd $ctdate`
jjj=`echo $julctdate | cut -c 5-7`  # extracting just the jjj part

#  Get the subdirectory on the ftp site under which our day's data are located,
#  in the format YYYY/MM/DD
daydir=`echo $ctdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`

# make the new date-specific directory as required
mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE

#  Trim date string to use a 2-digit year for DB timestamp
yymmdd=`echo $ctdate | cut -c 3-8`

echo "Time is $now UTC, getting CT files for date $yymmdd" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

for sat in `cat $SAT_LIST`
  do
    echo "Checking whether we have necessary files for this CT date."\
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    TARGET_CT=${daydir}/CT.${sat}.${ctdate}.${jjj}.txt
    ctfile=`ls ${CT_DATA}/${TARGET_CT}`
    if [ $? = 0 ]
      then
        echo "NOTE: Already have file ${ctfile}, not downloading again."\
    	      | tee -a $LOG_FILE
      else
        grep ${TARGET_CT} ${DBTEMPFILE} > /dev/null
        if  [ $? = 0 ]
          then
            echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
          else
            status=$UNTRIED
            echo "Adding ${TARGET_CT} to download list for today."
            echo ${TARGET_CT} >> $TODAYSFILES
        fi
    fi
done

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Checking whether we have prior missing CT datestamps to process."\
  | tee -a $LOG_FILE

echo "Check for actual prior attempts which failed for external reasons:"\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
if [ -s ${DBTEMPFILE} ]
  then
    echo "Satellite/Dates of prior MISSING:" | tee -a $LOG_FILE
    cat ${DBTEMPFILE} | cut -f1 -d '|' | tee -a $LOG_FILE
    status=$MISSING
  else
    echo "No prior dates with status MISSING." | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Check for prior dates never attempted due to local problems:"\
  | tee -a $LOG_FILE
# Do so by looking for a gap in dates of >1 between last log file's datestamp
# and the current attempt date


nlogs=`ls ${LOG_DIR}/wgetAllCTdaily.* | grep -v $today | wc -l`
echo "nlogs: "${nlogs}
if [ `expr $nlogs \> 0` = 1 ]
  then
    STAMPLAST=`ls ${LOG_DIR}/wgetAllCTdaily.* | grep -v $today | cut -f2 -d '.' | sort | tail -1`
    echo "" | tee -a $LOG_FILE
    echo "Date of last run was on $STAMPLAST" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    DATELAST=`echo $STAMPLAST | sed 's/ //'`
    DATEGAP=`grgdif $today $DATELAST`

    if [ `expr $DATEGAP \> 10` = 1 ]
      then
        echo "Date of last run ($DATELAST) more than 10 days ago, limiting lookback to 10 days."
        DATELAST=`offset_date $today -3`  # immediately gets incremented by 1, below
    fi

    while [ `expr $DATEGAP \> 1` = 1 ]
      do
        # if DATELAST was the last time script was run, it would have downloaded
        # the prior day's CT files, so the subsequent day's missed run would try
        # to get CT files for date DATELAST.  Just use DATELAST as the stamp for
        # the missed CT files and increment afterwards

        # but first check whether intended CT date is the same as current run's
        if [ $DATELAST -ne $ctdate ]
          then
            yymmddNever=`echo $DATELAST | cut -c 3-8`
            echo "No prior attempt of $yymmddNever, set up to download files for this date:"\
              | tee -a $LOG_FILE
            # add this date to the temp file, for each satellite

            #  Get the subdirectory on the ftp site under which our day's data are located,
            #  in the format YYYY/MM/DD
            daydir=`echo $DATELAST | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
            # make the new date-specific directory as required
            mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE
            #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
            juldatelast=`ymd2yd $DATELAST`
            jjjLast=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
            for sat in `cat $SAT_LIST`
              do
                echo "Checking whether we have any files for this old CT date."\
                  | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
                TARGET_CT=${daydir}/CT.${sat}.${DATELAST}.${jjjLast}.txt
                ctfile=`ls ${CT_DATA}/${TARGET_CT}`
                if [ $? = 0 ]
                  then
                    echo "NOTE: Already have file ${ctfile}, not downloading again."\
                	      | tee -a $LOG_FILE
                  else
                    #echo "Adding ${TARGET_CT} to download list for old dates."
                    grep ${TARGET_CT} ${DBTEMPFILE} > /dev/null
                    if  [ $? = 0 ]
                      then
                        echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                      else
                        # check if date is a 5-time loser, ignore if so
                        grep ${TARGET_CT} ${CTFAILURE} > /dev/null
                        if  [ $? = 1 ]
                          then
                            echo "Adding ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            echo ${TARGET_CT}"|0" >> ${DBTEMPFILE}
                            status=$MISSING
                          else
                            echo "${TARGET_CT} is 5-time loser, don't try to download." | tee -a $LOG_FILE
                        fi
                    fi
                  fi
            done
        else
          echo "Intended missing day $DATELAST is same as current day $ctdate."
        fi
        # NOW increment run date and check against current day
        DATELAST=`offset_date $DATELAST 1`
        DATEGAP=`grgdif $today $DATELAST`
        echo "" | tee -a $LOG_FILE
    done
  else
    echo "No prior run log files found, assuming first-time run."  | tee -a $LOG_FILE
fi

echo "Today's new download list:"
if [ -s $TODAYSFILES ]
  then
    cat $TODAYSFILES
fi

if [ -s ${DBTEMPFILE} ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Need to retry downloads for missing CT file dates below:" \
       | tee -a $LOG_FILE
     cat ${DBTEMPFILE} | tee -a $LOG_FILE
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
# exit

# Get the missing old files first, if needed
if [ $have_retries = 't' ]
  then
    echo "Getting old missing CT files." | tee -a $LOG_FILE
    for entry in `cat ${DBTEMPFILE}`
      do
        file=`echo $entry | cut -f1 -d '|'`
        times=`echo $entry | cut -f2 -d '|'`
        daydir=`echo $file | cut -f1-3 -d'/'`
        # increment the number of tries, up to 5.  After that, remove from
        # DBTEMPFILE and write failed download info to CTFAILURE file
        newtimes=`expr $times \+ 1`
        if [ `expr $newtimes \> 5` = 1 ]
          then
            echo ""
            echo "Failed to get ${file} after $times tries." | tee -a $LOG_FILE
            echo "Adding this entry to FAILURES file: ${CTFAILURE}"
            #cp ${DBTEMPFILE} ${TEMPCOPY}
            #cat ${TEMPCOPY} | grep -v ${file} > ${DBTEMPFILE}
            echo ${file} >> ${CTFAILURE}
          else
            echo "Get ${file} from PPS ftp site." | tee -a $LOG_FILE
            wget -P ${CT_DATA}/${daydir}  --user=$USERPASS --password=$USERPASS \
                 $FIXEDPATH/${file}
            ctfile=`ls ${CT_DATA}/${TARGET_CT}`
            if [ $? = 0 ]
              then
	        echo "${CT_DATA}/$file" >> $FILES2DO
                echo "Got prior missing file ${file}" | tee -a $LOG_FILE
                # remove this entry from DBTEMPFILE
                cp ${DBTEMPFILE} ${TEMPCOPY}
                cat ${TEMPCOPY} | grep -v ${file} > ${DBTEMPFILE}
                rm ${TEMPCOPY}
	      else
	        echo "Failed to retrieve ${file} from PPS ftp site!" \
	        	   | tee -a $LOG_FILE
                     # edit the file in place, incrementing # of attempts by 1
                     # note the use of double quotes to allow variable substitution
                     fileAndTimes=`echo ${entry} | cut -f4 -d '/'`
                     basefile=`echo ${fileAndTimes} | cut -f1 -d '|'`
                     sed -i "s/${fileAndTimes}/${basefile}|${newtimes}/" ${DBTEMPFILE}
            fi
	fi
    done
fi

# Next, get the current file if needed.  We will make multiple attempts at it as
# it might just be late, whereas we will only try once each to get other missing
# files.

if [ $status != $SUCCESS ]
  then
     for TARGET_CT in `cat $TODAYSFILES`
       do
         echo ""  | tee -a $LOG_FILE
         echo "Download current file ${TARGET_CT} from PPS"  | tee -a $LOG_FILE
         ctfile=`ls ${CT_DATA}/${TARGET_CT}`

         # If desired file was already downloaded and processed, report as such
         if [ $? = 0 ]
           then
              runagain='n'
              echo "WARNING:  File $ctfile already exists, not downloading again." \
	        | tee -a $LOG_FILE
           else
              runagain='y'
         fi

         # Use wget to download coincidence file from PPS ftp site. 
         # Repeat attempts at intervals of $ZZZ seconds if file is not retrieved in
         # first attempt.  If file is still not found, record the failure to try
         # to get it again in the next days' run(s) of the script.

         declare -i tries=0

         until [ "$runagain" = 'n' ]
           do
              tries=tries+1
              echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
              daydir=`echo $TARGET_CT | cut -f1-3 -d'/'`
              wget -P ${CT_DATA}/${daydir} --user=$USERPASS --password=$USERPASS \
                   $FIXEDPATH/${TARGET_CT}
              ctfile=`ls ${CT_DATA}/${TARGET_CT}`
              if [ $? = 0 ]
                then
                   runagain='n'
                   ls ${CT_DATA}/${TARGET_CT} | tee -a $LOG_FILE
                   echo "${CT_DATA}/${TARGET_CT}" >> $FILES2DO
                   echo "Got it!  Mark success in database:" | tee -a $LOG_FILE
                   echo "" | tee -a $LOG_FILE
#	           echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
#	            app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';"\
#	        	| psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
                else
                   if [ $tries -eq 2 ]
                     then
                        runagain='n'
                        echo "Failed after 2 tries, giving up." | tee -a $LOG_FILE
                        #echo "Adding ${TARGET_CT} to download list for old dates."
                        entry=`grep ${TARGET_CT} ${DBTEMPFILE}`
                        if  [ $? = 0 ]
                          then
                            echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            file=`echo $entry | cut -f1 -d '|'`
                            times=`echo $entry | cut -f2 -d '|'`
                            # edit the file in place, incrementing # of attempts by 1
                            # note the use of double quotes to allow variable substitution
                            newtimes=`expr $times \+ 1`
                            fileAndTimes=`echo ${entry} | cut -f4 -d '/'`
                            basefile=`echo ${fileAndTimes} | cut -f1 -d '|'`
                            sed -i "s/${fileAndTimes}/${basefile}|${newtimes}/" ${DBTEMPFILE}
                          else
                            echo "Adding ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            echo ${TARGET_CT}"|1" >> ${DBTEMPFILE}
                            status=$MISSING
                        fi
#	                echo "UPDATE appstatus SET status = '$MISSING' WHERE\
#		          app_id = 'wgetCTdaily' AND datestamp = '$yymmdd';"\
#		          | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
                     else
                        echo "Failed to get file, sleeping $ZZZ s before next try."\
	                  | tee -a $LOG_FILE
                        sleep $ZZZ
                   fi
              fi
         done    # until [ "$runagain" = 'n' ] loop
     done        # for TARGET_CT in `cat $TODAYSFILES`
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

#  Check for presence of downloaded files, process if any

if [ -s $FILES2DO ]
  then
     if [ ! -x ${BIN_DIR}/get_Q2_time_matches_from_CTs.sh ]
       then
          echo "Executable file '${BIN_DIR}/get_Q2_time_matches_from_CTs.sh' not found!" \
            | tee -a $LOG_FILE
          exit 1
     fi
     
     echo "Calling get_Q2_time_matches_from_CTs.sh to process file(s):" | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     for iofile in `cat $FILES2DO`
       do
          echo "Process this CT file for NMQ time matching:" \
	    | tee -a $LOG_FILE
          ls -al $iofile | tee -a $LOG_FILE
	  echo "" | tee -a $LOG_FILE
          ${BIN_DIR}/get_Q2_time_matches_from_CTs.sh -v $iofile | tee -a $LOG_FILE
     done
  else
    echo "File $FILES2DO not found, no new CT files or downloads failed." \
      | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
