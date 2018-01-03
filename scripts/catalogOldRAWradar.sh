#!/bin/sh
################################################################################
#
#  catalogOldRAWradar.sh     Morris/SAIC/GPM GV     Feb. 2007
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the $DATA_DIR/gv_radar/defaultQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'rawradar'.
#
#  FILES
#   lsKXXXdefault.lis  (output; listing of current file pathnames in directory
#                     $DATA_DIR/gv_radar/defaultQC_in; XXX varies by radar site)
#   defaultQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' (temporarily) and 'rawradar' (permanently)
#    tables in 'gpmgv' database.  Logic is contained in SQL commands in file
#    catalogOldRAWradar.sql, run in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalogOldRAWradar.YYMMDD.log in ${DATA_DIR}/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', SELECT/INSERT privileges on table 'rawradar', and
#    SELECT/INSERT/DELETE privileges on table 'gvradartemp'.  Utility
#    'psql' must be in user's $PATH.
#
#  HISTORY
#    06/18/2012, Morris, GPM GV
#    - Added for loop over 'years' and calculation of years to do.
#    - Added automatic configuration of GV_BASE_DIR and DATA_DIR based on user
#      and machine IDs.  Modified Postgresql process count error messages.
#    - Added check to wait until catalogQCradar.sh is done, to prevent database
#      access conflict with gvradartemp table.
#    08/29/2012, Morris, GPM GV
#    - Added logic to dbfileprep() 1CUF case to handle new Dual-pol file naming
#      convention, ignore 'images' type, and do cursory filename pattern
#      checking on each type.
#    08/30/2013, Morris, GPM GV
#    - Created from catalogRAWradar.sh, modified to look at all files for a
#      specific year (and optional month or monthday) and catalog those not
#      already cataloged in the database.  Requires one argument in the format
#      YYYY, YYYY/MM, YYYY/MMD (1st digit of 2-digit day of month), or YYYY/MMDD
#      that defines the date subdirectory(ies) of the files to be cataloged.
#      The SQL command file catalogOldRAWradar.sql determines what is and isn't
#      already cataloged -- this script prepares the metadata file to be loaded
#      to the temporary table in the database and calls 'psql gpmgv' to run the
#      SQL commands.
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
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac

LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${LOG_DIR}/catalogOldRAWradar.${rundate}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     echo "Argument must be date in the format YYYY, YYYY/MM, or YYYY/MMDD."
     exit 1
fi

export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

RAWDATADIR=${DATA_DIR}/gv_radar/defaultQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
TMP_DIR=${DATA_DIR}/tmp

SQL_BIN=${BIN_DIR}/catalogOldRAWradar.sql
loadfile=${TMP_DIR}/defaultQC_OldKxxxMeta.unl

LOG_FILE=${LOG_DIR}/catalogOldRAWradar.${rundate}.log
DB_LOG_FILE=${LOG_DIR}/catalogOldRAWradarSQL.log
runtime=`date -u`

umask 0002

echo "=====================================================" | tee $LOG_FILE
echo " Catalog specified TRMM GVS default QC radar files " | tee -a $LOG_FILE
echo "-----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 5 ]
  then
    echo "Message from catalogOldRAWradar.sh cron job on ${runtime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 5 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 5." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications


catqcproc=`ps -ef | grep catalogQCradar | grep -v grep | wc -l`
if [ ${catqcproc} -gt 0 ]
  then
    echo "Waiting 5 minutes for catalogQCradar to finish." | tee -a $LOG_FILE
    declare -i tries=0
    waitforqc=1
    while [ ${waitforqc} -eq 1 ]
      do
        tries=tries+1
        if [ $tries -eq 6 ]
          then
            echo "Too many tries, quitting." | tee -a $LOG_FILE
            exit 1
        fi
        echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
        sleep 300
        catqcproc=`ps -ef | grep catalogQCradar | grep -v grep | wc -l`
        if [ ${catqcproc} -eq 0 ]
          then
            waitforqc=0
        fi
    done
fi


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
                1CUF )  echo $pathless | grep '_' > /dev/null
                        if [ $? = 0 ]
                          then
                            echo "Catalog DP file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[A-Z]{4}_[0-9]{4}_[0-9]{4}_[0-9]{6}\.uf*' > /dev/null
                            if [ $? = 1 ]
                              then
                                echo "Bad DP 1CUF filename: $pathless"
                                return
                              else
                                dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                          else
                            echo "Catalog legacy 1CUF file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[0-9]{6}\.[0-9][0-9]?\.[A-Z]{4}\.[0-9]\.[0-9]{4}\.uf*' > /dev/null
                            if [ $? = 1 ]
                              then
                                echo "Bad legacy 1CUF filename: $pathless"
                                return
                              else
                                dtime=`echo $pathless | cut -f5 -d'.' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                        fi ;;
  2A54 | 2A55 | 1C51 )  echo $pathless | \
                                egrep '(2A5[3-5]|1C51)\.[0-9]{6}\.[0-9][0-9]?\.[A-Z]{4}\.[0-9]\.HDF*' > /dev/null
                              if [ $? = 1 ]
                                then
                                  echo "Bad 2A5x or 1C51 filename: $pathless"
                                  return
                                else
                                  dtime=`echo $pathless | cut -f3 -d'.'`
		                  dtime=`expr $dtime - 1`
			          dtime=${dtime}":00"
                              fi ;;
#              images )  echo $pathless | grep 'gif' > /dev/null
#                        if [ $? = 0 ]
#                          then
#                            echo "Catalog GIF file: $pathless"
#                            dtime=`echo $pathless | cut -f2 -d'.' | awk '{print \
#                               substr($1,1,2)":"substr($1,3,2)}'`
#                          else
#                            echo "Catalog PNG file: $pathless"
#                            dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
#                                   substr($1,1,2)":"substr($1,3,2)}'`
#                        fi ;;
		 raw )  echo $pathless | egrep '[A-Z]{4}[0-9]{8}_[0-9]{6}\.*' > /dev/null
                        # check the file pattern
                        if [ $? = 1 ]
                          then
                            echo "Bad raw (Archive Level II) filename: $pathless"
                            return
                          else
                            dtime=`echo $pathless | cut -f2 -d'_' | awk '{print \
                              substr($1,1,2)":"substr($1,3,2)":"substr($1,5,2)}'`
                        fi ;;
                   * )  return ;;
esac

# add preceding zero to hour if needed.  First cut hh out of hh or hh:mm string
dthr=`echo $dtime | cut -f1 -d':'`
# if ( hh < 10 ) AND ( length_of_hh_string = 1 ) THEN PREPEND '0' to timestring
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

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
years=$1

echo ""

for yr2do in $years
  do
    echo "Year(/month) to do = $yr2do" | tee -a $LOG_FILE
done

for Kxxx in `ls $RAWDATADIR`
#for Kxxx in KBRO              # for testing, just do one site
  do
    echo "" | tee -a $LOG_FILE
    echo "<<<< Processing received files for site $Kxxx >>>>"\
      | tee -a $LOG_FILE

    # This file will hold a listing of files in tree at time of this run:
    tmpfile=${TMP_DIR}/ls${Kxxx}default.lis
    rm -v $tmpfile

    cd $RAWDATADIR/$Kxxx

# List the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

    for yr2do in $years
      do
     for file in `ls -R */${yr2do}*`
       do
        # a directory under which files or immediate subdirectories are about
        # to be listed has a ':' at the end of the name, replace with '/' and
        # save for prepending to any regular files listed under it
        #echo $file
        echo $file | grep ':' > /dev/null 2>&1
        if [ $? = 0 ]
          then
            # is a directory with files under it, prepare the path
            subdir=`echo $file | sed 's|:|/|'`
          else
            # is this a regular file or just a subdirectory?
            if [ -f ${subdir}${file} ]
              then
                # ignore files in 'images' directory
                echo $subdir | grep 'images' > /dev/null 2>&1
                if [ $? = 1 ]
                   then
                     # is regular file, add path and write to $tmpfile
                     echo ${subdir}${file} >> $tmpfile
                fi
            fi
        fi
     done
    done

# walk thru the file and take action depending on filename or diff command
    for entry in `cat $tmpfile`
      do
        echo "Catalog file: $entry" | tee -a $LOG_FILE
	dbfileprep $entry $Kxxx $loadfile | tee -a $LOG_FILE
    done
done

echo " "
echo "LOADFILE:"
cat $loadfile
#exit

echo "" | tee -a $LOG_FILE

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee $DB_LOG_FILE 2>&1
	if [ ! -s $DB_LOG_FILE ]
	  then
            echo "FATAL: SQL log file $DB_LOG_FILE empty or not found!"\
              | tee -a $LOG_FILE
	    echo "Saving catalog file:"
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
            exit 1
	fi
	cat $DB_LOG_FILE >> $LOG_FILE
	grep -i ERROR $DB_LOG_FILE > /dev/null
	if  [ $? = 0 ]
	  then
	    echo "Error loading file to database.  Saving catalog file:"\
	     | tee -a $LOG_FILE
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
	fi
      else
        echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
          | tee -a $LOG_FILE
	echo "Saving catalog file:"
	mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
        exit 1
    fi
  else
    echo "No new file catalog info to load to database for this run."\
     | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Script complete, exiting." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
exit
