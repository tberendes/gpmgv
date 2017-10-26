#!/bin/sh

# back up the operational area
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

exit

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 90 days ago, extract year
ymdstart=`offset_date $ymd -90`
ystart=`echo $ymdstart | cut -c1-4`

echo "Start year = $ystart, End year = $yend"

# after 90 days we will no longer try to back up last year's files, 
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

echo ""
#exit

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
            echo "${site}/${area}/${year}:"
            ls -p /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}
#            rsync -rtv \
#              /home/data/gpmgv/gv_radar/finalQC_in/${site}/${area}/${year}/ \
#              /media/usbdisk/data/gv_radar/finalQC_in/${site}/${area}/${year} \
#               | tee -a $LOG_FILE 2>&1
        done
    done
    echo ""
done

exit
