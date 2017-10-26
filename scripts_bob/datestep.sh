#!/bin/sh
#
################################################################################

DATES2DO=/tmp/foo.txt
DATELAST=20160815
today=`date -u +%Y%m%d`
stopdate=`offset_date $today -2`
DATEGAP=`grgdif $stopdate $DATELAST`
if [ `expr $DATEGAP \> 0` = 1 ]
  then
     while [ `expr $DATEGAP \> 0` = 1 ]
       do
         DATELAST=`offset_date $DATELAST 1`
         yymmddNever=`echo $DATELAST`
         echo "No prior attempt of $yymmddNever:" | tee -a $LOG_FILE
         # add this date to the temp file
         echo "$yymmddNever" >> $DATES2DO
         DATEGAP=`grgdif $stopdate $DATELAST`
         echo "" | tee -a $LOG_FILE
     done
  else
    echo "No gaps found in dates processed."
fi

exit 0
