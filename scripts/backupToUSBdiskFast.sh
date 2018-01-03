#!/bin/sh
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/backupToUSBdisk.log  # perpetual log file?

ymd=`date -u +%Y%m%d`
echo "" | tee -a $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do full backup to USB disk on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "NOTE: No backup of the /data/gv_radar area is being performed."
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
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

# back up the software development area
target=/media/usbdisk/swdev
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/swdev.tar ]
      then
        mv -v $target/swdev.tar  $target/swdev.old.tar | tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /home/morris/swdev.tar  /home/morris/swdev | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/swdev.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
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
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

# back up e-mail and attachments
target=/media/usbdisk/morrismail
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/tbird.tar.gz ]
      then
        mv -v $target/tbird.tar.gz  $target/tbird.old.tar.gz \
	| tee -a $LOG_FILE 2>&1
    fi
    tar -cvf  /home/morris/tbird.tar  /home/morris/Attachments \
              /home/morris/.thunderbird | tee -a $LOG_FILE 2>&1
    gzip /home/morris/tbird.tar | tee -a $LOG_FILE 2>&1
    mv -v  /home/morris/tbird.tar.gz  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

# do /data backups with rsync

rsync -rtv  /home/data/gpmgv/coincidence_table/ \
     /media/usbdisk/data/coincidence_table | tee -a $LOG_FILE 2>&1

rsync -rtv  /home/data/gpmgv/mosaicimages/archivedmosaic/ \
      /media/usbdisk/data/mosaicimages/archivedmosaic | tee -a $LOG_FILE 2>&1

exit
