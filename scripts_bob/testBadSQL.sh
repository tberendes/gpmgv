#!/bin/sh
USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR
LOG_FILE=${LOG_DIR}/testBadSQL.log
export LOG_FILE
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
export BIN_DIR
export PATH
SQL_BIN=${BIN_DIR}/badSQLcmd.sql
rm -v $LOG_FILE

################################################################################

# Begin script

if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN" | psql -a -d gpmgv >> $LOG_FILE 2>&1
  else
    echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

echo "################################################################################" >> $LOG_FILE
echo ""
#echo "Log file:"
grep ERROR $LOG_FILE

exit
