#!/bin/sh
LOG_DIR=/data/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/backupToUSBdiskNew6.${ymd}.log

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do full backup to USB disk on $ymd." | tee -a $LOG_FILE
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

echo "" | tee -a $LOG_FILE
echo " do /data backups with rsync:" | tee -a $LOG_FILE

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -30`
ystart=`echo $ymdstart | cut -c1-4`

# after 30 days we will no longer try to back up last year's files, 
# as $ystart will be the current year, the same as $yend
if [ "$ystart" != "$yend" ]
  then
    years="${ystart} ${yend}"
  else
    years=${yend}
fi

echo ""

for yr2do in $years
  do
    echo "Year to do = $yr2do"
done

# ignore year in the following directories, for now
rsync -rtvin --modify-window=3602  /home/data/gpmgv/coincidence_table/ \
     /media/usbdisk/data/coincidence_table | tee -a $LOG_FILE 2>&1

rsync -rtvin --modify-window=3602  /home/data/gpmgv/mosaicimages/archivedmosaic/ \
      /media/usbdisk/data/mosaicimages/archivedmosaic | tee -a $LOG_FILE 2>&1

rsync -rtvin --modify-window=3602  /home/data/gpmgv/prsubsets/ \
      /media/usbdisk/data/prsubsets \
  | tee -a $LOG_FILE 2>&1

# synch up gv_radar for year(s) listed in $years

echo "" | tee -a $LOG_FILE
echo "Back up /home/data/gpmgv/gv_radar" | tee -a $LOG_FILE
echo "Start year = $ystart, End year = $yend" | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE


### THESE WILL FAIL WHEN THE TARGET DIRECTORY FOR ${site}/${area}/${year} DOES
### NOT YET EXIST ON THE USB DISK!!!  WE FIRST CHECK, AND IF DIRECTORY DOESN'T
### EXIST, DO A mkdir -p TO CREATE IT

for site in `ls /home/data/gpmgv/gv_radar/defaultQC_in/`
  do
    for area in `ls /home/data/gpmgv/gv_radar/defaultQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
             if [ -d /home/data/gpmgv/gv_radar/defaultQC_in/${site}/${area}/${year} ]
	     then
	       if [ ! -d /media/usbdisk/data/gv_radar/defaultQC_in/${site}/${area}/${year} ]
                 then
                   mkdir -p /media/usbdisk/data/gv_radar/defaultQC_in/${site}/${area}/${year}
               fi
               rsync -rtvin --modify-window=3602 \
                 /home/data/gpmgv/gv_radar/defaultQC_in/${site}/${area}/${year}/ \
                 /media/usbdisk/data/gv_radar/defaultQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
	     fi
        done
    done
done

for site in `ls /home/data/gpmgv/gv_radar/finalQC_in/`
  do
    for area in `ls /home/data/gpmgv/gv_radar/finalQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
             if [ -d /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year} ]
	     then
	       if [ ! -d /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} ]
                 then
                   mkdir -p /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year}
               fi
               rsync -rtvin  --modify-window=3602 \
                 /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}/ \
                 /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
	     fi
        done
    done
done

exit
