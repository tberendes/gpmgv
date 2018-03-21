#!/bin/sh
#
################################################################################
#
#  get_PPS_CS_v4testdata_NSSL.sh     Morris/SAIC/GPM GV     March 2016
#
#  DESCRIPTION
#    Retrieves coincidence subset (CS) satellite files from PPS site:
#
#       arthurhou.pps.eosdis.nasa.gov
#
#    as listed in daily ftp_url files posted there by the PPS.  Filters out CS
#    file types not of interest to NSSL.
#
#  ROUTINES CALLED
#    getPPSftpListings_v4test_NSSL.sh
#    mirror                (Perl script package, via getPPSftpListings_v4test_NSSL.sh)
#    update_CS_dirs_v4test_NSSL.sh     (as needed for new ITE PPS versions)
#    wget utility
#
#  FILES
#
#  DATABASE
#    Not used.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    get_PPS_CS_v4testdata.YYYYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User must have write privileges in $DATA_DIR and its subdirectories
#
#  HISTORY
#    03/29/16      - Morris - Modified to run in OU environment without database
#                             I/O, and only ingest GPM CONUS subset data.
#
################################################################################

##### begin local configuration #####

GV_BASE_DIR=/oldeos/NASA_NMQ/satellite   # CHANGE THIS AS NEEDED, SEE BIN_DIR

DATA_DIR=/oldeos/NASA_NMQ/satellite/data      # CHANGE THIS AS NEEDED, SEE ALSO CS_BASE
if [ ! -s $DATA_DIR ]
  then
    echo "get_PPS_CS_v4testdata_NSSL.sh:  Directory $DATA_DIR non-existent, please correct."
    exit 1
  else
    export DATA_DIR
    echo "DATA_DIR: $DATA_DIR"
fi

# Downloaded data files are moved to a directory tree under $CS_BASE
# See also update_CS_dirs_v4test_NSSL.sh

CS_BASE=${DATA_DIR}/orbit_subset   # MUST BE SAME AS "ORB" IN update_CS_dirs_v4test_NSSL.sh
if [ ! -s $CS_BASE ]
  then
    echo "get_PPS_CS_v4testdata_NSSL.sh:  Directory $CS_BASE non-existent, please correct."
    exit 1
  else
    export CS_BASE
fi

# Orbit subset data and ftp_url files are originally downloaded to TMP_CS_DATA.
# Data files are moved to a directory tree under $CS_BASE, while the ftp_url
# files remain here so that mirror can determine which ftp_url files we have
# and which are new.

### TMP_CS_DATA MUST BE SAME AS MIR_DATA_DIR IN getPPSftpListings_NSSL.sh ###

TMP_CS_DATA=/oldeos/NASA_NMQ/satellite/data/tmp/PPS_CS   # CHANGE THIS AS NEEDED
if [ ! -s $TMP_CS_DATA ]
  then
    echo "get_PPS_CS_v4testdata_NSSL.sh:  Directory $TMP_CS_DATA non-existent, please correct."
    exit 1
  else
    export TMP_CS_DATA
fi

BIN_DIR=${GV_BASE_DIR}/scripts     # MUST BE SAME AS IN getPPSftpListings_v4test_NSSL.sh
if [ ! -s $BIN_DIR ]
  then
    echo "get_PPS_CS_v4testdata_NSSL.sh:  Directory $BIN_DIR non-existent, please correct."
    exit 1
fi

LOG_DIR=/oldeos/NASA_NMQ/satellite/data/logs
if [ ! -s $LOG_DIR ]
  then
    echo "get_PPS_CS_v4testdata_NSSL.sh:  Directory $LOG_DIR non-existent, please correct."
    exit 1
fi

##### end local configuration #####

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/get_PPS_CS_v4testdata.${rundate}.log       # script log file
export LOG_FILE

PATH=${PATH}:${BIN_DIR}

umask 0002

# verify that child scripts exist and are executable
if [ ! -x ${BIN_DIR}/getPPSftpListings_v4test_NSSL.sh ]
  then
    echo ""
    echo "Child script ${BIN_DIR}/getPPSftpListings_v4test_NSSL.sh"
    echo "not found or not executable, please correct."
    exit 1
    echo ""
fi

# file listing partial datestamp YYMMDD of ftp_url files to be processed this run
FILES2DO=${TMP_CS_DATA}/DatesToGet
rm -f $FILES2DO

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in wgetCStypes4date()
SATSUBTYPE_TEMP=${TMP_CS_DATA}/SatSubsetSubtype2do
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP

have_retries='f'  # indicates whether we have missing prior filedates to retry

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
# Function calling sequence: wgetCStypes4date $urlfile $TMP_CS_DATA
#

# ftp configuration for downloads
 ftpServer=arthurhou.pps.eosdis.nasa.gov
 ftpURL='ftp://'$ftpServer
 USERPASS=pierre.kirstetter@noaa.gov    # EDIT THIS IF NOT CORRECT FOR NSSL USER

# double check ftp_url file existence
 declare -i found=0
 foundman='n'
# check for the presence of ftp_url file (= $1) in TMP_CS_DATA (= $2)
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
#     for satellite in `cat $2/$1 | grep -v coincidence | cut -f12 -d '/' | cut -f2 -d '.' | sort -u`
     for satellite in GPM    # ignore ftp_url satellites, just do GPM
       do
         # set up the product types and subsets that we want for this satellite
         case $satellite in
            GPM )  subsets='CONUS'
                   datatypes='1C 2A 2B'
                   ;;
           TRMM )  subsets='CONUS'
                   datatypes='1C 2A 2B'
                   ;;
              * )  subsets='CONUS'
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
                 grep $filepre $2/$1 | grep -v XCAL | grep -v 'TRMM.PR.2A21' | cut -f4-12 -d '/' \
                  | tee $SATSUBTYPE_TEMP | tee -a $LOG_FILE
                 if [ -s $SATSUBTYPE_TEMP ]
                   then
                     # use wget to download the file(s) listed in $SATSUBTYPE_TEMP
                     wget -P $2  --user=$USERPASS --password=$USERPASS -B ${ftpURL} -i $SATSUBTYPE_TEMP

                     # check our success
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
                             # format the product type directory name ($Algo) based on rules
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
                             # subdirs for the latter as needed.
                             targetVersDir=${CS_BASE}/${satellite}/${Instrument}/${Algo}/${Version}
                             if [ ! -s $targetVersDir ]
                               then
                                 echo "Creating baseline directory $targetVersDir for $thisPPSfile"
                                 update_CS_dirs_v4test_NSSL.sh  ${satellite}/${Instrument}/${Algo}  ${Version}\
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

echo "$rundate" >> $FILES2DO

cd $TMP_CS_DATA
GOT_FILES='n'

if [ -s $FILES2DO ]
  then
    echo "Getting PPS ftp_url_YYYYMMDDhhmm.txt files:" | tee -a $LOG_FILE
    ${BIN_DIR}/getPPSftpListings_v4test_NSSL.sh
    if [ -s ${LOG_DIR}/PPSftpListings_v4test.${rundate}.log ]
      then
        # we have a valid mirror log file, check if for successful retrieval(s)
        grep Got ${LOG_DIR}/PPSftpListings_v4test.${rundate}.log
        if [ $? -eq 0 ]
          then
            # grab the names of the downloaded ftp_url files and write to FILES2DO
            URLFILES=`grep Got ${LOG_DIR}/PPSftpListings_v4test.${rundate}.log | cut -f2 -d ' '`
        fi
      else
        echo "No valid ftp_url files downloaded by getPPSftpListings_v4test_NSSL.sh, exiting."
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
        fi
    done
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "See log file: $LOG_FILE"

exit
