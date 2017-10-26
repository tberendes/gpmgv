#!/bin/sh

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
LOG_FILE=${LOG_DIR}/get_PPS_CS_data.${rundate}.log       # script log file
export LOG_FILE

                     satellite="TRMM"
                     subset="CONUS"
                     thisPPSfilepath="gpmuser/gpmgv/V05/2017/10/02/1C/1C-CS-CONUS.TRMM.TMI.XCAL2017-C.YYYYMMDD-SHHMMSS-EHHMMSS.999999.V05A.HDF5"
                         # extract the file basename and dirname from thisPPSfilepath
                         thisPPSfile=${thisPPSfilepath##*/}
                         thisPPSdir=${thisPPSfilepath%/*}
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
                                 # TRMM files for V05A are now same format as GPM
                                 case $satellite in
                                   TRMM ) prodTypeLong=`echo $thisPPSfile | cut -f 1 -d '.'`
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
                                          Algo=${prodType}${Instrument}  # e.g., '2AKU','2BPRTMI'
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
                                 echo update_CS_dirs.sh  ${satellite}/${Instrument}/${Algo}  ${Version}\
                                   | tee -a $LOG_FILE
                             fi
                             targetDir1=${CS_BASE}/${satellite}/${Instrument}/${Algo}/${Version}/${subset}
                             if [ ! -s $targetDir1 ]
                               then
                                 echo "ERROR: Missing baseline directory $targetDir1 for file $2/$thisPPSfile" \
                                   | tee -a $LOG_FILE
                                 echo "Leaving $2/$thisPPSfile uncataloged and in place." \
                                   | tee -a $LOG_FILE
#                               else
                                 targetDir=${targetDir1}/${YMDdir}
                                 echo mkdir -p -v $targetDir
                                 dupByOrbit=`ls ${targetDir}/*.${Orbit}.*` > /dev/null 2>&1
                                 if [ $? -eq 0 ]
                                   then
                                     echo "New and old files for the same " \
                                          "satellite/orbit/product_type/subset/version found" | tee -a $LOG_FILE
                                     echo "Move the existing file to a "safe" directory:" | tee -a $LOG_FILE
                                     echo mv -v ${dupByOrbit} /data/tmp/replaced_PPS_files | tee -a $LOG_FILE
                                     # move the new file into the baseline directory
                                     echo mv -v $2/$thisPPSfile ${targetDir} | tee -a $LOG_FILE
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
                                     echo mv -v $2/$thisPPSfile ${targetDir} | tee -a $LOG_FILE
                                     echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');"
                                 fi
                             fi
exit
