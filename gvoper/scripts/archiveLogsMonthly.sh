#!/bin/sh
#
################################################################################
#
#  archiveLogsMonthly.sh     Morris/SAIC/GPM GV     September 2006
#
#  DESCRIPTION
#    Create a tar file of all log files for a month and remove the individual
#    log files from the 'logs' and 'logs/meta_logs' subdirectories.  The
#    month to be archived is two months prior to the current calendar month.
#
#  FILES
#    logsYYMM.tar.gz - (output) tar archive file holding all log files for month
#    'YYMM'.  All daily/monthly log files for MM=currentmonth-2 are tarred
#    up and then removed from the main log directory.
#
#    meta_logsYYMM.tar.gz - (output) tar archive file holding all meta_log
#    files for month 'YYMM'.  All daily/monthly log files for MM=currentmonth-2
#    are tarred up and then removed from the meta_logs subdirectory.
#
#  LOGS
#    Output from this script is appended to file 'archiveLogsMonthly.log'
#    in ${LOG_DIR} subdirectory.
#
#  HISTORY
#    July 2010, Morris/SAIC/GPM GV - Modified file paths for use on ds1-gpmgv.
#    August 2014, Morris/SAIC/GPM GV - Changed LOG_DIR to /data/logs.
#
################################################################################

LOG_DIR=/data/logs
LOG_DIR_META=${LOG_DIR}/meta_logs
LOG_ARCHIVE=${LOG_DIR}/archived
LOG_FILE=${LOG_DIR}/archiveLogsMonthly.log
umask 0002

ymd=`date -u +%Y%m%d`
echo "===================================================" | tee -a $LOG_FILE
echo " Archive all log files for month-2 on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

yrnow=`expr $ymd / 10000`
monnow=`expr \( $ymd % 10000 \) / 100`

case $monnow in
1) yr2log=`expr $yrnow - 1` ; mon2log=11 ;;
2) yr2log=`expr $yrnow - 1` ; mon2log=12 ;;
*) yr2log=$yrnow ; mon2log=`expr $monnow - 2` ;;
esac

yy=`echo $yr2log | cut -c3-4`

case $mon2log in
10|11|12) filepat=$yy$mon2log ;;
*) filepat=$yy'0'$mon2log ;;
esac

#echo "$ymd $yr2log $mon2log $filepat" | tee -a $LOG_FILE

cd $LOG_DIR
tarfile=${LOG_ARCHIVE}/logs${filepat}.tar

ls *.${filepat}*.log > /dev/null 2>&1
if [ $? = 0 ]
  then
    echo "" | tee -a $LOG_FILE
    echo "files to archive into $tarfile:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    tar -cvf $tarfile *.${filepat}*.log | tee -a $LOG_FILE 2>&1
    gzip $tarfile
    echo "" | tee -a $LOG_FILE
    rm -v *.${filepat}*.log | tee -a $LOG_FILE 2>&1
  else
    echo "No log files archived for YYMM = ${filepat}" | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Archiving files from logs/meta_logs directory:" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

cd $LOG_DIR_META
tarfile=${LOG_ARCHIVE}/meta_logs${filepat}.tar

ls *.${filepat}*.log > /dev/null 2>&1
if [ $? = 0 ]
  then
    echo "" | tee -a $LOG_FILE
    echo "files to archive into $tarfile:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    tar -cvf $tarfile *.${filepat}*.log | tee -a $LOG_FILE 2>&1
    gzip $tarfile
    echo "" | tee -a $LOG_FILE
    rm -v *.${filepat}*.log | tee -a $LOG_FILE 2>&1
  else
    echo "No meta_log files archived for YYMM = ${filepat}" | tee -a $LOG_FILE
fi
echo "" | tee -a $LOG_FILE

exit
