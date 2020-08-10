#!/bin/sh
################################################################################
#
# get2ADPRMeta.sh    Morris/SAIC/GPM GV    March 2014
#
# DESCRIPTION
# Child script called from get_PPS_CS_data.sh.  Runs the metadata extraction
# script, get2ADPRMeta4date.sh, which calls an IDL routine to do the metadata
# generation and then loads the IDL output to the 'gpmgv' database.
# Takes a single argument, a 'yymmdd' date string, uses it to determine the
# log file name from get_PPS_CS_data.sh which is searched to find the 2AKu or
# 2ADPR files downloaded for that date that will be processed to extract rain
# event metadata, and queries the gpmgv database to prepare a control file
# listing the file and information on the sites overpassed for the orbit and
# spatial subset for each file. Passes the yymmdd argument along to the child
# script so that the datestamped control file prepared by this script can be
# identified.  (Note that success in processing metadata for a set of DPR files
# is dependent on having the CT data for all the dates indicated by the files,
# since the metadata are tagged to the overpass event IDs defined by the CT
# file entries for our sites of interest.)
#
# HISTORY
# 4/2/14   - Morris - Created from get2A23-25MetaNew.sh.
# 8/26/14  - Morris - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
# 9/9/14   - Morris - Changed "grep -v INSERT" to "grep -Ev '(INSERT|Making)'"
#                     to keep from picking up directory creation lines.
# 3/6/15   - Morris - Added Already|gvoper filters to "grep -Ev" command to
#                     filter additional duplicate instances of file names.
# 2/1/16   - Morris - Removed the ".new" segment from the LOG_FILE name to make
#                     it compatible with notify_vn_status.sh.
# 3/11/16 - PUT TEMPORARY FILTER ON ONLY 2A FILENAMES CONTAINING "201603" FOR
#           VO4A REPROCESSED DATA INGEST PERIOD.  LINE 223 (225 W. THIS COMMENT)
# 5/30/16 - REMOVED ABOVE FILTER, WAY TOO LATE AFTER REPROCESSING!
# 2/13/17 - Excluding pattern 'replaced_PPS_files' from grep on the contents of
#           the get_PPS_CS_data log file so that it doesn't get identified as
#           the pathname of a new 2AKu file following modification of the
#           get_PPS_CS_data.sh script to accept reprocessed data files.
# 8/10/20 - Berendes - fixed parsing of wget output to change "`" in grep 
#		    to "'", upgrade of OS from Centos 6 to 8 broke this.  This is a
#           fragile setup, depending on wget to not change screen output on download
#           TODO:  make more robust parsing of filenames to run metadata extraction on
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

BIN_DIR=${GV_BASE_DIR}/scripts
DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_table
TMP_DIR=/data/tmp
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/dbtempfileMeta2ADPR
# file listing all yymmdd to be processed this run
FILES2DO=${TMP_DIR}/Metas2ADPRToGet
rm -f $FILES2DO

INSTRUMENT=Ku   # 2A data type to process for metadata.  Other option is 'DPR'

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
     LOG_FILE=${META_LOG_DIR}/get2ADPRMeta.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISRUN=$1
LOG_FILE=${META_LOG_DIR}/get2ADPRMeta.${THISRUN}.log

echo "Processing 2A-DPR metadata for rundate ${THISRUN}" \
 | tee $LOG_FILE
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
      WHERE app_id = 'get2ADPRMeta' AND status in ('$MISSING', '$UNTRIED') \
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

echo "" | tee -a $LOG_FILE
echo "Check for prior dates never attempted due to local problems:"\
  | tee -a $LOG_FILE
# Do so by looking for a gap in dates of >1 between last attempt registered
# in the database, and the current attempt date

STAMPLAST=`psql -q -t -d gpmgv -c "SELECT COALESCE(MAX(datestamp),'$THISRUN') \
 FROM appstatus WHERE app_id = 'get2ADPRMeta' AND datestamp != '$THISRUN';"`
echo "" | tee -a $LOG_FILE
echo "Last date previously attempted was $STAMPLAST" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
DATELAST=`echo 20$STAMPLAST | sed 's/ //'`
DATEGAP=`grgdif 20$THISRUN $DATELAST`

while [ `expr $DATEGAP \> 1` = 1 ]
  do
    DATELAST=`offset_date $DATELAST 1`
    yymmddNever=`echo $DATELAST | cut -c 3-8`
    echo "No prior attempt of $yymmddNever, initialize status in database:"\
      | tee -a $LOG_FILE
    echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
      ('get2ADPRMeta','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
    # add this date to the temp file
    echo $yymmddNever >> ${FILES2DO}
    DATEGAP=`grgdif 20$THISRUN $DATELAST`
    echo "" | tee -a $LOG_FILE
done

echo "Checking whether we have an entry for current run date in database." \
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'get2ADPRMeta' AND datestamp = '$THISRUN';" | psql -a -d gpmgv \
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
      ('get2ADPRMeta','$THISRUN','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
     # add this yymmdd to the list of those to process this run
     echo $THISRUN >> $FILES2DO
fi

echo "FILES2DO:"
cat $FILES2DO
#exit

if [ ! -s $FILES2DO ]
  then
    echo "All metadata processing seems up-to-date, exiting."\
   | tee -a $LOG_FILE
  exit 0
fi

# increment the ntries column in the appstatus table for $MISSING and $UNTRIED
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'get2ADPRMeta' \
 AND status IN ('$MISSING','$UNTRIED');" | psql -a -d gpmgv \
  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

for yymmdd in `cat $FILES2DO`
  do
    # - Prepare the control file for IDL to do new 2ADPR file metadata extraction.
    # - NOW we added the overpass 'event_num' to the overpass event lines of the groups.

    # - Added logic to check prior day(s)' getCTdailies.sh run status, to avoid
    #   the situation of missing matching overpass_events for files we
    #   just downloaded today when yesterday's getCTdailies run times-out or fails!

    # Files to hold the delimited output from the database queries comprising the
    # control files for the 2ADPR metadata extraction in the IDL routines:
    # - 'outfile' gets overwritten each time psql is called in the loop over the
    #   new 2ADPR files, so its output is copied in append manner to 'outfileall',
    #   which is run-date-specific:
    outfile=${TMP_DIR}/file2aDPRsites_temp.txt
    outfileall=${TMP_DIR}/file2aDPRsites.${yymmdd}.txt
    rm -f $outfileall
    MIR_LOG_FILE=${LOG_DIR}/get_PPS_CS_data.${yymmdd}.log
    CTMISSING='f'
    # file to hold the 2ADPR pathnames extracted from the get_PPS_CS_data log file
    filepaths2ADPR=${TMP_DIR}/filepaths2ADPR_temp.txt

    # find the pathnames of the 2ADPR or 2AKu files listed as downloaded in this log file

    echo "" | tee -a $LOG_FILE
    echo "==================================================" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "Looking for downloaded 2A${INSTRUMENT} files in $MIR_LOG_FILE" \
      | tee -a $LOG_FILE

# Simplified this on 11/17/15, & don't know why DARW was still excluded
#    grep 2A $MIR_LOG_FILE | grep $INSTRUMENT | grep orbit_subset \
#      | grep -Ev '(INSERT|Making|DARW|Already|gvoper)' \
#      | cut -f2 -d '>' | sed 's/ `//' | sed "s/'//" | tee $filepaths2ADPR

# TAB 8/10/20 wget screen output changed "`" to "'" during file download
#    grep 2A${INSTRUMENT} $MIR_LOG_FILE | grep -v replaced_PPS_files | grep "\->" \
#      | cut -f2 -d '>' | sed 's/ `//' | sed "s/'//" | tee $filepaths2ADPR
      
    grep 2A${INSTRUMENT} $MIR_LOG_FILE | grep -v replaced_PPS_files | grep "\->" \
      | cut -f2 -d '>' | sed "s/ '//" | sed "s/'//" | tee $filepaths2ADPR

    if [ -s $filepaths2ADPR ]
      then
        nku=`cat $filepaths2ADPR | wc -l`
      else
        nku=0
    fi
    echo "$nku 2A${INSTRUMENT} files found."  | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    #   CHECK THE DATES OF THE DATA FILES WE ARE PROCESSING THIS TIME TO SEE
    #   WHETHER WE ARE MISSING A MATCHING CT DAILY DATA FILE.  WE COULD
    #   HAVE GOTTEN MORE THAN ONE DAY'S DPR FILES IN A GIVEN DAY'S PPS FILES
    #   DOWNLOAD, WHICH WOULD SPAN MORE THAN ONE CT FILE.  NEED TO FLAG A RUN AS
    #   'MISSING' IN THIS CASE, SINCE WE DON'T CURRENTLY HAVE A MECHANISM TO
    #   TRACK METADATA CREATION ON A PER-FILE BASIS

    for mirlogdate in `cat $filepaths2ADPR | cut -f5 -d'.' | cut -c 3-8 | sort -u`
      do
        dateStringLen=`echo $mirlogdate | awk '{print length}'`
        if [ $dateStringLen -eq 6 ]
          then
            mirdate=$mirlogdate   # have yymmdd format datestamp, use as-is
          else
            if [ $dateStringLen -eq 8 ]
              then
                mirdate=`echo $mirlogdate | cut -c3-8`  # trim yyyymmdd datestamp
              else
                echo "Have 2ADPR datestamp of illegal length ${dateStringLen}: $mirlogdate"\
                  | tee -a $LOG_FILE
                echo "Exiting with errors."
                CTMISSING='t'
            fi
        fi
        echo "Downloaded data file(s) for date $mirdate, check database for matching CT data."\
         | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE

        echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
        WHERE app_id = 'wgetCTGPM' AND datestamp = '$mirdate' \
        order by status desc limit 1;" | psql -a -d gpmgv # | tee -a $LOG_FILE 2>&1

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
          else
             echo "" | tee -a $LOG_FILE
             echo "FATAL:  No CT data entry for $mirdate!" | tee -a $LOG_FILE
             echo "Coincidence events assumed to be missing in database." \
               | tee -a $LOG_FILE
	     CTMISSING='t'
        fi
        echo "" | tee -a $LOG_FILE
    done

    if [ $CTMISSING != "t" ]
    then
       echo "" | tee -a $LOG_FILE
       echo "Generating orbit/file/site overpass control file ${outfileall}"\
        | tee -a $LOG_FILE
       echo ""  | tee -a $LOG_FILE

       for thisPPSfilepath in `cat $filepaths2ADPR`
         do
           file2aDPR=${thisPPSfilepath##*/}
           file2aDPRdir=${thisPPSfilepath%/*}
           echo "File: $file2aDPR" | tee -a $LOG_FILE
           echo "\t \a \f '|' \o $outfile \
            \\\ SELECT '${thisPPSfilepath}', b.orbit, count(*) \
             FROM overpass_event a, orbit_subset_product b, \
                  siteproductsubset d \
            WHERE b.filename = '${file2aDPR}' \
              AND b.subset = d.subset AND a.sat_id = d.sat_id AND a.sat_id=b.sat_id \
              AND a.radar_id = d.radar_id AND a.orbit = b.orbit \
         GROUP BY b.filename, b.orbit; \
           SELECT a.event_num, a.radar_id, b.latitude, b.longitude \
             FROM overpass_event a, fixed_instrument_location b, \
               orbit_subset_product c, siteproductsubset d \
            WHERE a.radar_id = b.instrument_id and a.radar_id = d.radar_id \
              AND a.sat_id = d.sat_id AND a.sat_id=c.sat_id \
              AND a.orbit = c.orbit and c.subset = d.subset \
              AND c.filename='${file2aDPR}';" \
                | psql gpmgv  #>> $LOG_FILE 2>&1

           thisorbitpadded=`echo ${file2aDPR} | cut -f6 -d '.'`
           thisorbit=`expr $thisorbitpadded + 0`  # convert to numeric to remove zero padding
           thissubset=`echo ${file2aDPRdir} | cut -f9 -d'/'`
           echo ""  | tee -a $LOG_FILE
           if [ -s $outfile ]
             then
               echo "Control file additions for subset ${thissubset}, orbit ${thisorbit}:"\
                   | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
	           # copy the temp file output from psql to the daily control file
               cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
             else
               echo "No control file additions for subset ${thissubset}, orbit ${thisorbit}"\
                 | tee -a $LOG_FILE
               echo ""  | tee -a $LOG_FILE
           fi
       done
      #
    fi

    if [ -s $outfileall -a $CTMISSING != "t" ]
      then
        echo "" | tee -a $LOG_FILE
        start1=`date -u`

        echo " >>> Calling get2ADPRMeta4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/get2ADPRMeta4date.sh $yymmdd

        # CHECK THE STATUS OF THE ABOVE SCRIPT BEFORE BLINDLY DECLARING SUCCESS
	     if [ $? = 1 ]
	       then
	         echo "UPDATE appstatus SET status = '$MISSING' \
	           WHERE app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';" \
	           | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	         echo "See log file ${META_LOG_DIR}/get2ADPRMeta4date.${THISRUN}.log" \
              | tee -a $LOG_FILE
            exit 1
          else
            echo "" | tee -a $LOG_FILE
            end=`date -u`
            echo "Metadata script for $yymmdd completed on $end," | tee -a $LOG_FILE
            echo "set status to SUCCESS in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
            echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
             app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';"\
              | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	     fi
      else
        echo "" | tee -a $LOG_FILE
        echo "Mark $yymmdd as incomplete -- missing coincidence data for orbit(s)," \
	          | tee -a $LOG_FILE
        echo "  or no 2A${INSTRUMENT} subset data files listed in ${MIR_LOG_FILE}," \
	          | tee -a $LOG_FILE
        echo "  so set status to MISSING in database:" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$MISSING' WHERE \
         app_id = 'get2ADPRMeta' AND datestamp = '$yymmdd';"\
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi

done  # yymmdd loop

echo "" | tee -a $LOG_FILE

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 5 times.  Don't want to continue trying to process metadata for dates
# where it's been too many days that a needed CT file has been missing.

echo "Set status to FAILED where this is the 5th failure for any filedates:"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'get2ADPRMeta'\
 AND status='$MISSING' AND ntries > 4;" | psql -a -d gpmgv \
  | tee -a $LOG_FILE 2>&1

exit
