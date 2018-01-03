#!/bin/sh
LOG_DIR=~/data/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=${LOG_DIR}/copyHectorToDS1.${ymd}.log
THESERVER=ds1-gpmgv.gsfc.nasa.gov

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Copy from hector on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


echo "back up the postgres gpmgv database using pg_dump" | tee -a $LOG_FILE

target=${THESERVER}:/data/gpmgv
cd ~/data
scp -r db_backup $target | tee -a $LOG_FILE 2>&1

echo "" | tee -a $LOG_FILE

cd ~/data/prsubsets
for file in `ls`
  do
    tar -cvf ${file}subsets.tar $file
    ls -al ${file}subsets.tar | tee -a $LOG_FILE 2>&1
    scp ~/data/prsubsets/${file}subsets.tar \
      ${THESERVER}:/data/gpmgv/prsubsets/ | tee -a $LOG_FILE 2>&1
    rm -v ${file}subsets.tar | tee -a $LOG_FILE 2>&1
done

# synch up gv_radar

echo "" | tee -a $LOG_FILE
echo "tar up and copy data/gv_radar by site" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


cd ~/data/gv_radar/defaultQC_in
for site in `ls`
  do
    tar -cvf defGVRADAR_${site}.tar ${site}
    ls -al defGVRADAR_${site}.tar | tee -a $LOG_FILE 2>&1
    scp defGVRADAR_${site}.tar \
      ${THESERVER}:/data/gpmgv/gv_radar/defaultQC_in/ | tee -a $LOG_FILE 2>&1
    rm -v defGVRADAR_${site}.tar | tee -a $LOG_FILE 2>&1
done

cd ~/data/gv_radar/finalQC_in
for site in `ls`
  do
    tar -cvf GVRADAR_${site}.tar ${site}
    ls -al GVRADAR_${site}.tar | tee -a $LOG_FILE 2>&1
    scp GVRADAR_${site}.tar \
      ${THESERVER}:/data/gpmgv/gv_radar/finalQC_in/ | tee -a $LOG_FILE 2>&1
    rm -v GVRADAR_${site}.tar | tee -a $LOG_FILE 2>&1
done

exit
