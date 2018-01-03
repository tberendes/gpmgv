#!/bin/sh

echo "Getting KWAJ CSI files." | tee -a $LOG_FILE
for year in 2008 2009 2010
  do
    for month in 01 02 03 04 05 06 07 08 09 10 11 12
      do
        ndays=`monthdays $year $month`
        case $ndays in
          28 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28' ;;
          29 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29' ;;
          30 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30' ;;
          31 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31' ;;
           * )  ;;
        esac
        for day in `echo $days`
          do
            ctdate=$year$month$day

            #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
            julctdate=`ymd2yd $ctdate`

            #  Get the subdirectory on the ftp site under which our day's data are located,
            #  in the format YYYY/jjj
            jdaydir=`echo $julctdate | awk '{print substr($1,1,4)"/"substr($1,5,3)}'`

            #  Trim date string to use a 2-digit year, as in filename convention
            yymmdd=`echo $ctdate | cut -c 3-8`

            echo "Getting KWAJ CSI PR files for date $yymmdd" | tee -a $LOG_FILE
            echo "" | tee -a $LOG_FILE
        done
    done
done
exit
