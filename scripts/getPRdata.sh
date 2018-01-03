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
#       pps.gsfc.nasa.gov - Package file, holds configuration for mirror script
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
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

# Following two variables must be the same as specified in the "package" file!
MIR_DATA_DIR=${DATA_DIR}/prsubsets
MIR_LOG_FILE=${MIR_DATA_DIR}/gpmprsubsets.log

MIR_BIN=mirror
MIR_BIN_DIR=${BIN_DIR}/mirror
# The following are specified relative to MIR_BIN_DIR, as mirror expects:
MIR_PACKAGES_DIR=packages
MIR_PACKAGE_TEMPLATE=${MIR_PACKAGES_DIR}/pps_gsfc_nasa_gov.template
MIR_PACKAGE=${MIR_PACKAGES_DIR}/pps.gsfc.nasa.gov

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
satid="PR"
# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired data files, if any
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
INCOMPLETE='I' # could not complete all steps, could be external problem

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getPRdata_dbtempfile

# ZZZ is number of seconds to sleep between repeat mirror attempts if problems/errors
ZZZ=300
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getPRdata.${rundate}.log
export rundate

umask 0002

echo "Starting mirroring run for PR subsets for $rundate." | tee -a $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from getPRdata.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ws1-gpmgv' pankaj.jaiswal@nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
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
 WHERE app_id = 'getPRdata' AND datestamp = '${rundate}';" \
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
         echo "PRIOR RUN SUCCESSFUL.  SCRIPT getPRdata.sh COMPLETE, EXITING." \
	  | tee -a $LOG_FILE
         echo "See log file $LOG_FILE for information."
         exit 0
     fi
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus (app_id, datestamp, status) VALUES \
       ('getPRdata', '${rundate}', '$UNTRIED');" | psql -a -d gpmgv \
       | tee -a $LOG_FILE 2>&1
fi

# increment the ntries column in the appstatus table for $rundate
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'getPRdata' AND \
 datestamp = '$rundate';" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

# mirror (apparently) must be run from its home directory
cd ${MIR_BIN_DIR}

if [ ! -x ${MIR_BIN} ]
  then
     echo "Executable file '${MIR_BIN}' not found in `pwd`, exiting." \
       | tee -a $LOG_FILE
     echo "UPDATE appstatus SET status = '$FAILED' \
           WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
      | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
     exit 1
fi


# prepare the filename patterns for files mirror is to consider - as either one
# or two YYMM dates, from the current year/month to the year/month 28 days ago

today=`date -u +%Y%m%d`
startdate=`offset_date $today -28`
yyyymmend=`echo $today | cut -c1-6`
yyyymmstart=`echo $startdate | cut -c1-6`
if [ `expr $yyyymmend \> $yyyymmstart` = 1 ]
  then
#    need to consider this month and last month in file patterns
     yymmstart=`echo $yyyymmstart | cut -c3-6`
     yymmend=`echo $yyyymmend | cut -c3-6`
     fp1c21=`echo "(^1C21.${yymmstart}.*|^1C21.${yymmend}.*)"`
     fp2a23=`echo "(^2A23.${yymmstart}.*|^2A23.${yymmend}.*)"`
     fp2a25=`echo "(^2A25.${yymmstart}.*|^2A25.${yymmend}.*)"`
     fp2b31=`echo "(^2B31.${yymmstart}.*|^2B31.${yymmend}.*)"`
  else
#    otherwise file pattern is just for this month
     yymmstart=`echo $yyyymmstart | cut -c3-6`
     fp1c21=`echo "(^1C21.${yymmstart}.*)"`
     fp2a23=`echo "(^2A23.${yymmstart}.*)"`
     fp2a25=`echo "(^2A25.${yymmstart}.*)"`
     fp2b31=`echo "(^2B31.${yymmstart}.*)"`
fi

echo "" | tee -a $LOG_FILE
echo "Pattern regexp (1C21 example) = $fp1c21" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# substitute the computed file patterns for the placeholders in the template
# package file, and write to the operational package file

cat $MIR_PACKAGE_TEMPLATE | sed "s/__1C21__/${fp1c21}/g" \
                          | sed "s/__2A23__/${fp2a23}/g" \
                          | sed "s/__2A25__/${fp2a25}/g" \
                          | sed "s/__2B31__/${fp2b31}/g" | tee $MIR_PACKAGE

# run the mirror package!

#MIRCMD=./${MIR_BIN}' '${MIR_PACKAGE}
MIRCMD=./${MIR_BIN}' -n '${MIR_PACKAGE}  # TEST ONLY, NO DOWNLOADS
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
               WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
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

################### ADDED THIS BLOCK FOR TESTING WITH -n OPTION ###############
if [ -s $MIR_LOG_FILE ]
  then
     cat $MIR_LOG_FILE
fi
exit
###############################################################################

# could be more efficient than calling psql in a loop to insert 1 row at a time!
if [ -s $MIR_LOG_FILE ]
  then
    echo "" | tee -a $LOG_FILE
    # see if any data files were actually downloaded, exit now if none
    grep -E '(1C21|2A23|2A25|2B31)' ${MIR_LOG_FILE} > /dev/null
    if [ $? != 0 ]
      then
        echo "No PR subset files downloaded; skip metadata steps and exit."\
	 | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        if [ "$timedout" = 'y' ]
	  then
            echo "Timed out after $tries failed tries." | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$FAILED' \
             WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	  else
            echo "UPDATE appstatus SET status = '$MISSING' \
             WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
             | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	fi
        echo "" | tee -a $LOG_FILE
	echo "See log file $LOG_FILE for script output."
        mv $MIR_LOG_FILE ${LOG_DIR}/mirror.${rundate}.log
        exit
    fi

    # catalog the files in the database - need separate logic for the GPM_KMA
    # subset files, as they have a different naming convention
    for type in 1C21 2A23 2A25 2B31
      do
        for file in `grep $type $MIR_LOG_FILE | grep Got | cut -f2 -d ' '`
          do
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
            echo $file | grep "GPM_KMA" > /dev/null
            if  [ $? = 0 ]
              then
                subset='GPM_KMA'
                version=`echo $file | cut -f4 -d '.'`
              else
	        temp1=`echo $file | cut -f4 -d '.'`
	        temp2=`echo $file | cut -f5 -d '.'`
	        # The product version number precedes (follows) the subset ID
	        # in the GPMGV (baseline CSI) product filenames.  Find which of
	        # temp1 and temp2 is the version number.
	        expr $temp1 + 1
	        if [ $? = 0 ]   # is $temp1 a number?
	          then
	            version=$temp1
		    subset=$temp2
	          else
	            expr $temp2 + 1
		    if [ $? = 0 ]   # is $temp2 a number?
		      then
		        subset=$temp1
		        version=$temp2
		      else
		        echo "Cannot find version number in PR filename: $file"\
		          | tee -a $LOG_FILE
		        exit 2
	    	    fi
	        fi
            fi
	    echo "subset ID = $subset" | tee -a $LOG_FILE
            #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo "INSERT INTO orbit_subset_product VALUES ('${satid}',\
	    ${orbit},'${type}','${dateString}','${file}','${subset}');" \
	    | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
        done
    done

    echo ""  | tee -a $LOG_FILE
    echo "Renaming mirror log file to unique/datestamped:"  | tee -a $LOG_FILE
    mv -v $MIR_LOG_FILE ${LOG_DIR}/mirror.${rundate}.log | tee -a $LOG_FILE 2>&1
    
    # Call wgetKWAJ_PR_CSI.sh to get the KWAJ subsets from the DAAC,and check
    # for any output.  Append output to mirror log file, if any.
    ${BIN_DIR}/wgetKWAJ_PR_CSI.sh
    if [ -s ${LOG_DIR}/KWAJ_PR_CSI_newfiles.${rundate}.log ]
      then
        echo "" | tee -a $LOG_FILE
        echo "Adding KWAJ PR CSI files to mirror log file for metadata processing:" | tee -a $LOG_FILE
	cat ${LOG_DIR}/KWAJ_PR_CSI_newfiles.${rundate}.log | tee -a ${LOG_DIR}/mirror.${rundate}.log
    fi
    
    # Call the IDL wrapper script, get2A23-25Meta.sh, to run the IDL .bat files
    # to extract the file metadata.
    # It's slow, so run it in the background so that this script can complete.
    if [ -x ${BIN_DIR}/get2A23-25Meta.sh ]
      then
        echo "" | tee -a $LOG_FILE
        echo "Calling get2A23-25Meta.sh to extract PR file metadata." \
          | tee -a $LOG_FILE
    
        ${BIN_DIR}/get2A23-25Meta.sh $rundate &
    
        echo "See log file ${LOG_DIR}/get2A23-25Meta.${rundate}.log" \
         | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$SUCCESS' \
          WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
      else
        echo "" | tee -a $LOG_FILE
        echo "ERROR: Executable file ${BIN_DIR}/get2A23-25Meta.sh not found!" \
          | tee -a $LOG_FILE
        echo "Tag this rundate to be processed for metadata at a later run:" \
          | tee -a $LOG_FILE
	echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
          ('get2A2325Meta','$rundate','$MISSING');" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
        echo ""  | tee -a $LOG_FILE
        echo "Tag this script's run as INCOMPLETE, though problem is external:"\
          | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$INCOMPLETE' \
          WHERE app_id = 'getPRdata' AND datestamp = '$rundate';" \
          | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
    fi
fi

#cat $LOG_FILE
echo ""  | tee -a $LOG_FILE
echo "SCRIPT getPRdata.sh COMPLETE, EXITING." | tee -a $LOG_FILE
echo "See log file $LOG_FILE for script output."
echo "" | tee -a $LOG_FILE
exit
