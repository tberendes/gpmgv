#!/bin/sh
#
################################################################################
#
#  catalog_PPS_CS_data.sh     Morris/SAIC/GPM GV     March 2014
#
#  DESCRIPTION
#    Catalogs coincidence subset (CS) satellite files previously downloaded
#    from the PPS but still sitting in the temporary directory.  Filters out CS
#    file types not of interest to the GPM Validation Network.  The files to
#    be stepped through are those HDF files still sitting in the directory
#    /data/tmp/PPS_CS, as populated by the prior run of get_PPS_CS_data.sh.
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
#    catalog_PPS_CS_data.YYYYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User must have write privileges in CS_BASE and its subdirectories,
#      TMP_CS_DATA, and LOG_DIR.
#
#  HISTORY
#    March 2014    - Morris - Created
#    August 2014   - Morris/SAIC/GPM GV - Changed LOG_DIR to /data/logs and
#                    TMP_CS_DATA to /data/tmp/PPS_CS
#    11/16/16      - Morris - Added GPM and constellation subset BrazilRadars.
#    05/01/17      - Morris - Added functionality to build the list of HDF5
#                    files still uncataloged/unmoved, and process all satellites
#                    and subsets of interest.
#                  - Added check of Postgres status before starting.
#
################################################################################

GV_BASE_DIR=/home/morris
DATA_DIR=/data/gpmgv
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
CS_BASE=${DATA_DIR}/orbit_subset
export CS_BASE
TMP_CS_DATA=/data/tmp/PPS_CS
export TMP_CS_DATA
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalog_PPS_CS_data_existing.${rundate}.log
export LOG_FILE
PATH=${PATH}:${BIN_DIR}

umask 0002

today=`date -u +%Y%m%d`
echo "===================================================" | tee $LOG_FILE
echo " Re-attempt cataloging of PPS CS files on $today." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from catalog_PPS_CS_data.sh job on ${thistime}:" \
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

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in catalogCStypes4date()
SATSUBTYPE_TEMP=/tmp/SatSubsetSubtype2do
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP

#
# The directory structure into which the downloaded products exist is:
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

cd $TMP_CS_DATA

 # get a listing of HDF5 files in this temporary directory that didn't get
 # processed correctly (moved and cataloged) in prior data ingest run(s)

      filelist=/tmp/OrphanHDF5.listing.txt
      ls *.HDF5 > $filelist
      if [ $? != 0 ]
        then
           echo "Failed to get file listing."\
                | tee -a $LOG_FILE
           exit 1
        else
           echo "Have listing file $filelist" | tee -a $LOG_FILE
           ls -al $filelist
      fi

 # walk through the listing and identify instruments/products/subsets of interest
     for satellite in `cat $filelist | cut -f2 -d '.' | sort -u`
       do
         # set up the product types and subsets that we want for this satellite
         case $satellite in
            GPM )  subsets='AKradars BrazilRadars CONUS DARW KORA KOREA KWAJ Guam Hawaii SanJuanPR Finland AUS-East AUS-West Tasmania'
                   datatypes='1C-R 2A 2B'
                   ;;
           TRMM )  subsets='CONUS DARW KORA KOREA KWAJ'
                   datatypes='1C-R 2A 2B'
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
                 # identify any matching files from manifest, store list in temp file
                 grep $filepre $filelist | grep -v XCAL | grep -v 'TRMM.PR.2A21' \
                  | tee $SATSUBTYPE_TEMP | tee $LOG_FILE
                 if [ -s $SATSUBTYPE_TEMP ]
                   then
                     for thisPPSfile in `cat $SATSUBTYPE_TEMP`
                       do
                             echo "Catalog $thisPPSfile" | tee -a $LOG_FILE
                             # get info needed to catalog and move the file to baseline tree
                             # extract/format the YYYY/MM/DD directory specification for the file
                             YMDdir=`echo $thisPPSfile | cut -f5 -d '.' | cut -f1 -d '-' \
                                   | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
                             # extract the version specification from the filename
                             Version=`echo $thisPPSfile | cut -f 7 -d '.'`
                             # extract the orbit, instrument and algorithm names from the file basename
                             Orbit=`echo $thisPPSfile | cut -f 6 -d '.'`
                             Instrument=`echo $thisPPSfile | cut -f 3 -d '.'`
                             AlgoLong=`echo $thisPPSfile | cut -f 4 -d '.'`
                             # format the product_type column value for the database based on rules
                             echo $AlgoLong | grep -E '(GPROF|XCAL)' > /dev/null
                             if [ $? = 0 ]
                               then
                                 # product type is not cleanly'.' delimited, it is merged with
                                 # algorithm versioning, e.g., .GPROF2014v2-0.
                                 echo $AlgoLong | grep GPROF > /dev/null
                                 if [ $? = 0 ]
                                   then
                                     # just use '2AGPROF' as algorithm name
                                     Algo=2AGPROF
                                   else
                                     # just use '1CRXCAL' as algorithm name
                                     Algo=1CRXCAL
                                 fi
                               else
                                 # apply special cases for TRMM and GPM non-GPROF
                                 case $satellite in
                                   TRMM ) Algo=$AlgoLong    # just use what's given, e.g., '2A25'
                                          if [ "$Version" = "7" ]
                                            then
                                              Version="V0"$Version  # convert to naming standard
                                              # compress file if not already in gzip
                                              gzip -l $thisPPSfile > /dev/null 2>&1
                                              if [ $? = 1 ]
                                                then
                                                  echo "Compressing $thisPPSfile with gzip" \
                                                    | tee -a $LOG_FILE
                                                  gzip $thisPPSfile
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
                                 echo "ERROR: Missing baseline directory $targetDir1 for file $thisPPSfile" \
                                   | tee -a $LOG_FILE
                                 echo "Leaving $thisPPSfile uncataloged and in place." \
                                   | tee -a $LOG_FILE
                               else
                                 targetDir=${targetDir1}/${YMDdir}
                                 mkdir -p -v $targetDir
                                 dupByOrbit=`ls ${targetDir}/*.${Orbit}.*` > /dev/null 2>&1
                                 if [ $? -eq 0 ]
                                   then
                                     echo "New and old files for the same " \
                                          "satellite/orbit/product_type/subset/version found" | tee -a $LOG_FILE
                                     echo "Move the existing file to a "safe" directory:" | tee -a $LOG_FILE
                                     mv -v ${dupByOrbit} /data/tmp/replaced_PPS_files | tee -a $LOG_FILE
                                     # move the new file into the baseline directory
                                     mv -v $thisPPSfile ${targetDir} | tee -a $LOG_FILE
                                     # Update the product filename in the database if different from the old
                                     # name.  Need to extract the old file's basename first, as this is what
                                     # the data table stores as the 'filename' attribute.
                                     replaceBase=${dupByOrbit##*/}
                                     if [ $replaceBase != $thisPPSfile ]
                                       then
                                         echo "UPDATE orbit_subset_product SET filename='${thisPPSfile}' \
WHERE filename='${replaceBase}';" | psql -a -d gpmgv  >> $LOG_FILE 2>&1
                                     fi
                                   else
                                     mv -v $thisPPSfile ${targetDir} | tee -a $LOG_FILE
                                     echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" \
	                                | psql -a -d gpmgv  >> $LOG_FILE 2>&1
                                 fi
                             fi
                     done
                   else
                     echo "No matching files for pattern: $filepre" | tee -a $LOG_FILE
                 fi
             done
         done
     done

echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
