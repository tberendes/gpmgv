#!/bin/sh
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/backupToUSBdisk.log  # perpetual log file?

ymd=`date -u +%Y%m%d`
echo "" | tee -a $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "     Do partial backup to USB disk on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "NOTE: No backup of the /data or Mail area is being performed."
# back up the postgres 'gpmgv' database using pg_dump

target=/media/usbdisk
ls $target > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "USB disk off or unmounted.  Exit with failure to do back up." \
    | tee -a $LOG_FILE
    exit
fi

target=/media/usbdisk/data/db_backup
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gpmgvDBdump.gz ]
      then
        mv -v $target/gpmgvDBdump.gz  $target/gpmgvDBdump.old.gz \
         | tee -a $LOG_FILE
    fi
    pg_dump -f /data/tmp/gpmgvDBdump gpmgv | tee -a $LOG_FILE 2>&1
    gzip /data/tmp/gpmgvDBdump | tee -a $LOG_FILE 2>&1
    mv -v /data/tmp/gpmgvDBdump.gz $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do DB back up." | tee -a $LOG_FILE
    exit
fi

# back up the software development area as a preserved snapshot
target=/media/usbdisk/swdev
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    tar -cvf  /home/morris/swdev.${ymd}.tar  /home/morris/swdev | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/swdev.${ymd}.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do swdev back up." | tee -a $LOG_FILE
    exit
fi

# back up the GPM Documents
target=/media/usbdisk/gpm_docs
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gpm_docs.tar ]
      then
        mv -v $target/gpm_docs.tar  $target/gpm_docs.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /home/morris/gpm_docs.tar  /home/morris/GPM_Docs | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/gpm_docs.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do gpm_docs back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo "back up the operational area:" | tee -a $LOG_FILE
dir_orig=`pwd`
cd /home/gvoper
target=/media/usbdisk/gvoper
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gvoperBak.tar ]
      then
        mv -v $target/gvoperBak.tar  $target/gvoperBak.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /tmp/gvoperBak.tar  appdata bin idl scripts | tee -a $LOG_FILE 2>&1
    mv -v  /tmp/gvoperBak.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi
cd $dir_orig

exit
