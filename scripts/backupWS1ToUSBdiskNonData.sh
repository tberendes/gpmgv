#!/bin/sh

# This script backups up code areas, database, and GPM documents.

LOG_DIR=/data/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/backupToUSBdiskNew7.${ymd}.log

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do selective backup to USB disk on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


target=/media/usbdisk
ls $target > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "USB disk off or unmounted.  Exit with failure to do back up." \
    | tee -a $LOG_FILE
    exit
fi

echo ""
echo "Back up Thunderbird e-mail? (Y or N):"
read -r domail
if [ "$domail" = 'Y' -o "$domail" = 'y' ]
  then
     echo "" | tee -a $LOG_FILE
     echo " back up e-mail and attachments:" | tee -a $LOG_FILE
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
  else
     if [ "$domail" = 'N' -o "$domail" = 'n' ]
       then
         echo "Skipping T-bird backup." | tee -a $LOG_FILE
       else
         echo "Illegal response: $domail" | tee -a $LOG_FILE
         echo "Quitting on user command." | tee -a $LOG_FILE
         exit
     fi
fi

echo "back up the postgres gpmgv database using pg_dump" | tee -a $LOG_FILE

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

echo "" | tee -a $LOG_FILE
echo " back up the software development area:" | tee -a $LOG_FILE
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

echo "" | tee -a $LOG_FILE
echo " back up the GPM Documents:" | tee -a $LOG_FILE
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

exit
