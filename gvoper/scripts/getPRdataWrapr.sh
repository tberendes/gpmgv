#!/bin/sh
###########################################################################
#  getPRdataWrapr.sh     Morris/SAIC/GPM GV     August 2006
#
#  Description
#  Wrapper script for cron runs of getPRdata.sh
#
#  Files
#  Logs output to monthly log file getPRdataWrapr.YYMM.log
#
#  HISTORY
#    08/26/2014 - Morris, SAIC, GPM GV
#    - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
#
###########################################################################

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
LOG_DIR=/data/logs
BIN_DIR=${GV_BASE_DIR}/scripts

umask 0002

logdate=`date -u +%y%m%d`
logmon=`date -u +%y%m`
LOG_FILE=${LOG_DIR}/getPRdataWrapr.${logmon}.log
echo "getPRdataWrapr.sh log for `date -u +%Y%m%d`" >> $LOG_FILE

if [ -x ${BIN_DIR}/getPRdata.sh ]
  then
    ${BIN_DIR}/getPRdata.sh > /dev/null 2>&1
    echo "See daily log file getPRdata.${logdate}.log in $LOG_DIR" >> $LOG_FILE
  else
    echo "${BIN_DIR}/getPRdata.sh not found or not executable!!" >> $LOG_FILE
fi

echo "" >> $LOG_FILE

exit
