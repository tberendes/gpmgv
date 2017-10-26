#!/bin/sh
GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
PR_DIR=${DATA_DIR}/prsubsets
PR_BACK_DIR=/media/usbdisk${PR_DIR}

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/CleanOutKWAJ_CSI_PRfromUSB.${rundate}.log
export rundate
echo "Starting file cleanup run for KWAJ PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

for files2del in `ls ${DATA_DIR}/tmp/CleanOutKWAJ_CSI_PR.files2del.${rundate}.txt`
  do

    # delete the files from the USB backup drive
    target=/media/usbdisk
    ls $target > /dev/null 2>&1
    if [ $? != 0 ]
      then
        echo "USB disk off or unmounted.  Exit without deleting files from backup disk." \
        | tee -a $LOG_FILE
      else
        for thisfile in `cat $files2del`
          do
            prfiledir=`echo $thisfile | cut -f1 -d '|'`
            if [ -s ${PR_BACK_DIR}/${prfiledir} ]
              then
                rm -v ${PR_BACK_DIR}/${prfiledir}  | tee -a $LOG_FILE 2>&1 #DOES NOTHING UNTIL echo IS REMOVED FROM COMMAND
            fi
        done
    fi

done
