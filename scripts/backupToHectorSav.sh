#!/bin/sh
LOG_DIR=/data/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/backupToHector.${ymd}.log
THESERVER=hector.gsfc.nasa.gov

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do full backup to hector on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


echo "You should first have run CleanOutKWAJ_CSI_PR.sh to clean out KWAJ"
echo "PR subset files for overpasses at excessive range from the GV radar."
echo ""
echo "Has this been done? (Y or N):"
read -r bail
if [ "$bail" != 'Y' -a "$bail" != 'y' ]
  then
     if [ "$bail" != 'N' -a "$bail" != 'n' ]
       then
         echo "Illegal response: $bail" | tee -a $LOG_FILE
     fi
     echo "Quitting on user command." | tee -a $LOG_FILE
     exit
fi


echo "back up the postgres gpmgv database using pg_dump" | tee -a $LOG_FILE

target=${THESERVER}:\~/data/db_backup
ssh ${THESERVER} "ls ~/data/db_backup" | grep gpmgvDBdump.gz > /dev/null 2>&1
if [ $? = 0 ]
  then
echo "Found gpmgvDBdump.gz on ${THESERVER}:\~/data/db_backup" | tee -a $LOG_FILE
#    ssh ${THESERVER} "mv -v ~/data/db_backup/gpmgvDBdump.gz \
#                      ~/data/db_backup/gpmgvDBdump.old.gz" | tee -a $LOG_FILE
#    pg_dump -f /data/tmp/gpmgvDBdump gpmgv | tee -a $LOG_FILE 2>&1
#    gzip /data/tmp/gpmgvDBdump | tee -a $LOG_FILE 2>&1
#    scp /data/tmp/gpmgvDBdump.gz $target | tee -a $LOG_FILE 2>&1
#    rm -v /data/tmp/gpmgvDBdump.gz | tee -a $LOG_FILE 2>&1
  else
    echo "Filepath $target/gpmgvDBdump.gz not found." | tee -a $LOG_FILE
    echo "Exit with failure to do back up." | tee -a $LOG_FILE
    exit
fi

echo "" | tee -a $LOG_FILE
echo " do /data backups with rsync:" | tee -a $LOG_FILE

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -60`
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
    echo "Year to do = $yr2do" | tee -a $LOG_FILE
done

# ignore year in the following directories, for now

rsync -rtvn --ignore-existing /home/data/gpmgv/coincidence_table/CT*archive.* \
     ${THESERVER}:\~/data/coincidence_table | tee -a $LOG_FILE 2>&1

rsync -rtvn --ignore-existing /home/data/gpmgv/mosaicimages/archivedmosaic/ \
      ${THESERVER}:\~/data/mosaicimages/archivedmosaic | tee -a $LOG_FILE 2>&1

rsync -rtvn --ignore-existing --exclude="*.R*" /home/data/gpmgv/netcdf/geo_match/ \
      ${THESERVER}:\~/data/netcdf/geo_match | tee -a $LOG_FILE 2>&1

rsync -rtvn --ignore-existing /home/data/gpmgv/prsubsets/ \
      ${THESERVER}:\~/data/prsubsets | tee -a $LOG_FILE 2>&1

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
            rsync -rtvn --ignore-existing \
                 /home/data/gpmgv/gv_radar/defaultQC_in/${site}/${area}/${year}/ \
                 ${THESERVER}:\~/data/gv_radar/defaultQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
        done
    done
done

for site in `ls /home/data/gpmgv/gv_radar/finalQC_in/`
  do
    if [ $site = 'RGSN' ]
      then
        echo "Skipping /home/data/gpmgv/gv_radar/finalQC_in/${site}" | tee -a $LOG_FILE
        continue
    fi
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
            rsync -rtvn --ignore-existing \
                 /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}/ \
                 ${THESERVER}:\~/data/gv_radar/finalQC_in/${site}/${area}/${year} \
                 | tee -a $LOG_FILE 2>&1
        done
    done
done

exit
