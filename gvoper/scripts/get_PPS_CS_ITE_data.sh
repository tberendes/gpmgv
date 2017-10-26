#!/bin/sh
#
################################################################################
#
#  get_PPS_CS_ITE_data.sh     Morris/SAIC/GPM GV     February 2014
#
#  DESCRIPTION
#    Retrieves ITE test version coincidence subset (CS) satellite files from PPS
#    ftp site:
#
#       arthurhou.pps.eosdis.nasa.gov
#
#    as listed in new ftp_url files posted there by the PPS.  Filters out CS
#    file types not of interest to the GPM Validation Network.  Should work for
#    any new ITE data versions posted by the PPS.
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
#    5/9/2014      - Morris - Added "KOREA" subset for redefined "KORA" bounds.
#    08/26/14      - Morris - Changed LOG_DIR to /data/logs and TMP_DIR to
#                             /data/tmp
#    02/26/15      - Morris - Added check of downloaded file pre-existence in
#                             targetDir before trying to move and catalog it a
#                             second time.  This is to handle a re-posting of
#                             previously incomplete ftp_url files by PPS.
#    03/09/15      - Morris - Added GPM subsets Guam, Hawaii, and SanJuanPR.
#    11/16/15      - Morris - Added GPM and constellation subset BrazilRadars.
#                           - Cleaned out obsolete logic and documentation in
#                             included function wgetCStypes4date()
#                           - Deleted obsolete LOG_DATA_FILE variable.
#    02/12/16      - Morris - Added GPM and constellation subset Finland.
#    02/16/17      - Morris - Removed constellation subset KORA and added
#                             constellation subsets AKradars, DARW, Guam,
#                             Hawaii, SanJuanPR as in update_CS_dirs_v4test.sh.
#    04/27/17      - Morris - Created from get_PPS_CS_v4testdata.sh.  Now calls
#                             getPPSftpListings_ITE.sh and update_CS_dirs_ITE.sh
#                             and uses app_id tag of 'get_ITE_CS' in the
#                             appstatus table in the gpmgv database.  Also
#                             updated PPS user ID and password.
#
################################################################################

GV_BASE_DIR=/home/gvoper
MACHINE=`hostname | cut -c1-3`
DATA_DIR=/data/emdata
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
CS_BASE=${DATA_DIR}/orbit_subset
export CS_BASE
TMP_CS_DATA=/data/tmp/PPS_v4test
export TMP_CS_DATA
BIN_DIR=${GV_BASE_DIR}/scripts

LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/get_PPS_CS_ITE_data.${rundate}.log       # script log file
export LOG_FILE

PATH=${PATH}:${BIN_DIR}

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
# Parses a previously retrieved PPS "ftp_url" file to find out which files
# have been posted on the ftp site for that particular PPS update.
# Filters ftp_url file contents to get only the product(s) of interest for each
# satellite of interest.  ftp_url contains full pathnames of files on ftp site.
# Downloads data files of interest to the directory defined by TMP_CS_DATA.
# If the ftp_url file defined by arguments $2/$1 is not found, record the
# failure in the log file and do not increment $found variable.
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
#  version      | character varying(8)   | not null default 6  - changed to varchar(8) on 2/10/16
#
# Function calling sequence: wgetCStypes4date $urlfile $TMP_CS_DATA
#

# ftp configuration for downloads
 ftpServer=arthurhou.pps.eosdis.nasa.gov
 ftpURL='ftp://'$ftpServer
 USERPASS=todd.a.berendes@nasa.gov

# double check ftp_url file existence
 declare -i found=0
 foundman='n'
# check for the presence of ftp_url file "$1" in TMP_CS_DATA ($2)
 manfilelist=`ls $2/$1`
 if [ $? != 0 ]
   then
      echo "Failed to find file $2/$1" | tee -a $LOG_FILE
   else
      found=found+1
      foundman='y'
      echo "Processing ftp_url file $manfilelist" | tee -a $LOG_FILE
 fi

 # walk through the ftp_url_yyyymmddhhmm.txt file and identify
 # instruments/products/subsets of interest
 if [ "$foundman" = "y" ]
   then
     # get a sorted, unique list of satellites included in ftp_url
     for satellite in `cat $2/$1 | grep -v coincidence | cut -f12 -d '/' | cut -f2 -d '.' | sort -u`
       do
         # set up the product types and subsets that we want for this satellite
         case $satellite in
            GPM )  subsets='AKradars BrazilRadars CONUS DARW KORA KOREA KWAJ Guam Hawaii SanJuanPR Finland'
                   datatypes='1C 2A 2B'
                   ;;
           TRMM )  subsets='CONUS DARW KORA KOREA KWAJ'
                   datatypes='1C 2A 2B'
                   ;;
              * )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland'
                   datatypes='1C-R 2A'
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
                 grep $filepre $2/$1 | grep -v XCAL | grep -v 'TRMM.PR.2A21' | cut -f4-12 -d '/' \
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
                             YMDdir=`echo $thisPPSdir | cut -f 5-7 -d '/'`
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
                                 # apply special cases for GPM non-GPROF
                                 case $satellite in
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
                                 update_CS_dirs_ITE.sh  ${satellite}/${Instrument}/${Algo}  ${Version}\
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
                                 if [ -f ${targetDir}/$thisPPSfile ]
                                   then
                                     echo "Already have ${targetDir}/$thisPPSfile" | tee -a $LOG_FILE
                                     #ls -al ${targetDir}/$thisPPSfile | tee -a $LOG_FILE
                                     rm -v $2/$thisPPSfile | tee -a $LOG_FILE
                                   else
                                     mv -v $2/$thisPPSfile ${targetDir} | tee -a $LOG_FILE
                                     echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" \
	                                | psql -a -d gpmgv  >> $LOG_FILE 2>&1
                                 fi
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
    HOST=`hostname`
    thistime=`date -u`
    echo "Message from get_PPS_CS_data.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "ERROR: ${pgproccount} Postgres processes active, should be 3+ !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ${HOST}' \
      -c kenneth.r.morris@nasa.gov,todd.a.berendes@nasa.gov \
      makofski@radar.gsfc.nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3+." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

#exit  #uncomment for just testing e-mail notifications

echo "Checking whether we have an entry for this date in database."\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "\pset format u \t \o ${DBTEMPFILE} \\\ SELECT * FROM appstatus WHERE \
 app_id = 'get_ITE_CS' AND datestamp = '$rundate';" | psql -a -d gpmgv \
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
      ('get_ITE_CS','$rundate','$UNTRIED');" | psql -a -d gpmgv \
      | tee -a $LOG_FILE 2>&1
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ ${status} != $SUCCESS ]
  then
    echo "$rundate" >> $FILES2DO
  else
  echo "All PPS CS acquisition seems up-to-date, exiting."\
   | tee -a $LOG_FILE
  exit 0
fi

# increment the ntries column in the appstatus table for $MISSING, 
# $UNTRIED, $INCOMPLETE cycles
echo "" | tee -a $LOG_FILE
echo "UPDATE appstatus SET ntries=ntries+1 WHERE app_id = 'get_ITE_CS' AND \
 status IN ('$MISSING','$UNTRIED','$INCOMPLETE');" \
 | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

cd $TMP_CS_DATA

GOT_FILES='n'

if [ -s $FILES2DO ]
  then
    echo "Getting PPS ftp_url_YYYYMMDDhhmm.txt files:" | tee -a $LOG_FILE
    ${BIN_DIR}/getPPSftpListings_ITE.sh
    if [ -s ${LOG_DIR}/PPSftpListings_ITE.${rundate}.log ]
      then
        # we have a valid mirror log file, check if for successful retrieval(s)
        grep Got ${LOG_DIR}/PPSftpListings_ITE.${rundate}.log
        if [ $? -eq 0 ]
          then
            # grab the names of the downloaded ftp_url files and write to FILES2DO
            URLFILES=`grep Got ${LOG_DIR}/PPSftpListings_ITE.${rundate}.log | cut -f2 -d ' '`
        fi
      else
        echo "No valid ftp_url files downloaded by getPPSftpListings_ITE.sh, exiting."
        echo "Mark incomplete in database:" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "UPDATE appstatus SET status = '$MISSING' WHERE \
	       app_id = 'get_ITE_CS' AND datestamp = '$rundate';" \
            | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
        exit 1
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
            echo "Got data from ftp_url file $fdate" | tee -a $LOG_FILE
            GOT_FILES='y'
        else
            echo "" | tee -a $LOG_FILE
            echo "No ftp_url file or failed data files for $fdate" | tee -a $LOG_FILE
            echo "Mark incomplete in database:" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
	    echo "UPDATE appstatus SET status = '$INCOMPLETE' WHERE \
	          app_id = 'get_ITE_CS' AND datestamp = '$rundate';" \
		  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
        fi
    done
fi

if [ $GOT_FILES = 'y' ]
  then
    echo "Mark success in database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
          app_id = 'get_ITE_CS' AND datestamp = '$rundate';" \
	  | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
     
    # Call the wrapper script, get_PR_DPR_Meta.sh, to run the scripts that
    # run the IDL .bat files to extract the PR and DPR file metadata.
    # It's slow, so run it in the background so that this script can complete.
  #CODE BLOCK REMOVED
fi

# set status to $FAILED in the appstatus table for $MISSING rows where ntries
# reaches 5 times.  Don't want to continue for too many days if file is missing.
echo "" | tee -a $LOG_FILE
echo "Set status to FAILED where this is the 5th failure for any downloads:"\
 | tee -a $LOG_FILE
echo "UPDATE appstatus SET status='$FAILED' WHERE app_id = 'get_ITE_CS' AND \
 status='$MISSING' AND ntries > 4;" | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1



echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
