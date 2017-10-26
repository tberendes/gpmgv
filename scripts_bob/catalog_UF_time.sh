#!/bin/sh
#
################################################################################
#
#   catalog_UF_time.sh     Morris/GPM GV/SAIC   March 2012
#
#   Takes existing 'nominal' datetime values for existing 1CUF product entries
#   in the 'gvradar' table in the 'gpmgv' database and updates them from the
#   rounding to the hour to hour and minute, as given in the filename's hhmm
#   field.  Only operates on UF files with the TRMM GV naming convention, as
#   filtered by the 'radar_id' values between KAMX and KWAJ.  Skips products
#   where the existing nominal value is EPOCH (1970-01-01 00:00:00+00).
#
################################################################################

GV_BASE_DIR=/home/morris/swdev

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi

LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalog_UF_time.${rundate}.log
echo $MACHINE | tee $LOG_FILE
echo "DATA_DIR = $DATA_DIR" | tee -a $LOG_FILE
#exit

LOG_DIR=${DATA_DIR}/logs

unloadfile=${DATA_DIR}/tmp/unload_gvradar_nominal.unl
loadfile=${DATA_DIR}/tmp/db_UF_times.unl

umask 0002

# Begin script

rm -v $loadfile | tee -a $LOG_FILE
rm -v $unloadfile | tee -a $LOG_FILE
echo "DROP TABLE gvradartimeupd;" | psql -a -d gpmgv | tee -a $LOG_FILE
echo "DROP TABLE gvradarnewtimes;" | psql -a -d gpmgv | tee -a $LOG_FILE
date | tee -a $LOG_FILE

echo "select nominal, filename, fileidnum\
 into gvradartimeupd from gvradar where product='1CUF'\
 and radar_id between 'KAMX' and 'KWAJ' and nominal > '1970-01-01 00:00:00+00' order by nominal;
 CREATE INDEX idnumidx ON gvradartimeupd(fileidnum);
 \t \a \o $unloadfile \\\ select nominal at time zone 'UTC', filename, fileidnum\
 from gvradartimeupd;" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1

echo ''
wc -l $unloadfile | tee -a $LOG_FILE
echo ''
date | tee -a $LOG_FILE
echo ''
echo "Processing times..."

while read ufile
  do
    datestr=`echo $ufile | cut -f1 -d' '`
    timestr=`echo $ufile | cut -f1 -d'|' | cut -f2 -d ' '`
    ufname=`echo $ufile | cut -f2 -d'|'`
    uftime=`echo $ufname | cut -f5 -d '.' | awk '{print substr($1,1,2)":"substr($1,3,2)":00+00"}'`
    fileidnum=`echo $ufile | cut -f3 -d'|'`
    #echo $ufile
    datetime="${datestr} ${uftime}"
    echo "${datetime}|${datestr} ${timestr}+00|${ufname}|${fileidnum}" >> $loadfile
done < $unloadfile

echo "Done."
echo ''
date | tee -a $LOG_FILE

echo ''
echo "select nominal as newnominal, nominal as oldnominal, filename, fileidnum\
 into gvradarnewtimes from gvradartimeupd limit 1;\
 CREATE UNIQUE INDEX idnumidxnew ON gvradarnewtimes(fileidnum);
 delete from gvradarnewtimes;" | psql -a -d gpmgv

#exit
if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Update gvradar times in database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
#cat $loadfile
    echo "\copy gvradarnewtimes from '$loadfile' with delimiter '|'" \
            | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    echo "select max(newnominal-oldnominal) from gvradarnewtimes;"\
         | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    echo "update gvradar set nominal = (select newnominal from gvradarnewtimes\
         where gvradar.fileidnum=gvradarnewtimes.fileidnum) WHERE EXISTS\
        (select fileidnum from gvradarnewtimes where gvradar.fileidnum=gvradarnewtimes.fileidnum);"\
         | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
#    echo "select nominal at time zone 'UTC', filename, fileidnum from gvradar where product='1CUF'\
# and radar_id between 'KAMX' and 'KWAJ' and nominal > '1970-01-01 00:00:00+00' order by nominal limit 45;"\
#         | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
fi

echo ''
date | tee -a $LOG_FILE
exit
