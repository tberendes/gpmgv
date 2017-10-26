#!/bin/sh

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

# temp file listing pathnames of data files to be processed for an iteration of
#   satellite/subset/productType, used in wgetCStypes4date()
SATSUBTYPE_TEMP=${TMP_CS_DATA}/SatSubsetSubtype2do
export SATSUBTYPE_TEMP
rm -f $SATSUBTYPE_TEMP

 declare -i tries=0
 declare -i found=0
 runagain='y'
 foundman='y'
cd /data/gpmgv/tmp/PPS_CS
for manfile in `ls manifest.2014031*.txt`
  do
     # walk through the manifest and identify instruments/products/subsets of interest
 if [ "$foundman" = "y" ]
   then
     # get a sorted, unique list of satellites included in manifest
     for satellite in `cat $manfile | cut -f2 -d '.' | sort -u`
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
                 # identify any matching files from manifest, store list in temp file
                 grep $filepre $manfile | grep -v XCAL | grep -v 'TRMM.PR.2A21' \
                  | tee $SATSUBTYPE_TEMP | tee -a $LOG_FILE
                 if [ -s $SATSUBTYPE_TEMP ]
                   then
                     # use wget to download the file(s) listed in $SATSUBTYPE_TEMP
#                     wget -P $2  --user=$USERPASS --password=$USERPASS -B ${ftpURL} -i $SATSUBTYPE_TEMP

                     # check our success and catalog downloaded file(s) in database
                     for thisPPSfilepath in `cat $SATSUBTYPE_TEMP`
                       do
                         # extract the file basename and dirname from thisPPSfilepath
                         thisPPSfile=${thisPPSfilepath##*/}
                         thisPPSdir=${thisPPSfilepath%/*}
                         # get the file from the PPS ftp site
#                         wget -P $2  --user=$USERPASS --password=$USERPASS \
#                           ftp://${ftpURL}${thisPPSfilepath}
                         # check our success
#                         if [ -s ${TMP_CS_DATA}/$thisPPSfile ]
#                           then
                             echo "Got ${TMP_CS_DATA}/$thisPPSfile" | tee -a $LOG_FILE
                             # get info needed to catalog and move the file to baseline tree
                             # extract the YYYY/MM/DD directory specification for the file
                             YMDdir=`echo $thisPPSdir | cut -f 5-7 -d '/'`
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
                             # move the file into its proper place in the baseline
                             # directory structure.  Update the year/month/day subdirs
                             # for the latter as needed.  Catalog moved files in 'gpmgv'
                             # database table 'orbit_subset_product'
                             targetDir1=${CS_BASE}/${satellite}/${Instrument}/${Algo}/${Version}/${subset}
                             if [ ! -s $targetDir1 ]
                               then
                                 echo "Missing baseline directory $targetDir1 for file ${TMP_CS_DATA}/$thisPPSfile" \
                                   | tee -a $LOG_FILE
                               else
                                 targetDir=${targetDir1}/${YMDdir}
                                 if [ -s ${targetDir}/$thisPPSfile ]
                                   then
	                           echo "INSERT INTO orbit_subset_product VALUES \
('${satellite}',${Orbit},'${Algo}','${YMDdir}','${thisPPSfile}','${subset}','${Version}');" \
	                          | psql -a -d gpmgv
                                 fi
                             fi
                     done
                   else
                     echo "No matching files for pattern: $filepre" | tee -a $LOG_FILE
                 fi
             done
         done
     done
 fi
done
exit
