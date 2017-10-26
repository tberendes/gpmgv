#!/bin/sh
#
################################################################################
#
#  archiveCTMonthly.sh     Morris/SAIC/GPM GV     September 2006
#
#  DESCRIPTION
#    Create a tar file of all CT.yymmdd.6 and CT.yymmdd.unl files for a month
#    and remove the individual files from the coincidence_table directory.  The
#    month to be archived is the month prior to the current calendar month.
#
#  FILES
#    CTYYMMArchive.tar.gz - (output) tar archive file holding all daily CT
#    files for month 'YYMM'.  All CT.YYMMDD.6 and CT/YYMMDD.unl files for
#    MM=currentmonth-1 are tarred up and then removed from the
#    coincidence_table directory.
#
#  LOGS
#    Output from this script is appended to file 'archiveCTMonthly.log'
#    in /data/logs subdirectory.
#
#  HISTORY
#    July 2010, Morris/SAIC/GPM GV - Modified file paths for use on ds1-gpmgv.
#    July 2011, Morris/SAIC/GPM GV - Modified to handle PPS CT files with the
#                                    CT.yyyymmdd.7 naming convention.
#    August 2014, Morris/SAIC/GPM GV - Changed tar flags from 'avf' to 'rvf' to
#                                      work under CENTOS on ds1-gpmgv.
#                                    - Changed LOG_DIR to /data/logs, no longer
#                                      under DATA_DIR
#
################################################################################

DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_table
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/archiveCTMonthly.log

umask 0002

ymd=`date -u +%Y%m%d`
echo "===================================================" | tee -a $LOG_FILE
echo " Archive CT.yymmdd.* files for month-1 on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

yrnow=`expr $ymd / 10000`
monnow=`expr \( $ymd % 10000 \) / 100`

case $monnow in
1) yr2log=`expr $yrnow - 1`; mon2log=12 ;;
*) yr2log=$yrnow ; mon2log=`expr $monnow - 1` ;;
esac

yy=`echo $yr2log | cut -c3-4`

case $mon2log in
10|11|12) filepat=$yy$mon2log ;;
*) filepat=$yy'0'$mon2log ;;
esac

#echo "$ymd $yr2log $mon2log $filepat" | tee -a $LOG_FILE

cd $CT_DATA
tarfile=${CT_DATA}/CT${filepat}archive.tar

ls *.${filepat}*.* > /dev/null 2>&1
if [ $? = 0 ]
  then
    echo "" | tee -a $LOG_FILE
    echo "files to archive into $tarfile:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    tar -cvf $tarfile CT.${filepat}*.* | tee -a $LOG_FILE 2>&1
    tar -rvf $tarfile CT.20${filepat}*.* | tee -a $LOG_FILE 2>&1
    gzip $tarfile
    echo "" | tee -a $LOG_FILE
# LET'S MAKE SURE WE ARE SAFELY TARCHIVING ALL THE CT FILES BEFORE DELETING
#    rm -v CT.${filepat}*.* | tee -a $LOG_FILE 2>&1
#    rm -v CT.20${filepat}*.* | tee -a $LOG_FILE 2>&1
  else
    echo "No CT files archived for YYMM = ${filepat}" | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
