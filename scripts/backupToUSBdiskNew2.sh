#!/bin/sh

# back up the postgres 'gpmgv' database using pg_dump

target=/media/usbdisk
ls $target > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "USB disk off or unmounted.  Exit with failure to do back up."
    exit
fi

target=/media/usbdisk/data/db_backup
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/gpmgvDBdump.gz ]
      then
        mv -v $target/gpmgvDBdump.gz  $target/gpmgvDBdump.old.gz
    fi
    pg_dump -f /data/tmp/gpmgvDBdump gpmgv
    gzip /data/tmp/gpmgvDBdump
    mv -v /data/tmp/gpmgvDBdump.gz $target
  else
    echo "Directory $target not found."
    echo "Exit with failure to do back up."
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
        mv -v $target/swdev.tar  $target/swdev.old.tar
    fi
    tar -cvf  /home/morris/swdev.tar  /home/morris/swdev
    mv -v  /home/morris/swdev.tar  $target
  else
    echo "Directory $target not found."
    echo "Exit with failure to do back up."
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
        mv -v $target/tbird.tar.gz  $target/tbird.old.tar.gz
    fi
    tar -cvf  /home/morris/tbird.tar  /home/morris/Attachments /home/morris/.thunderbird
    gzip /home/morris/tbird.tar
    mv -v  /home/morris/tbird.tar.gz  $target
  else
    echo "Directory $target not found."
    echo "Exit with failure to do back up."
    exit
fi
