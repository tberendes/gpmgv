#!/bin/sh

# back up the postgres 'gpmgv' database using pg_dump

target=/media/usbdisk/data/db_backup
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
    echo "USB disk off, unmounted or /data/archived_mosaic_images dir not found."
    echo "Exit with failure to do back up."
    exit
fi

# back up the coincident NWS radar mosiacs
target=/media/usbdisk/data/archived_mosaic_images
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    if [ -s $target/archived.tar ]
      then
        mv -v $target/archived.tar  $target/archived.old.tar
    fi
    tar -cvf $target/archived.tar /data/mosaicimages/archivedmosaic
    #mv -v /data/mosaicimages/archived.tar $target
  else
    echo "USB disk off, unmounted or /data/archived_mosaic_images dir not found."
    echo "Exit with failure to do back up."
    exit
fi

# back up the software development area
target=/media/usbdisk/swdev
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
    echo "USB disk off, unmounted or /swdev directory not found."
    echo "Exit with failure to do back up."
    exit
fi
