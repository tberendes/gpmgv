#!/bin/sh
#
################################################################################
#
#  wget_orbdef_GPM.sh     Morris/SAIC/GPM GV     Aug 2016
#
#  DESCRIPTION
#    Retrieves GPM satellite orbit definition files from PPS site:
#
#       arthurhou.eosdis.nasa.gov
#
#    The orbit definition file naming convention is:
#      "GPMCORE.yyyymmdd.hhmmssddd_YYYYMMDD.HHMMSSDDD.001.ORBDEF.txt", where
#
#       GPMCORE - literal characters 'GPMCORE'
#          SSSS - ID of the satellite ('GPM' only for this script)
#      yyyymmdd - year (4-digit), month, and day of the orbit start
#     hhmmssddd - hour, minute, second, and decimal second of orbit start
#      YYYYMMDD - year (4-digit), month, and day of the orbit end
#     HHMMSSDDD - hour, minute, second, and decimal second of orbit end
#    ORBDEF.txt - literal characters 'ORBDEF.txt'
#
#    and they are located on the server arthurhou.eosdis.nasa.gov in the
#    subdirectory gpmdata/geolocation in a year/month/day-specific directory
#    structure.  Downloaded files are stored in the same directory structure
#    under the top level directory GEO_DATA defined in this script.
#
#    Uses the 'wget' utility to mirror the GPMCORE.*.ORBDEF.txt files in the
#    current and prior month's directories only.
#
#  FILES
#    GPMCORE.yyyymmdd.hhmmssddd_YYYYMMDD.HHMMSSDDD.001.ORBDEF.txt
#      - GPM orbit files to be mirrored from PPS ftp site.  Current and prior
#        months' yyyymm is determined by time script is run, and determines the
#        directories YYYY/MM/DD to be mirrored between the PPS and local hosts.
#
#    GEOtoGet
#       - Temporary file listing the 'yyyy/mm' file paths of all the
#         GPMCORE.*.ORBDEF.txt files we want to mirror in the current run.
#
#    GEO_dbtempfile
#       - Temporary file holding appstatus table output from a query.
#
#  LOGS
#    Output for day's script run logged to daily log file wget_orbdef_GPM.YYMMDD.log
#    in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table "appstatus". 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $GEO_DATA, $LOG_DIR directories
#
#  HISTORY
#    Aug 2016 - Morris - Created from wget_GT7_GPM.sh.
#
################################################################################

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/tmp
  else
    DATA_DIR=/data/tmp
fi

export DATA_DIR
echo "DATA_DIR: $DATA_DIR"
GEO_DATA=${DATA_DIR}/geolocation
TMP_DIR=/data/tmp
export TMP_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wget_orbdef_GPM.${rundate}.log
PATH=${PATH}:${BIN_DIR}
USERPASS=kenneth.r.morris@nasa.gov
FIXEDPATH='ftp://arthurhou.pps.eosdis.nasa.gov/gpmdata/geolocation'

umask 0002

# re-usable file to hold output from wget
TEMPFILE=${TMP_DIR}/GEO_tempfile
# listing of all files retrieved in this run
FILES2DO=${TMP_DIR}/GEOtoGet
rm -f $FILES2DO

################################################################################
function extract_orbits() {

infile=$1
outfile=$TMP_DIR/geolocationTemp.txt
rm $outfile

for geofile in ` cat $infile`
  do
    rm $outfile
   # sed command 1: delete 22 header lines of CT file
   # sed command 2: remove trailing space(s) at end of lines
   # sed command 3: replace multiple spaces between values with single space
    sed '
    1,22 d
    s/  *$//
    s/  */|/g' <$geofile | cut -f1,11,13 -d '|' >$outfile

    if [ -s $outfile ]
      then
        orbit=`cat $outfile | cut -f1 -d '|'`

       # convert date/times to database-compatible UTC values, e.g., 
       # "2016-07-30T23:53:52.041" -> "2016-07-30 23:53:52+00"
        foo=`cat $outfile | cut -f2 -d '|' | cut -f1 -d '.' | sed 's/T/ /'`
        start_dtime=${foo}+00
        foo=`cat $outfile | cut -f3 -d '|' | cut -f1 -d '.' | sed 's/T/ /'`
        end_dtime=${foo}+00

       # write values to gpm_orbits table in gpmgv database
        echo "INSERT INTO gpm_orbits( orbit, starttime, endtime ) VALUES \
          ( '${orbit}', '${start_dtime}', '${end_dtime}' );" | psql -a -d gpmgv \
          | tee -a $LOG_FILE 2>&1
    fi
done

return 1
}
################################################################################

today=`date -u +%Y%m%d`
echo "====================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence files on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wget_orbdef_GPM.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

#  Get the date string for two days back by calling offset_date.
ctdate2=`offset_date $today -2 | cut -c1-6`
#  Ditto, for 28 days back
ctdate1=`offset_date $today -28 | cut -c1-6`


# THIS BLOCK IS FOR THE FIRST-TIME RUN TO GRAB ALL THE FILES SINCE LAUNCH,
# LEAVE IT COMMENTED OUT UNLESS RESTARTING FROM SCRATCH
##########################################################################
#DATES2DO=/tmp/foo.txt
#rm $DATES2DO
#DATELAST=20140226
#stopdate=`offset_date $today -3`
#DATEGAP=`grgdif $stopdate $DATELAST`
#if [ `expr $DATEGAP \> 1` = 1 ]
#  then
#     while [ `expr $DATEGAP \> 1` = 1 ]
#       do
#         DATELAST=`offset_date $DATELAST 1`
#         yymmddNever=`echo $DATELAST`
#         echo "No prior attempt of $yymmddNever:" | tee -a $LOG_FILE
#         # add this date to the temp file
#         echo "$yymmddNever" >> $DATES2DO
#         DATEGAP=`grgdif $stopdate $DATELAST`
#         echo "" >> $LOG_FILE
#     done
#  else
#    echo "No gaps found in dates processed."
#fi
#
# THESE TWO LINES WOULD REPLACE THEIR COUNTERPARTS IN THE for LOOP BELOW
#for datepath in `cat $DATES2DO` 
#    yyyymmpath=`echo $datepath | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
#
##########################################################################

# HANDLE EACH YYYY/MM SUBDIRECTORY SEPARATELY, ONE AT A TIME
for datepath in `echo $ctdate1 $ctdate2 | sort -u`
  do
    #  Get the subdirectory on the ftp site under which our month's data are located,
    #  in the format YYYY/MM
    yyyymmpath=`echo $datepath | awk '{print substr($1,1,4)"/"substr($1,5,2)}'`

    echo "Mirroring files under YYYY/MM path $yyyymmpath" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    # make the new year/month-specific directory as required
    mkdir -p -v ${GEO_DATA}/${yyyymmpath} | tee -a $LOG_FILE

    wget -r -nc -np -nH --cut-dirs=4 -o ${TEMPFILE} -P ${GEO_DATA}/${yyyymmpath} -AORBDEF.txt\
         --user=$USERPASS --password=$USERPASS $FIXEDPATH/${yyyymmpath}/

    cat ${TEMPFILE} | grep saved | grep ORBDEF.txt | cut -f2 -d '“' | cut -f1 -d '”' > $FILES2DO
    if [ -s $FILES2DO ]
      then
        ngotten=`cat $FILES2DO | wc -l`
        echo "Got ${ngotten} files." | tee -a $LOG_FILE
        cat $FILES2DO | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "Calling extract_orbits.sh $FILES2DO" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        extract_orbits $FILES2DO | tee -a $LOG_FILE 2>&1
      else
        echo "No files under $FIXEDPATH/${yyyymmpath} retrieved from PPS ftp site." \
            | tee -a $LOG_FILE
    fi
done

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "See log file $LOG_FILE"
exit
