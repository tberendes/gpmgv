#!/bin/sh
################################################################################
#
#  catalogQCradar.sh     Morris/SAIC/GPM GV     October 2006
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the /data/gv_radar/finalQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradar'.
#
#  FILES
#   lsKXXXfinal.new  (output; listing of current file pathnames under directory
#                     /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXXfinal.old  (output; prior listing of file pathnames under directory
#                     /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXX.diff  (output; difference between lsKXXX.new and lsKXXX.old
#                 files; XXX varies by radar site)
#   finalQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' (temporarily) and 'gvradar' (permanently)
#    tables in 'gpmgv' database.  Logic is contained in SQL commands in file
#    catalogQCradar.sql, run in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalogQCradar.YYMMDD.log in /data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', SELECT/INSERT privileges on table 'gvradar', and
#    SELECT/INSERT/DELETE privileges on table 'gvradartemp'.  Utility
#    'psql' must be in user's $PATH.
#
################################################################################

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs

unloadfile=${DATA_DIR}/tmp/fix2A23nominal_in_DB.unl

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/fix2A23nominal_in_DB.${rundate}.log
runtime=`date -u`

umask 0002

echo "=====================================================" | tee $LOG_FILE
echo " Fix nominal of 2A23 final QC radar files in DB as of " | tee -a $LOG_FILE
echo "        $runtime" | tee -a $LOG_FILE
echo "-----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


################################################################################
# Begin script

rm -v $unloadfile

#echo "\t \a \f '|' \o $unloadfile \\\ select nominal at time zone 'UTC', filename from gvradar \
# where product = '2A53' and radar_id = 'KTBW';" | psql -q gpmgv | tee -a $LOG_FILE 2>&1
echo "\t \a \f '|' \o $unloadfile \\\ select filename from gvradar \
 where product = '2A53' and radar_id < 'KLCH';" \
 | psql -q gpmgv | tee -a $LOG_FILE 2>&1
 
if [ ! -s  $unloadfile]
  then
    echo "No cases in control file $unloadfile, exiting."| tee -a $LOG_FILE
    exit 0
fi


#for dateandfile in `cat $unloadfile`
for pathless in `cat $unloadfile`
  do
#     olddtime=`echo $dateandfile  | cut -f1 -d'|'`
#     pathless=`echo $dateandfile  | cut -f2 -d'|'`
     type=`echo $pathless | cut -c1-4`
     yymmdd=`echo $pathless | cut -f2 -d'.' | awk '{print \
           substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
     datestr='20'${yymmdd}
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
echo "update gvradar set nominal = '${dtimestr}' \
 where filename = '${pathless}';" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1

done


echo "" | tee -a $LOG_FILE
echo "Script complete, exiting." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
exit
