#!/bin/sh
USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

TMP_DIR=${DATA_DIR}/tmp
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogQCradarFIX.${rundate}.log
runtime=`date -u`

years=2013

for Kxxx in `ls $QCDATADIR`
#for Kxxx in KTLH              # for testing, just do one site
  do
    echo "" | tee -a $LOG_FILE
    echo "<<<< Processing received files for site $Kxxx >>>>"\
      | tee -a $LOG_FILE

    cd $QCDATADIR/$Kxxx

# List the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

    for yr2do in $years
      do
        # MADE THESE LISTING FILES YEAR-SPECIFIC SO THAT WHEN WE QUIT LISTING
        # THE PRIOR YEAR WE DON'T GET ALL LAST YEAR'S FILES AS "NEW"

        # This file will hold a listing of files in tree at time of this run:
        tmpfile=${TMP_DIR}/ls${Kxxx}final_${yr2do}.new

        # This file holds the listing of files in tree at time of prior run:
        tmpfileold=${TMP_DIR}/ls${Kxxx}final_${yr2do}.old

        # This file will hold the 'diff tmpfile tmpfileold' command output:
        tmpfilediff=${TMP_DIR}/ls${Kxxx}final_${yr2do}.diff

        # Move last run's tmpfile (if any) to be the 'old' file
        if [ -f $tmpfile ]
          then
            echo ""
	    cp -fv $tmpfileold $tmpfile | tee -a $LOG_FILE 2>&1
	    echo "" | tee -a $LOG_FILE
        fi
     done
done

exit
