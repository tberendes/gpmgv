#!/bin/sh
LOG_DIR=/data/gpmgv/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/copyDS1radarToHector.${ymd}.log
THESERVER=hector.gsfc.nasa.gov

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do full backup to hector on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


for site in `ls /data/gpmgv/gv_radar/defaultQC_in/`
  do
    if [ $site != 'KAMX' ]
      then
        rsync -av /data/gpmgv/gv_radar/defaultQC_in/${site}/ \
              ${THESERVER}:\~/data/gpmgv/gv_radar/defaultQC_in/${site} \
              | tee -a $LOG_FILE 2>&1
    fi
done

for site in `ls /data/gpmgv/gv_radar/finalQC_in/`
  do
    if [ $site = 'RGSN' ]
      then
        echo "Skipping /data/gpmgv/gv_radar/finalQC_in/${site}" | tee -a $LOG_FILE
      else
        rsync -av /data/gpmgv/gv_radar/finalQC_in/${site}/ \
              ${THESERVER}:\~/data/gpmgv/gv_radar/finalQC_in/${site} \
              | tee -a $LOG_FILE 2>&1
    fi
done

exit
