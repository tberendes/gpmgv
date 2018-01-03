#!/bin/sh
#
################################################################################

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

SQL_BIN=${BIN_DIR}/catalogKWAJ_UF.sql
loadfile=${DATA_DIR}/tmp/KWAJ_UF_times_2001a.unl

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogKWAJ_UF.${rundate}.log
DB_LOG_FILE=${LOG_DIR}/catalogKWAJ_UF_SQL.log
runtime=`date -u`

umask 0002

# Begin script

rm -v $loadfile
cd /data/gv_radar
for ufile in `ls KWAJ_UF/010*` #`cat /home/morris/Desktop/KWAJ_1CUF_Listing.filtered`
  do
    #yymmstr=`echo $ufile | cut -f3-4 -d'/' | sed 's\/\-\' | cut -f1-2 -d'-'`
    #ddstr=`echo $ufile | cut -f5 -d'/' | cut -c5-6`
    #datestr=`echo ${yymmstr}-${ddstr}`
    datestr=`echo $ufile | cut -f2 -d'/' | awk '{print substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
    timestr=`echo $ufile | cut -f5 -d'.' | awk '{print substr($1,1,2)":"substr($1,3,2)}'`
    echo "KWAJ|1CUF|20${datestr} ${timestr}+00|$ufile" >> $loadfile
done
#exit
if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "\copy radarcatalog FROM '${loadfile}' WITH DELIMITER '|'" \
            | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    echo "" | tee -a $LOG_FILE
fi

exit
