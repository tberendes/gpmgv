#!/bin/sh
###########################################################################
#  getPRdataWrapr.sh     Morris/SAIC/GPM GV     August 2006
#
#  Description
#  Wrapper script for cron runs of getPRdata.sh
#
#  Files
#  Logs output to monthly log file getPRdataWrapr.YYMM.log
###########################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

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
