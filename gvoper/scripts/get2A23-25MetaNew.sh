#!/bin/sh
################################################################################
#
# get2A23-25MetaNew.sh    Morris/SAIC/GPM GV    March 2014
#
# DESCRIPTION
# Child script called from get_PPS_CS_data.sh.  Runs the two metadata extraction
# scripts, get2A23Meta.sh and get2A25Meta.sh, which call IDL routines to do the
# metadata generation, and then load their respective IDL outputs to the 'gpmgv'
# database.  Passes along a single argument, a 'yymmdd' date string, to the two
# scripts.  (Note that success in processing metadata for a set of PR files
# is dependent on having the CT data for all the dates indicated by the files,
# since the metadata are tagged to the overpass event IDs defined by the CT
# file entries for our sites of interest -- see HISTORY, 1/26/07 for how this
# is handled in the latest incarnation.)
#
# HISTORY
# 1/26/07 - Morris - Added tests to see if CT data is missing, on a date-by-
# date basis.  Note, we can be missing an earlier CT file download which
# overlaps the data dates for which we got PR files in today's attempt --
# even if we got the most recent CT file.  This can happen when we get more than
# one day's worth of PR subset files due to a failed/missing earlier attempt,
# but the CT downloads have not caught up or are still not available.
# Before this change, we would not indicate a failure as long as at least one
# of the orbits we were processing had coincidence event data, regardless of
# how many other days/orbits were missing CT events.  This resulted in partial
# metadata, with no attempt to recover the missing part.  Now we flag a date's
# attempt as MISSING unless the CT data are present for *ALL* PR file dates.
#
# IS IT POSSIBLE THAT WE COULD GET PR ORBIT SUBSET FILES FOR WHICH THERE ARE NO
# CT ENTRIES, EVEN WHEN THE CT FILES ARE ALL UP-TO-DATE?  ANSWER IS YES, so need
# to assure that downloaded/db-loaded CT dates cover our set of PR file dates.
# Cannot compare PR file orbit numbers one-by-one to CT orbit numbers, as we
# have a zero-to-many relationship between PR files and site overpasses.)
#
# 2/12/08 - Morris - Modified the query which produces the control file info to
# take the 'subset' of the 2A23 file into account, so that we don't get a
# radar_id counted/included in the output which is not associated with the PR
# product subset.  This issue came up when the DARW radar was added to the list
# of stations processed in the CT files and caused incomplete metadata runs.
#
# 11/8/13 - Morris - Using >> rather than "| tee -a" to capture any psql
# error output in main query.
#
# 27/3/14 - Morris - Created from get2A23-25Meta.sh, and modified to look at
# get_PPS_CS_data.sh log file rather than mirror log file to find list of new
# 2A23 and 2A25 files to process.  Also, looks at process IDs 'wgetCTdaily' and
# 'wgetCTTRMM' to determine the status of CT file downloads.  Now includes full
# pathnames to the 2A23 and 2A25 files in the control file, not just basenames.
#
# 4/24/14  - Morris - Increased ntries from 5 to 10 before declaring FAILURE.
# 8/26/14  - Morris - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
#                   - Commented out unused DATA_DIR
# 9/9/14   - Morris - Changed "grep -v INSERT" to "grep -Ev '(INSERT|Making)'"
#                     to keep from picking up directory creation lines.
#
################################################################################

GV_BASE_DIR=/home/gvoper
BIN_DIR=${GV_BASE_DIR}/scripts
#DATA_DIR=/data/gpmgv
#CT_DATA=${DATA_DIR}/coincidence_table
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/dbtempfileMeta2A23-25
# file listing all yymmdd to be processed this run
FILES2DO=${TMP_DIR}/Metas2A23-25ToGet
rm -f $FILES2DO

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired CT file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts

have_retries='f'  # indicates whether we have missing prior dates to retry
status=$UNTRIED   # assume we haven't yet tried to do current file date

umask 0002

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/get2A23-25Meta.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
LOG_FILE=${META_LOG_DIR}/get2A23-25MetaNew.${THISRUN}.log

echo "Processing 2A23 and 2A25 metadata for rundate ${THISRUN}" \
 | tee -a $LOG_FILE
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++"\
 | tee -a $LOG_FILE

# Figure out which mirror runs' YYMMDDs we need to process, current and past.
if [ -s ${DBTEMPFILE} ]
  then
    rm ${DBTEMPFILE}
fi

echo "" | tee -a $LOG_FILE
echo "Checking whether we have prior missing datestamps to process."\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
      WHERE app_id = 'get2A2325Meta' AND status = '$MISSING' \
      AND datestamp != '$THISRUN';" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
if [ -s ${DBTEMPFILE} ]
  then
     # add these yymmdds to the list of those to process this run
     cat ${DBTEMPFILE} | cut -f3 -d '|' > $FILES2DO
     echo "" | tee -a $LOG_FILE
     echo "Need to retry metadata processing for missing file dates below:" \
       | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
  else
     echo "" | tee -a $LOG_FILE
     echo "No missing prior processing dates found." | tee -a $LOG_FILE
fi

echo "Checking whether we have an entry for current run date in database." \
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'get2A2325Meta' AND datestamp = '$THISRUN';" | psql -a -d gpmgv \
 | tee -a $LOG_FILE 2>&1

if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to process this mirror date before, check our past status.
     status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
     echo "" | tee -a $LOG_FILE
     echo "Have status=${status} from prior attempt." | tee -a $LOG_FILE
     if [ $status = $UNTRIED  -o  $status = $MISSING ]
       then
	  echo "Need to retry metadata for current date $THISRUN."\
	   | tee -a $LOG_FILE
	  echo $THISRUN >> $FILES2DO
     fi
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "No prior attempt, initialize status in database:" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
      ('get2A2325Meta','$THISRUN','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
     # add this yymmdd to the list of those to process this run
     echo $THISRUN >> $FILES2DO
fi

if [ ! -s $FILES2DO ]
  then
    echo "All metadata processing seems up-to-date, exiting."\
   | tee -a $LOG_FILE
  exit 0
fi

# increment the ntries column in the appstatus table for $MISSING and $UNTRIED
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'get2A2325Meta' \
 AND status IN ('$MISSING','$UNTRIED');" | psql -a -d gpmgv \
  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

for yymmdd in `cat $FILES2DO`
  do
# - Prepare the control file for IDL to do new 2A23 file metadata extraction.
# - NOW we added the matching 2A25 filename to the 'orbit' lines of the groups,
#   and the overpass 'event_num' to the overpass event lines of the groups.

# - Added logic to check prior day(s)' getCTdaily.sh run status, to avoid
#   the situation of missing matching overpass_events for files we
#   just downloaded today when yesterday's getCTdaily run times-out or fails!

# Files to hold the delimited output from the database queries comprising the
# control files for the 2A23 RainType metadata extraction in the IDL routines:
# - 'outfile' gets overwritten each time psql is called in the loop over the
#   new 2A23 files, so its output is copied in append manner to 'outfileall',
#   which is run-date-specific:
    outfile=${TMP_DIR}/file2a23sites_temp.txt
    outfileall=${TMP_DIR}/file2a23sites.${yymmdd}.txt
    rm -f $outfileall
    MIR_LOG_FILE=${LOG_DIR}/get_PPS_CS_data.${yymmdd}.log
    CTMISSING='f'
# file to hold the 2A23 pathnames extracted from the get_PPS_CS_data log file
    filepaths2A23=${TMP_DIR}/filepaths2A23_temp.txt
    rm -fv $filepaths2A23 | tee -a $LOG_FILE 2>&1

    echo "Find the pathnames of the 2A23 files listed as downloaded in $MIR_LOG_FILE" | tee -a $LOG_FILE
    grep 2A23 $MIR_LOG_FILE | grep orbit_subset | grep -Ev '(INSERT|Making)' | grep -v KOREA | cut -f2 -d '>' \
      | sed 's/ `//' | sed "s/'//" | tee $filepaths2A23 | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

#   CHECK THE DATES OF THE DATA FILES WE ARE PROCESSING THIS TIME TO SEE
#   WHETHER WE ARE MISSING A MATCHING CT DAILY DATA FILE.  WE COULD
#   HAVE GOTTEN MORE THAN ONE DAY'S PR FILES IN A MIRROR ATTEMPT, WHICH
#   WOULD SPAN MORE THAN ONE CT FILE.  NEED TO FLAG A RUN AS 'MISSING'
#   IN THIS CASE, EVEN IF PARTIAL 'OUTFILEALL' IS CREATED AND ITS
#   NONZERO-FILE-EXISTS TEST BELOW WOULD NORMALLY SUCCEED!

    for mirlogdate in `cat $filepaths2A23 | cut -f5 -d'.' | cut -c 3-8 | sort -u`
      do
        echo "Found file datestamp $mirlogdate" | tee -a $LOG_FILE
        dateStringLen=`echo $mirlogdate | awk '{print length}'`
        if [ $dateStringLen -eq 6 ]
          then
            mirdate=$mirlogdate   # have yymmdd format datestamp, use as-is
          else
            if [ $dateStringLen -eq 8 ]
              then
                mirdate=`echo $mirlogdate | cut -c3-8`  # trim yyyymmdd datestamp
              else
                echo "Have 2A23 datestamp of illegal length ${dateStringLen}: $mirlogdate"\
                  | tee -a $LOG_FILE
                echo "Exiting with errors."
                CTMISSING='t'
            fi
        fi
        echo "Checking database for CT data for $mirdate."\
         | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE

        echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
        WHERE app_id IN ('wgetCTdaily','wgetCTTRMM') AND datestamp = '$mirdate' \
        order by status desc limit 1;" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1

        if [ -s ${DBTEMPFILE} ]
          then
             # We've tried to get this CT file before, check our past status.
             status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
             echo "Have CT status=${status} in database." | tee -a $LOG_FILE
             if [ ${status} != ${SUCCESS} ]
               then
                 echo "" | tee -a $LOG_FILE
                 echo "FATAL:  Status indicates CT data missing for $mirdate!"\
                  | tee -a $LOG_FILE
                 CTMISSING='t'
             fi
             echo "" | tee -a $LOG_FILE
          else
             echo "" | tee -a $LOG_FILE
             echo "FATAL:  No CT data entry for $mirdate!" | tee -a $LOG_FILE
             echo "Coincidence events assumed to be missing in database." \
               | tee -a $LOG_FILE
	     CTMISSING='t'
        fi
#        ctunlfile=${CT_DATA}/CT.${mirdate}.unl
#        echo "Need matching CT data from file $ctunlfile" | tee -a $LOG_FILE
#	if [ ! -s $ctunlfile ]
#	  then
#           echo "FATAL: CT data file $ctunlfile not found!" | tee -a $LOG_FILE
#           echo "Coincidence events assumed to be missing in database." \
#               | tee -a $LOG_FILE
#           CTMISSING='t'
#         else
#           echo "Valid CT data file found." | tee -a $LOG_FILE
#	fi
        echo "" | tee -a $LOG_FILE
    done

    if [ $CTMISSING != "t" ]
    then
   #
    echo "" | tee -a $LOG_FILE
    echo "Generating orbit/file/site overpass control file ${outfileall}"\
     | tee -a $LOG_FILE
   #
    for thisPPSfilepath in `cat $filepaths2A23`
      do
        file2a23=${thisPPSfilepath##*/}
        file2a23dir=${thisPPSfilepath%/*}
        file2a25dir=`echo $file2a23dir | sed 's/2A23/2A25/'`
        echo ""  | tee -a $LOG_FILE
        echo "\t \a \f '|' \o $outfile \
         \\\ SELECT '${thisPPSfilepath}', '${file2a25dir}/'||c.filename, b.orbit, count(*) \
          FROM overpass_event a, orbit_subset_product b, \
               orbit_subset_product c, siteproductsubset d \
         WHERE a.orbit = b.orbit AND b.filename = '${file2a23}' \
           AND a.orbit = c.orbit AND c.product_type = '2A25' \
           AND b.subset = c.subset AND b.subset = d.subset \
           AND a.radar_id = d.radar_id AND b.version=c.version and d.sat_id='PR' \
      GROUP BY b.filename, c.filename, b.orbit; \
        SELECT a.event_num, a.radar_id, b.latitude, b.longitude \
          FROM overpass_event a, fixed_instrument_location b, \
               orbit_subset_product c, siteproductsubset d \
         WHERE a.radar_id = b.instrument_id and a.radar_id = d.radar_id \
           AND a.orbit = c.orbit and c.subset = d.subset and d.sat_id='PR' \
           AND c.filename='${file2a23}';" \
             | psql gpmgv  >> $LOG_FILE 2>&1
       #
        thisorbit=`echo ${file2a23} | cut -f3 -d '.'`
        echo "Output file additions for orbit ${thisorbit}:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
	# copy the temp file output from psql to the daily control file
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done
   #
    fi

    if [ -s $outfileall -a $CTMISSING != "t" ]
      then
        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling get2A23Meta.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/get2A23Meta.sh $yymmdd

        echo "" | tee -a $LOG_FILE
        start2=`date -u`
        echo "Calling get2A25Meta.sh $yymmdd on $start2" | tee -a $LOG_FILE
        ${BIN_DIR}/get2A25Meta.sh $yymmdd

        echo "" | tee -a $LOG_FILE
        end=`date -u`
        echo "Metadata scripts for $yymmdd completed on $end,"\
	 | tee -a $LOG_FILE
        echo "set status to SUCCESS in database:" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
         app_id = 'get2A2325Meta' AND datestamp = '$yymmdd';"\
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        
	echo "See log files ${LOG_DIR}/get2A23Meta.${yymmdd}.log," \
         | tee -a $LOG_FILE
        echo "and ${LOG_DIR}/get2A23Meta.${yymmdd}.log" | tee -a $LOG_FILE
      
      else
        echo "" | tee -a $LOG_FILE
        echo "Mark $yymmdd as incomplete -- no coincidence data for orbit(s)," \
	  | tee -a $LOG_FILE
        echo "or no PR subset data files listed in ${MIR_LOG_FILE}, so" \
	  | tee -a $LOG_FILE
        echo "set status to MISSING in database:" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$MISSING' WHERE \
         app_id = 'get2A2325Meta' AND datestamp = '$yymmdd';"\
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi

done  # yymmdd loop

echo "" | tee -a $LOG_FILE

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 10 times.  Don't want to continue trying to process metadata for dates
# where it's been too many days that a needed CT file has been missing.

echo "Set status to FAILED where this is the 10th failure for any filedates:"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'get2A2325Meta'\
 AND status='$MISSING' AND ntries > 9;" | psql -a -d gpmgv \
  | tee -a $LOG_FILE 2>&1

exit
