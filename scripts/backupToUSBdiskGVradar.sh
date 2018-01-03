#!/bin/sh
LOG_DIR=/data/logs
LOG_FILE=$LOG_DIR/backupToUSBdiskGVradar.log  # perpetual log file?

ymd=`date -u +%Y%m%d`
echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do initial gv_radar backup to USB disk on $ymd." | tee -a $LOG_FILE
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


for site in `ls /home/data/gpmgv/gv_radar/finalQC_in`
  do
#site="KWAJ"
    for area in `ls /home/data/gpmgv/gv_radar/finalQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in `ls /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}`
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
