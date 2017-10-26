#!/bin/sh
#
################################################################################
#
#  catalog_PPS_CS_leftovers.sh     Morris/SAIC/GPM GV     July 2014
#
#  DESCRIPTION
#    Catalogs previously downloaded coincidence subset (CS) satellite files 
#    sitting in the /data/tmp/PPS_CS directory.  Filters out CS
#    file types not of interest to the GPM Validation Network.
#
#  ROUTINES CALLED
#
#  FILES
#
#  DATABASE
#    disabled.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalog_PPS_CS_data.YYYYMMDD.log in /data/logs subdirectory.
#
#  CONSTRAINTS
#    - User must have write privileges in CS_BASE and its subdirectories,
#      TMP_CS_DATA, and LOG_DIR.  This is why we had to write this in the
#      first place.
#    - List of YYMMDD dates of manifest files to process must be in existing
#      file $FILES2DO.
#
#  HISTORY
#    March 2014    - Morris - Created
#    August 2014   - Morris/SAIC/GPM GV - Changed LOG_DIR to /data/logs and
#                    TMP_CS_DATA to /data/tmp/PPS_CS
#    03/09/15      - Morris - Added GPM subsets Guam, Hawaii, and SanJuanPR.
#    05/21/15      - Morris - Added GPM subset Brisbane.
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
TMP_CS_DATA=/data/tmp/PPS_CS
export TMP_CS_DATA
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalog_PPS_CS_leftovers.${rundate}.log
export LOG_FILE
PATH=${PATH}:${BIN_DIR}
ZZZ=1800

umask 0002

# file listing partial datestamp YYMMDD of manifest files to be processed this run
FILES2DO=${TMP_CS_DATA}/DatesToGet

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in catalogCStypes4date()
SATSUBTYPE_TEMP=${TMP_CS_DATA}/SatSubsetSubtype2redo
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP


# DEFINE FUNCTIONS

################################################################################
function catalogCStypes4date() {

# Use wget to download coincidence subsets for each type from PPS ftp site.
# Retrieves and parses the daily PPS "manifest" file datestamped with $fulldate
# to find out which files have been posted on the ftp site for that date.
# Filters to manifest file to get only the product(s) of interest for each
# satellite of interest.  Manifest contains full pathnames of files on ftp site.
# Downloads manifest and data files to the directory defined by TMP_CS_DATA.
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
# Function calling sequence: catalogCStypes4date $daydir $TMP_CS_DATA $fulldate
#

 declare -i tries=0
 declare -i found=0

           runagain='n'
           foundman='y'

 # walk through the manifest and identify instruments/products/subsets of interest
 if [ "$foundman" = "y" ]
   then
     # get a sorted, unique list of satellites included in PPS_CS directory
     for satellite in `ls $2/*-CS-*HDF* | cut -f2 -d '.' | sort -u`
       do
         # set up the product types and subsets that we want for this satellite
         case $satellite in
            GPM )  subsets='Brisbane'
                   datatypes='1C 2A 2B'
                   ;;
           TRMM )  subsets='Brisbane'
                   datatypes='1C 2A 2B'
                   ;;
              * )  subsets='CONUS KORA KWAJ KOREA NPOL'
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
                 filepre=${datatype}-CS-${subset}.${satellite}*
                 # identify any matching files from manifest, store list in temp file
                 ls $2/$filepre | grep -v XCAL | grep -v 'TRMM.PR.2A21' \
                  | tee $SATSUBTYPE_TEMP | tee -a $LOG_FILE
                 if [ -s $SATSUBTYPE_TEMP ]
                   then

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
                             YMDdir=`echo $thisPPSfile | cut -f5 -d '.' | cut -f1 -d '-' \
                                   | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
                             # extract the version specification from the ftp filepath
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
                             if [ ! -d $targetDir1 ]
                               then
                                 echo "ERROR: Missing baseline directory $targetDir1 for file $2/$thisPPSfile" \
                                   | tee -a $LOG_FILE
                                 echo "Leaving $2/$thisPPSfile uncataloged and in place." \
                                   | tee -a $LOG_FILE
                               else
                                 targetDir=${targetDir1}/${YMDdir}
                                 mkdir -p -v $targetDir
                                 mv -v $2/$thisPPSfile ${targetDir} | tee -a $LOG_FILE
	                         echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" \
	                          | psql -a -d gpmgv  >> $LOG_FILE 2>&1
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


#  Get the date string for desired day's date by calling offset_date.
csdate=`offset_date $today -1`

#  Get the Julian representation of csdate: YYYYMMDD -> YYYYjjj
julcsdate=`ymd2yd $csdate`

#  Get the subdirectory on the ftp site under which our day's data are located,
#  in the format YYYY/MM/DD
csdaydir=`echo $csdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
echo 'New directory subtree for downloads: $csdaydir' | tee $LOG_FILE 2>&1

#  Trim date string to use a 2-digit year, as in appstatus.datestamp convention
yymmdd=`echo $csdate | cut -c 3-8`

echo "Getting PPS CS files for date $csdate" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

#    echo "$yymmdd" >> $FILES2DO

echo "" | tee -a $LOG_FILE
echo "Dates to process this run:" | tee -a $LOG_FILE
cat $FILES2DO | tee -a $LOG_FILE
#exit


cd $TMP_CS_DATA

if [ -s $FILES2DO ]
  then
    echo "Getting PPS CS files." | tee -a $LOG_FILE
    for fdate in `cat $FILES2DO`
      do
        #  Get the complete representation of date: YYMMDD -> YYYYMMDD
        fulldate=20${fdate}
        #  Get the subdirectory on the ftp site under which our day's data are located,
        #  in the format YYYY/MM/DD
        daydir=`echo $fulldate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
        echo "Get files for ${daydir} from ftp site." | tee -a $LOG_FILE
        catalogCStypes4date $daydir $TMP_CS_DATA $fulldate
        if [ $? -eq 1 ]
          then
            echo "Got data from manifest file for $fulldate" | tee -a $LOG_FILE
        else
            echo "" | tee -a $LOG_FILE
            echo "No manifest file or failed data files for $fdate" | tee -a $LOG_FILE
        fi
    done
fi

echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
