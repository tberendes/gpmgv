#!/bin/sh
################################################################################
#
#  RidgeMosaicAllMeta.sh     Morris/SAIC/GPM GV     August 2006
#
#  DESCRIPTION
#    The new filenames and their modification datetime values are written into
#    the PostGRESQL database 'gpmgv' table 'heldmosaic', to facilitate later
#    time matchup to the TRMM Coincidence Table data in table 'ct_temp'.
#
#  FILES
#    YYYY-Mon-DD_HH:MM.gif - Renamed latest.gif file, with date/time derived
#                            from file modification time.
#                     
#  DATABASE
#    Loads data into 'heldmosaic' table in 'gpmgv' database in PostGRESQL via
#    call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    wgetRidgeMosaic.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', and INSERT privilege on table "heldmosaic".  Utility
#    'psql' must be in user's $PATH.
#    - User must have write privileges in $MOSAIC_DATA, $LOG_DIR directories
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
MOSAIC_BASE_DATA=${DATA_DIR}/mosaicimages
MOSAIC_DATA_HOLD=${MOSAIC_BASE_DATA}/holding
MOSAIC_DATA=${MOSAIC_BASE_DATA}/www.srh.noaa.gov/ridge/Conus/RadarImg
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wgetRidgeMosaic.${rundate}.log
runtime=`date -u`

echo "===================================================" | tee -a $LOG_FILE
echo " Attempting download of Ridge mosaic file on $runtime." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

cd ${MOSAIC_BASE_DATA}

# Directory $MOSAIC_DATA will not exist 1st time, so skip check in this case.
if [ -d ${MOSAIC_DATA} ]
  then
     numfound=`ls ${MOSAIC_DATA}/latest*.* | wc -l`
     if [ `expr $numfound \> 1` = 1 ]
       then
          echo "$numfound leftover latest.gif file(s) found in" \
            | tee -a $LOG_FILE
          echo "directory ${MOSAIC_DATA}" | tee -a $LOG_FILE
          echo "at beginning of script run, deleting all:" | tee -a $LOG_FILE
          rm -fv ${MOSAIC_DATA}/latest*.*  | tee -a $LOG_FILE
          echo "" | tee -a $LOG_FILE
     fi
fi

# do the download

/usr/bin/wget --mirror -P ${MOSAIC_BASE_DATA} \
   http://www.srh.noaa.gov/ridge/Conus/RadarImg/latest.gif

numfound=`ls ${MOSAIC_DATA}/latest*.* | wc -l`

if [ `expr $numfound = 1` = 1 ]
  then
     # have one and only one latest.gif file in download, rename, check, and
     # copy to holding directory if new data time
     time=`ls -l --time-style='+%Y-%m-%d %H:%M' ${MOSAIC_DATA} \
       | sed 's/  */ /g' | cut -f 6-7 -d ' ' | awk 'NR==2 {print $1, $2}'`
     name=`echo ${time} | awk '{print $1"_"$2".gif"}'`
     echo "time, name = $time , $name"
     if [ -s ${MOSAIC_DATA_HOLD}/${name} ]
       then
          echo "Already have ${name}, skipping."  | tee -a $LOG_FILE
       else
          echo "Copying latest.gif to:" | tee -a $LOG_FILE
          echo "  ${MOSAIC_DATA_HOLD}/${name}"  | tee -a $LOG_FILE
          cp ${MOSAIC_DATA}/latest.gif ${MOSAIC_DATA_HOLD}/${name}
          echo "Copying metadata to test database:"  | tee -a $LOG_FILE
          echo "insert into heldmosaic values( '$time', '$name' );" \
            |  psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
     fi
  else
     echo "No latest.gif file in ${MOSAIC_DATA}," | tee -a $LOG_FILE
     echo "download failed." | tee -a $LOG_FILE
fi

echo "===================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
