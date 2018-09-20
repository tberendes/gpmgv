#!/bin/sh
LOG_DIR=/data/logs
ymd=`date -u +%d%b%y`
LOG_FILE=$LOG_DIR/backup_gpmgv_DB.${ymd}.log

umask 0002

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do gpmgv DB backup on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


echo ""
echo "It wouldn't hurt to run a 'vacuumdb -f -d gpmgv' before dumping the db."
echo ""
echo "Answer Y if yes or to proceed w/o vacuumed DB, N to quit now (Y or N):"
read -r bail
if [ "$bail" != 'Y' -a "$bail" != 'y' ]
  then
     if [ "$bail" != 'N' -a "$bail" != 'n' ]
       then
         echo "Illegal response: $bail" | tee -a $LOG_FILE
     fi
     echo "Quitting on user command." | tee -a $LOG_FILE
     exit
fi

echo "back up the postgres gpmgv database using pg_dump" | tee -a $LOG_FILE

target=/data/db_backup
#ls /data/db_backup/gpmgvDBdump.gz > /dev/null 2>&1
if [ -d $target -a -w $target ]
  then
    echo "Found /data/db_backup" | tee -a $LOG_FILE
    pg_dump -f /data/tmp/gpmgvDBdump.${ymd}.dump gpmgv | tee -a $LOG_FILE 2>&1
    gzip /data/tmp/gpmgvDBdump.${ymd}.dump | tee -a $LOG_FILE 2>&1
    mv -v /data/tmp/gpmgvDBdump.${ymd}.dump.gz /data/db_backup | tee -a $LOG_FILE 2>&1
  else
    echo "Filepath /gpmgvDBdump.gz not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "If errors seen, review log file: $LOG_FILE"

exit
