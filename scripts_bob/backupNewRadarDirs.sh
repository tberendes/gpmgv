#!/bin/sh
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/backupToUSBdiskNew6.log  # perpetual log file?

ymd=`date -u +%Y%m%d`
echo "" | tee -a $LOG_FILE
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
years=2007
for yr2do in $years
  do
    echo "Year to do = $yr2do"
done

for site in `ls /home/data/gpmgv/gv_radar/finalQC_in`
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
             if [ ! -d /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} ]
               then
                 mkdir -p /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year}
                 rsync -rtv \
                  /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}/ \
                  /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} \
                  | tee -a $LOG_FILE 2>&1
             fi
        done
    done
done
