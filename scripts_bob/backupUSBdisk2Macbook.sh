#!/bin/sh
MYDIR=/Users/krmorri1/Documents/GPM
LOG_DIR=${MYDIR}/data/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/backupUSBdisk2Macbook.${ymd}.log

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do backup of USB disk on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

fromdisk=/Volumes/EDGE_DISKGO
ls $fromdisk > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "USB disk off or unmounted.  Exit with failure to do back up." \
    | tee -a $LOG_FILE
    exit
fi

echo "back up the postgres gpmgv database dump files" | tee -a $LOG_FILE

target=${MYDIR}/data/db_backup
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    cp -v ${fromdisk}/data/db_backup/gpmgvDBdump.old.gz  $target | tee -a $LOG_FILE 2>&1
    cp -v ${fromdisk}/data/db_backup/gpmgvDBdump.gz  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo " back up the software development area:" | tee -a $LOG_FILE
target=${MYDIR}/swdev
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    cp -v  ${fromdisk}/swdev/swdev.old.tar  $target | tee -a $LOG_FILE 2>&1
    cp -v  ${fromdisk}/swdev/swdev.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo "back up the operational area:" | tee -a $LOG_FILE
target=${MYDIR}/gvoper
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    cp -v  ${fromdisk}/gvoper/gvoperBak.old.tar  $target | tee -a $LOG_FILE 2>&1
    cp -v  ${fromdisk}/gvoper/gvoperBak.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi
cd $dir_orig

echo "" | tee -a $LOG_FILE
echo " back up the GPM Documents:" | tee -a $LOG_FILE
target=${MYDIR}/gpm_docs
mkdir -p $target
ls $target > /dev/null 2>&1
if [ $? = 0 ]
  then
    cp -v  ${fromdisk}/gpm_docs/gpm_docs.old.tar  $target | tee -a $LOG_FILE 2>&1
    cp -v  ${fromdisk}/gpm_docs/gpm_docs.tar  $target | tee -a $LOG_FILE 2>&1
  else
    echo "Directory $target not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
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
# somehow there is a one-hour-later offset between file times on the USB and
# those on the hard drive, so set modify-window to one hour, plus 2 seconds
# for the FAT vs. Linux hard disk format
rsync -rtvn --modify-window=3602  ${fromdisk}/data/coincidence_table/ \
     ${MYDIR}/data/coincidence_table | tee -a $LOG_FILE 2>&1

rsync -rtvn --modify-window=3602  ${fromdisk}/data/mosaicimages/archivedmosaic/ \
      ${MYDIR}/data/mosaicimages/archivedmosaic | tee -a $LOG_FILE 2>&1

rsync -rtvn --modify-window=3602  ${fromdisk}/data/prsubsets/ \
      ${MYDIR}/data/prsubsets | tee -a $LOG_FILE 2>&1

# synch up gv_radar for year(s) listed in $years

echo "" | tee -a $LOG_FILE
echo "Back up ${fromdisk}/data/gv_radar" | tee -a $LOG_FILE
echo "Start year = $ystart, End year = $yend" | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE


### THESE WILL FAIL WHEN THE TARGET DIRECTORY FOR ${site}/${area}/${year} DOES
### NOT YET EXIST ON THE USB DISK!!!  WE FIRST CHECK, AND IF DIRECTORY DOESN'T
### EXIST, DO A mkdir -p TO CREATE IT

for site in `ls ${fromdisk}/data/gv_radar/defaultQC_in/`
  do
    for area in `ls ${fromdisk}/data/gv_radar/defaultQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
             if [ -d ${fromdisk}/data/gv_radar/defaultQC_in/${site}/${area}/${year} ]
             then
               if [ ! -d ${MYDIR}/data/gv_radar/defaultQC_in/${site}/${area}/${year} ]
                 then
                   mkdir -p ${MYDIR}/data/gv_radar/defaultQC_in/${site}/${area}/${year}
               fi
               rsync -rtvn --modify-window=3602 \
                 ${fromdisk}/data/gv_radar/defaultQC_in/${site}/${area}/${year}/ \
                 ${MYDIR}/data/gv_radar/defaultQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
             fi
        done
    done
done

for site in `ls ${fromdisk}/data/gv_radar/finalQC_in/`
  do
    for area in `ls ${fromdisk}/data/gv_radar/finalQC_in/${site}`
      do
        echo ${area} | grep "log_${site}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        for year in $years
          do
             if [ -d ${fromdisk}/data/gv_radar/finalQC_in/${site}/${area}/${year} ]
             then
               if [ ! -d ${MYDIR}/data/gv_radar/finalQC_in/${site}/${area}/${year} ]
                 then
                   mkdir -p ${MYDIR}/data/gv_radar/finalQC_in/${site}/${area}/${year}
               fi
               rsync -rtvn --modify-window=3602 \
                 ${fromdisk}/data/gv_radar/finalQC_in/${site}/${area}/${year}/ \
                 ${MYDIR}/data/gv_radar/finalQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
             fi
        done
    done
done

exit
