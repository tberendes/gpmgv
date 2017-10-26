#!/bin/sh
#
################################################################################
#
#  extract_daily_predicts.sh     Morris/SAIC/GPM GV     May 2015
#
#  DESCRIPTION
#    Extracts GPM 1-s ground track data for individual calendar days (UTC) from
#    7-day-prediction ground track files retrieved from the PPS ftp site by the
#    parent script wget_GT7_GPM.sh, and stores them in daily ground track files.
#    In normal cases only the first 24h of predictions are extracted from the
#    7-day prediction files, which are produced on a daily basis.  If a gap of
#    more than one day exists in the sequence of 7-day prediction files, then
#    predictions for the "gap" days are extracted from the latest preceding 7
#    day file.  Header lines in the 7-day file are skipped over.
#
#  FILES
#    GTsToGet
#       - Text file listing the full pathnames of all the newly-acquired
#         GT-7.SSSS.yyyymmdd.jjj.txt files we want to process in a run.  If not
#         provided as the argument to this script, then the script instead will
#         walk through all the GT-7 files in the directory PREDICT_DIR defined
#         in this script and look for files with datestamps later than that of
#         the last 1-day predict file's date.  INPUT
#
#    GT-7.SSSS.yyyymmdd.jjj.txt
#      - GT-7 files already retrieved from PPS ftp site.  Date yyyymmdd
#        is first day's worth of the 7 days of 1-s orbital predictions
#        contained in the file.  INPUT
#
#    GPM_1s_subpts.yyyymmdd.txt
#      - File holding 24 hours worth of 1-s orbit track information for date
#        yyyymmdd, as extracted from a GT-7.SSSS.yyyymmdd.jjj.txt file.  OUTPUT
#
#
#  HISTORY
#    May 2015 - Morris - Created from wgetCTdailies.sh.
#
################################################################################

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}

PREDICT_DIR=/data/tmp/ground_track_7day/2015
TARGET_DIR=/data/tmp/daily_predict

DATE1LAST=`ls $TARGET_DIR | tail -1 | cut -f2 -d '.'`  # latest 1-day file
echo "Start date: ${DATE1LAST}"

if [ $# != 1 ] 
  then
    # no listing of newly-downloaded GT-7 files provided, just walk thru directory
    files7day=/data/tmp/GT7files.lis
    ls $PREDICT_DIR/GT-7.GPM.* > $files7day
  else
    # use the list of new GT-7 files provided by caller
    files7day=$1
fi

LAST_FILE=`cat $files7day | head -1`  # initialize "prior" 7-day file
WORKINGDATE=`echo $LAST_FILE | cut -f3 -d '.'`  # date of prior 7-day
echo "First GT7 file to consider: $LAST_FILE"

# walk through the 7-day files and see if there is a gap of more than +1 day
# between their datestamp and the last 1-day file.  If yes, then we need to get
# additional day's predictions for the "gap" from a preceding 7-day file

for file in `cat $files7day`
  do
    thisdate=`echo $file | cut -f3 -d '.'`
    DATEGAP=`grgdif $thisdate $DATE1LAST`
#echo "DATEGAP: $DATEGAP"

    if [ `expr $DATEGAP \> 0` = 1 ]  # only look at 7-day file dates after latest 1-day date
      then
        if [ `expr $DATEGAP \> 1` = 1 ]  # gap > 1 day from last daily file to this 7-day file
          then                           # get "gap" days (up to 6) out of previous prediction file

            while [ `expr $DATEGAP \> 1` = 1 ]
              do
                DATE1LAST=`offset_date $DATE1LAST 1`          # next daily date to attempt
                DATEGAPFROM=`grgdif $DATE1LAST $WORKINGDATE`  # days between desired daily and prior 7-day
#                echo "DATEGAPFROM: $DATEGAPFROM"
                if [ `expr $DATEGAPFROM \< 7` = 1 ]
                  then
                    targetFile=${TARGET_DIR}/GPM_1s_subpts.${DATE1LAST}.txt
                    echo "Extract missing data into $targetFile for $DATE1LAST from $LAST_FILE"
                    daydir=`echo $DATE1LAST | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
#                    echo "Pattern = ${daydir}"
                    cat $LAST_FILE | grep -Ev '[A-S]' | grep T \
                       | sed 's/^  *//' | sed 's/  */,/g' | grep $daydir > $targetFile
                    ls -al $targetFile
                  else
                    echo "No data for $DATE1LAST in $LAST_FILE"
                fi
                DATEGAP=`grgdif $thisdate $DATE1LAST`
            done

        fi
        # if no gap, then get the prediction for the date of the file's datestamp only
        DATE1LAST=$thisdate
        LAST_FILE=$file
        WORKINGDATE=`echo $LAST_FILE | cut -f3 -d '.'`  # date of current 7-day
        daydir=`echo $DATE1LAST | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
        targetFile=${TARGET_DIR}/GPM_1s_subpts.${DATE1LAST}.txt
        echo "Extract data into $targetFile for $DATE1LAST from $LAST_FILE"
        cat $LAST_FILE | grep -Ev '[A-S]' | grep T \
           | sed 's/^  *//' | sed 's/  */,/g' | grep $daydir > $targetFile
        ls -al $targetFile
      else
        echo "Ignoring old GT file: $file"
    fi
done
echo ""
echo "Done:  extract_daily_predicts.sh"

exit
