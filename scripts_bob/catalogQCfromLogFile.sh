#!/bin/sh

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data/gpmgv
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

SQL_BIN=${BIN_DIR}/catalogQCradar.sql
loadfile=${DATA_DIR}/tmp/finalQC_KxxxMeta.unl

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogQCradar.110204.log
DB_LOG_FILE=${LOG_DIR}/catalogQCradarSQL.log
runtime=`date -u`

umask 0002

################################################################################
function dbfileprep() {

# function formats file metadata into delimited text file, for loading into
# table 'gvradartemp' in 'gpmgv' database.  Takes 3 args: full file pathname,
# radar ID, and name of delimited text file to write output into

type=`echo $1 | cut -f1 -d'/'`
#echo "orig_type = $type"
pathless=`echo $1 | cut -f4 -d'/'`
sitepath=`echo $1 | cut -f1-3 -d'/'`
if [ "$type" = "level_2" ]
  then
     if [ $pathless = "options" ]
       then
         echo "Skipping file $1"
	 return
     fi
     type=`echo $pathless | cut -c1-4`
     year=`echo $1 | cut -f2 -d'/'`
     mmdd=`echo $pathless | cut -f2 -d'.' | cut -c3-6 | awk '{print \
           substr($1,1,2)"-"substr($1,3,2)}'`
     datestr=${year}'-'${mmdd}
  else
     datestr=`echo $1 | cut -f2-3 -d'/' | awk '{print \
              substr($1,1,4)"-"substr($1,6,2)"-"substr($1,8,2)}'`
fi
#echo "datatype = $type"
#echo "datestr = $datestr"
# nominal hour value in filename for 1CUF,1C51,2A54,2A55 runs from 1-24,
# convert to 00:00 to 23:00 for loading in database
case $type in
                1CUF )  dtime=`echo $pathless | cut -f2 -d'.'`
		        dtime=`expr $dtime - 1`
			dtime=${dtime}":00" ;;
  2A53 | 2A54 | 2A55 | 1C51 )  dtime=`echo $pathless | cut -f3 -d'.'`
		        dtime=`expr $dtime - 1`
			dtime=${dtime}":00" ;;
              images )  dtime=`echo $pathless | cut -f2 -d'.' | awk '{print \
                               substr($1,1,2)":"substr($1,3,2)}'` ;;
                   * )  ;;
esac

# add preceding zero to hour if needed.  First cut hh out of hh or hh:mm string
dthr=`echo $dtime | cut -f1 -d':'`
# if ( hh < 12 ) AND ( length_of_hh_string = 1 ) THEN PREPEND '0' to timestring
if [ `expr $dthr \< 10` = 1  -a  ${#dthr} = 1  ]
  then
     dtime='0'$dtime
fi

dtimestr=${datestr}' '${dtime}"+00"
echo "${type}|$2|${dtimestr}|${sitepath}|${pathless}" >> $3
return
}
################################################################################

# Begin script

rm -v $loadfile

while read line
  do
    entry=`echo -e "$line"`
    echo "$entry" | grep "<<<<" > /dev/null 2>&1
    if [ $? = 0 ]
      then
         site=`echo "$entry" | cut -f7 -d ' '`
         echo $site
    fi
    echo "$entry" | grep "\.g" > /dev/null 2>&1
    if [ $? = 0 ]
      then
         echo "$entry"
         dbfileprep $entry $site $loadfile
    fi
done  <$LOG_FILE

exit
