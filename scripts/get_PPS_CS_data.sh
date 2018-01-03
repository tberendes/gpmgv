#!/bin/sh
#
################################################################################
#
#  get_PPS_CS_data.sh     Morris/SAIC/GPM GV     February 2014
#
#  DESCRIPTION
#    Retrieves coincidence subset (CS) satellite files from PPS site:
#
#       arthurhou.pps.eosdis.nasa.gov
#
#    as listed in daily ftp_url files posted there by the PPS.  Filters out CS
#    file types not of interest to the GPM Validation Network.
#
#  ROUTINES CALLED
#
#  FILES
#
#  DATABASE
#    Catalogs data in 'orbit_subset_products' table in 'gpmgv' database in
#    PostGRESQL via call to psql utility.  Tracks status of file retrieval
#    in 'appstatus' table.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    get_PPS_CS_data.YYYYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table. 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $DATA_DIR and its subdirectories
#
#  HISTORY
#    March 2014    - Morris - Created from wgetKWAJ_PR_CSI.sh
#    4/3/2014      - Morris - Added steps to gzip TRMM legacy products in HDF4.
#                           - Changed to call get_PR_DPR_Meta.sh instead of
#                             get2A23-25MetaNew.sh.
#    4/11/2014     - Morris - Modified to work with ftp_url_YYYYMMDD.txt files
#                             instead of manifest files, with new paths on PPS
#                             ftp site.
#    4/14/2014     - Morris - Modified to call getPPSftpListings.sh to retrieve
#                             one or more ftp_url_YYYYMMDDhhmm.txt files for a
#                             given date.
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
CS_BASE=${DATA_DIR}/orbit_subset
export CS_BASE
TMP_CS_DATA=${DATA_DIR}/tmp/PPS_CS
export TMP_CS_DATA
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/get_PPS_CS_data.${rundate}.log
export LOG_FILE
LOG_DATA_FILE=${LOG_DIR}/PPS_CS_newfiles.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=1800

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_CS_DATA}/dbtempfile

# file listing partial datestamp YYMMDD of ftp_url files to be processed this run
FILES2DO=${TMP_CS_DATA}/DatesToGet
rm -f $FILES2DO

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in wgetCStypes4date()
SATSUBTYPE_TEMP=${TMP_CS_DATA}/SatSubsetSubtype2do
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP

# file listing status of each date's download attempts
THE_SCOOP=${TMP_CS_DATA}/DateStatus
rm -f $THE_SCOOP

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error
INCOMPLETE='I' # got fewer than all the expected file types for an orbit

have_retries='f'  # indicates whether we have missing prior filedates to retry
status=$UNTRIED   # assume we haven't yet tried to get current file

# DEFINE FUNCTIONS

################################################################################
function wgetCStypes4date() {

# Use wget to download coincidence subsets for each type from PPS ftp site.
# Retrieves and parses the daily PPS "ftp_url" file datestamped with $fulldate
# to find out which files have been posted on the ftp site for that date.
# Filters to ftp_url file to get only the product(s) of interest for each
# satellite of interest.  ftp_url contains full pathnames of files on ftp site.
# Downloads ftp_url and data files to the directory defined by TMP_CS_DATA.
# Repeat attempts at intervals of $ZZZ seconds if file(s) not retrieved in
# first attempt.  If a file of interest is not found, record the failure in the
# log file and do not increment $found variable.
#
# The directory structure into which the downloaded products will be moved is:
#
# satellite/             (GPM, TRMM, F16, etc.)
#   instrument/          (DPR, GMI, SSMIS, etc.)
#     algorithm/         (2AGPROF, 2BDPRGMI, 2A25, 2AKa, 2Aku, etc.), 
#       version/         (V00A, V00B, V01, V07, etc.)
#         subset/        (CONUS, KWAJ, KORA, etc.)
#           year/        (2014, 2015,…)
#             month/     (01, 02, …, 12)
#               day/     (01, 02, …, 28, 29, 30, 31)
#                 (data files)
#
# under the common directory defined by $CS_BASE.
#
# The database table "orbit_subset_product: where the downloaded files are
# cataloged has the schema:
#
#     Column    |          Type          |     Modifiers      
# --------------+------------------------+--------------------
#  sat_id       | character varying(15)  | not null
#  orbit        | integer                | not null
#  product_type | character varying(15)  | not null
#  filedate     | date                   | 
#  filename     | character varying(120) | 
#  subset       | character varying(15)  | not null
#  version      | character varying(5)   | not null default 6
#
# Function calling sequence: wgetCStypes4date $urlfile $TMP_CS_DATA
#

 declare -i tries=0
 declare -i found=0
 ZZZ=1
# ftpURL='ftp://arthurhou.pps.eosdis.nasa.gov'
 ftpServer=arthurhou.pps.eosdis.nasa.gov
 ftpURL='ftp://'$ftpServer
 USERPASS=kenneth.r.morris@nasa.gov
# mandir=/gpmuser/$USERPASS/scripts

 runagain='y'
 foundman='n'
 while [ "$runagain" != 'n' ]
   do
      tries=tries+1
      echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
      # check for the presence of url_ftp file in $TMP_CS_DATA
      manfilelist=`ls $2/$1`
      if [ $? != 0 ]
        then
           if [ $tries -eq 5 ]
             then
                runagain='n'
                echo "Failed after 5 tries, giving up." | tee -a $LOG_FILE
             else
                echo "Failed to find file $2/$1, sleeping $ZZZ s before next try." | tee -a $LOG_FILE
                sleep $ZZZ
             fi
        else
           found=found+1
           runagain='n'
           foundman='y'
           echo "Have ftp_url file $manfilelist" | tee -a $LOG_FILE
      fi
 done

 # walk through the ftp_url_yyyymmddhhmm.txt file and identify
 # instruments/products/subsets of interest
 if [ "$foundman" = "y" ]
   then
     # get a sorted, unique list of satellites included in ftp_url
     for satellite in `cat $2/$1 | grep -v coincidence | cut -f11 -d '/' | cut -f2 -d '.' | sort -u`
       do
         # set up the product types and subsets that we want for this satellite
         case $satellite in
            GPM )  subsets='AKradars CONUS DARW KORA KWAJ'
                   datatypes='1C 2A 2B'
                   ;;
           TRMM )  subsets='CONUS DARW KORA KWAJ'
                   datatypes='1C 2A 2B'
                   ;;
              * )  subsets='CONUS KORA KWAJ NPOL'
                   datatypes='2A'
                   ;;
         esac

         # walk through the subsets and product types, and retrieve qualifying data files
         for subset in `echo $subsets`
           do
             for datatype in `echo $datatypes`
               do
                 echo "" | tee -a $LOG_FILE
                 echo "Getting ${datatype} files for ${satellite} for ${subset} subset:" | tee -a $LOG_FILE
                 echo "" | tee -a $LOG_FILE
                 # build the filebasename pattern for this combination
                 filepre=${datatype}-CS-${subset}.${satellite}
                 # identify any matching files from ftp_url, store list in temp file
                 grep $filepre $2/$1 | grep -v XCAL | grep -v 'TRMM.PR.2A21' | cut -f4-11 -d '/' \
                  | tee $SATSUBTYPE_TEMP | tee -a $LOG_FILE
                 if [ -s $SATSUBTYPE_TEMP ]
                   then
                     # use wget to download the file(s) listed in $SATSUBTYPE_TEMP
                     wget -P $2  --user=$USERPASS --password=$USERPASS -B ${ftpURL} -i $SATSUBTYPE_TEMP

                     # check our success and catalog downloaded file(s) in database
                     for thisPPSfilepath in `cat $SATSUBTYPE_TEMP`
                       do
                         # extract the file basename and dirname from thisPPSfilepath
                         thisPPSfile=${thisPPSfilepath##*/}
                         thisPPSdir=${thisPPSfilepath%/*}
                         # check our success
                         if [ -s $2/$thisPPSfile ]
                           then
                             echo "Got $2/$thisPPSfile" | tee -a $LOG_FILE
                             # get info needed to catalog and move the file to baseline tree
                             # extract the YYYY/MM/DD directory specification for the file
                             YMDdir=`echo $thisPPSdir | cut -f 4-6 -d '/'`
                             # extract the version specification from the filename
                             Version=`echo $thisPPSfile | cut -f 7 -d '.'`
                             # extract the orbit, instrument and algorithm names from the file basename
                             Orbit=`echo $thisPPSfile | cut -f 6 -d '.'`
                             Instrument=`echo $thisPPSfile | cut -f 3 -d '.'`
                             AlgoLong=`echo $thisPPSfile | cut -f 4 -d '.'`
                             # format the product_type column value for the database based on rules
                             echo $AlgoLong | grep GPROF > /dev/null
                             if [ $? = 0 ]
                               then
                                 # just use '2AGPROF' as algorithm name
                                 Algo=2AGPROF
                               else
                                 # apply special cases for TRMM and GPM non-GPROF
                                 case $satellite in
                                   TRMM ) Algo=$AlgoLong    # just use what's given, e.g., '2A25'
                                          if [ "$Version" = "7" ]
                                            then
                                              Version="V0"$Version  # convert to naming standard
                                              # compress file if not already in gzip
                                              gzip -l $2/$thisPPSfile > /dev/null 2>&1
                                              if [ $? = 1 ]
                                                then
                                                  echo "Compressing $2/$thisPPSfile with gzip" \
                                                    | tee -a $LOG_FILE
                                                  gzip $2/$thisPPSfile
                                                  thisPPSfilegz=${thisPPSfile}.gz
                                                  thisPPSfile=${thisPPSfilegz}
                                              fi
                                          fi
                                          ;;
                                    GPM ) prodTypeLong=`echo $thisPPSfile | cut -f 1 -d '.'`
                                          # see if we have '-' in 1st file subfield, e.g. '2A-CS-KWAJ'
                                          echo $prodTypeLong | grep '-' > /dev/null
                                          if [ $? = 0 ]
                                            then
                                              # have a compound product type/subset field, cut out type
                                              prodType=`echo $prodTypeLong | cut -f1 -d '-'`
                                            else
                                              # have a simple type indicator, use as-is
                                              prodType=$prodTypeLong
                                          fi
                                          # concatenate type and Instrument
                                          Algo=${prodType}${Instrument}  # e.g., '2AKu'
                                          ;;
                                 esac
                             fi
                             # Move the file into its proper place in the baseline
                             # directory structure.  Update the version and year/month/day
                             # subdirs for the latter as needed.  Catalog moved files in
                             # 'gpmgv' database table 'orbit_subset_product'
                             targetVersDir=${CS_BASE}/${satellite}/${Instrument}/${Algo}/${Version}
                             if [ ! -s $targetVersDir ]
                               then
                                 echo "Creating baseline directory $targetVersDir for $thisPPSfile"
                                 update_CS_dirs.sh  ${satellite}/${Instrument}/${Algo}  ${Version}\
                                   | tee -a $LOG_FILE
                             fi
                             targetDir1=${CS_BASE}/${satellite}/${Instrument}/${Algo}/${Version}/${subset}
                             if [ ! -s $targetDir1 ]
                               then
                                 echo "ERROR: Missing baseline directory $targetDir1 for file $2/$thisPPSfile" \
                                   | tee -a $LOG_FILE
                                 echo "Leaving $2/$thisPPSfile uncataloged and in place." \
                                   | tee -a $LOG_FILE
                               else
                                 targetDir=${targetDir1}/${YMDdir}
                                 mkdir -p -v $targetDir
                                 echo "mv -v $2/$thisPPSfile ${targetDir}" | tee -a $LOG_FILE
	                              echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" #\
#	                              | psql -a -d gpmgv  >> $LOG_FILE 2>&1
                             fi
                           else
                             echo "ERROR: Failed to download PPS file: $thisPPSfilepath" | tee -a $LOG_FILE
                         fi
                     done
                   else
                     echo "No matching files for pattern: $filepre" | tee -a $LOG_FILE
                 fi
             done
         done
     done
 fi

 return $found
}
################################################################################

# BEGIN MAIN SCRIPT

today=`date -u +%Y%m%d`
echo "===================================================" | tee $LOG_FILE
echo " Attempting download of PPS CS files on $today." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from get_PPS_CS_data.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "ERROR: ${pgproccount} Postgres processes active, should be 3+ !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ${HOST}' \
      kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3+." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

#exit  #uncomment for just testing e-mail notifications

#  Get the date string for desired day's date by calling offset_date.
csdate=`offset_date $today -1`

#  Get the Julian representation of csdate: YYYYMMDD -> YYYYjjj
julcsdate=`ymd2yd $csdate`

#  Get the subdirectory on the ftp site under which our day's data are located,
#  in the format YYYY/MM/DD
csdaydir=`echo $csdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
echo 'New directory subtree for downloads: $csdaydir' | tee -a $LOG_FILE 2>&1

#  Trim date string to use a 2-digit year, as in appstatus.datestamp convention
yymmdd=`echo $csdate | cut -c 3-8`

echo "Getting PPS CS files for date $csdate" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "Checking whether we have an entry for this date in database."\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'get_PPS_CS' AND datestamp = '$yymmdd';" | psql -a -d gpmgv \
 | tee -a $LOG_FILE 2>&1

if [ -s ${DBTEMPFILE} ]
  then
     # We've tried to get this day's files before, check our past status.
     status=`cat ${DBTEMPFILE} | cut -f5 -d '|'`
     echo "" | tee -a $LOG_FILE
     echo "Have status=${status} from prior attempt." | tee -a $LOG_FILE
  else
     # Empty file indicates no row exists for this file datestamp, so insert one
     # now with defaults for first_attempt and ntries columns
     echo "" | tee -a $LOG_FILE
     echo "No prior attempt, initialize status in database:" | tee -a $LOG_FILE
     echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
      ('get_PPS_CS','$yymmdd','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Checking whether we have prior missing datestamps to process."\
  | tee -a $LOG_FILE

echo "Check for actual prior attempts which failed for external reasons:"\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus \
      WHERE app_id = 'get_PPS_CS' \
        AND status IN ('$MISSING','$UNTRIED','$INCOMPLETE') \
        AND datestamp != '$yymmdd';" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
if [ -s ${DBTEMPFILE} ]
  then
    echo "Dates of prior MISSING:" | tee -a $LOG_FILE
    for filemsg in `cat ${DBTEMPFILE} | cut -f3 -d '|'`
      do
        echo $filemsg | tee -a $LOG_FILE
	echo "$filemsg" >> $FILES2DO
    done
  else
    echo "No prior dates with status MISSING." | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Check for prior dates never attempted due to local problems:"\
  | tee -a $LOG_FILE
# Do so by looking for a gap in dates of >1 between last attempt registered
# in the database, and the current attempt date

STAMPLAST=`psql -q -t -d gpmgv -c "SELECT MAX(datestamp) FROM appstatus WHERE \
 app_id = 'get_PPS_CS' AND datestamp != '$yymmdd';" | sed 's/ //g'`

#echo "${STAMPLAST}" | tee -a $LOG_FILE
# set STAMPLAST to $yymmdd if NO HITS from database
if [ "${STAMPLAST}" = "" ]
  then
    STAMPLAST=$yymmdd
    echo "setting STAMPLAST"
fi
echo "Last date previously attempted was ${STAMPLAST}" | tee -a $LOG_FILE
#echo "" | tee -a $LOG_FILE
DATELAST=`echo 20$STAMPLAST | sed 's/ //'`
#echo DATELAST=$DATELAST
DATEGAP=`grgdif $csdate $DATELAST`
#echo DATEGAP=$DATEGAP
#exit
if [ `expr $DATEGAP \> 1` = 1 ]
  then
     while [ `expr $DATEGAP \> 1` = 1 ]
       do
         DATELAST=`offset_date $DATELAST 1`
         yymmddNever=`echo $DATELAST | cut -c 3-8`
         echo "No prior attempt of $yymmddNever, initialize status in database:"\
           | tee -a $LOG_FILE
         echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
           ('get_PPS_CS','$yymmddNever','$UNTRIED');" | psql -a -d gpmgv \
           | tee -a $LOG_FILE 2>&1
         # add this date to the temp file, preceded by bogus '|'-delimited values
         # so the format is compatible with the MISSING dates query output
         echo "$yymmddNever" >> $FILES2DO
         DATEGAP=`grgdif $csdate $DATELAST`
         echo "" | tee -a $LOG_FILE
     done
  else
    echo "No gaps found in dates processed."
fi

if [ -s $FILES2DO ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Need to retry downloads for missing file dates below:" \
       | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
  else
#     echo "" | tee -a $LOG_FILE
     echo "No missing prior dates found." | tee -a $LOG_FILE
     if [ $status = $SUCCESS ]
       then
	  echo "All PPS CS acquisition seems up-to-date, exiting."\
	   | tee -a $LOG_FILE
	  exit 0
     fi
fi

if [ ${status} != $SUCCESS ]
  then
    echo "$yymmdd" >> $FILES2DO
fi

echo "" | tee -a $LOG_FILE
echo "Dates to process this run:" | tee -a $LOG_FILE
cat $FILES2DO | tee -a $LOG_FILE
#exit

# increment the ntries column in the appstatus table for $MISSING, 
# $UNTRIED, $INCOMPLETE cycles
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'get_PPS_CS' AND \
 status IN ('$MISSING','$UNTRIED','$INCOMPLETE');" \
 | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

cd $TMP_CS_DATA

if [ -s $FILES2DO ]
  then
    echo "Getting PPS ftp_url_YYYYMMDDhhmm.txt files:" | tee -a $LOG_FILE
    ${BIN_DIR}/getPPSftpListings.sh
    if [ -s ${LOG_DIR}/PPSftpListings.${rundate}.log ]
      then
        # we have a valid mirror log file, check if for successful retrieval(s)
        grep Got ${LOG_DIR}/PPSftpListings.${rundate}.log
        if [ $? -eq 0 ]
          then
            # grab the names of the downloaded ftp_url files and write to FILES2DO
            URLFILES=`grep Got ${LOG_DIR}/PPSftpListings.${rundate}.log | cut -f2 -d ' '`
        fi
      else
          echo "No valid ftp_url files downloaded by getPPSftpListings.sh, exiting."
          echo "Mark incomplete in database:" | tee -a $LOG_FILE
          echo "" | tee -a $LOG_FILE
          echo "UPDATE appstatus SET status = '$MISSING' WHERE \
	         app_id = 'get_PPS_CS' AND datestamp = '$fdate';" \
            | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
          exit 1
       fi
    fi
    echo ""  | tee -a $LOG_FILE 2>&1
    echo "Getting PPS CS files." | tee -a $LOG_FILE
    echo "URLFILES: $URLFILES" | tee -a $LOG_FILE 2>&1
    echo ""  | tee -a $LOG_FILE 2>&1
    for fdate in `echo $URLFILES`
      do
        #  Get the complete representation of date: YYYYMMDD
        fulldate=`echo ${fdate} | cut -c 9-16`
        #  Get the subdirectory on the ftp site under which our day's data are located,
        #  in the format YYYY/MM/DD
        daydir=`echo $fulldate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
        echo "Get files for ${daydir} from ftp site." | tee -a $LOG_FILE
        wgetCStypes4date $fdate $TMP_CS_DATA
        if [ $? -eq 1 ]
          then
            echo "Got data from ftp_url file for $fulldate" | tee -a $LOG_FILE
            echo "Mark success in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
	          app_id = 'get_PPS_CS' AND datestamp = '$fdate';" \
		  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
     
            # Call the wrapper script, get_PR_DPR_Meta.sh, to run the scripts that
            # run the IDL .bat files to extract the PR and DPR file metadata.
            # It's slow, so run it in the background so that this script can complete.
            if [ -x ${BIN_DIR}/get_PR_DPR_Meta.sh ]
              then
                echo "" | tee -a $LOG_FILE
                echo "Calling get_PR_DPR_Meta.sh to extract PR and DPR file metadata." \
                  | tee -a $LOG_FILE
    
                ${BIN_DIR}/get_PR_DPR_Meta.sh $fdate &
    
                echo "See log file ${LOG_DIR}/get_PR_DPR_Meta.${fdate}.log" \
                 | tee -a $LOG_FILE
                echo ""  | tee -a $LOG_FILE
              else
                echo "" | tee -a $LOG_FILE
                echo "ERROR: Executable file ${BIN_DIR}/get_PR_DPR_Meta.sh not found!" \
                  | tee -a $LOG_FILE
                echo "Tag this rundate to be processed for metadata at a later run:" \
                  | tee -a $LOG_FILE
	        echo "INSERT INTO appstatus(app_id,datestamp,status) VALUES \
                  ('get2A2325Meta','$fdate','$MISSING');" | psql -a -d gpmgv \
                  | tee -a $LOG_FILE 2>&1
                echo ""  | tee -a $LOG_FILE
                echo "Tag this script's run as INCOMPLETE, though problem is external:"\
                  | tee -a $LOG_FILE
                echo "UPDATE appstatus SET status = '$INCOMPLETE' \
                  WHERE app_id = 'get_PPS_CS' AND datestamp = '$fdate';" \
                  | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
            fi
        else
            echo "" | tee -a $LOG_FILE
            echo "No ftp_url file or failed data files for $fdate" | tee -a $LOG_FILE
            echo "Mark incomplete in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$INCOMPLETE' WHERE \
	          app_id = 'get_PPS_CS' AND datestamp = '$fdate';" \
		  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
        fi
    done
fi

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 5 times.  Don't want to continue for too many days if file is missing.
echo "" | tee -a $LOG_FILE
echo "Set status to FAILED where this is the 5th failure for any downloads:"\
 | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'get_PPS_CS' AND \
 status='$MISSING' AND ntries > 4;" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1



echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
