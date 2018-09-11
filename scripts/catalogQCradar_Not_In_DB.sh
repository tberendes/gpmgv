#!/bin/sh
################################################################################
#
#  catalogQCradar_Not_In_DB.sh     Morris/SAIC/GPM GV     August 2013
#
#  DESCRIPTION
#    
#    Catalog specific set of files found in the /data/gpmgv/gv_radar/finalQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradar'.  Lets SQL commands handle whether the file has been
#    previously cataloged.
#
#  FILES
#   finalQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' (temporarily) and 'gvradar' (permanently)
#    tables in 'gpmgv' database.  Logic is contained in SQL commands in file
#    catalogQCradar.sql, run in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalogQCradar_Not_In_DB.YYMMDD.log in /data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', SELECT/INSERT privileges on table 'gvradar', and
#      SELECT/INSERT/DELETE privileges on table 'gvradartemp'.  Utility
#      'psql' must be in user's $PATH.
#
#  HISTORY
#    07/09/2010, Morris, GPM GV
#    - Replaced hard-wired pathnames under /data/tmp with $TMP_DIR for running
#      on ds1-gpmgv with different file paths.
#    03/20/2012, Morris, GPM GV
#    - Modified parsing of hour and minute for 1CUF files to retain minutes
#      rather than truncating to hour.
#    06/18/2012, Morris, GPM GV
#    - Added automatic configuration of GV_BASE_DIR and DATA_DIR based on user
#      and machine IDs.  Modified Postgresql process count error messages.
#    08/29/2012, Morris, GPM GV
#    - Added logic to dbfileprep() 1CUF case to handle new Dual-pol file naming
#      convention.
#    03/25/14, Morris, GPM GV
#    - Adding 'raw' file type to those cataloged in this script now that these
#      are included under the finalQC_in directory tree.
#
################################################################################

#if [ $# != 1 ]
#  then
#     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
#     exit 1
#fi

#site2do=$1

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  tberendes ) GV_BASE_DIR=/home/tberendes/git/gpmgv/ ;;
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

TMP_DIR=/data/tmp
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=/data/logs

SQL_BIN=${BIN_DIR}/catalogQCradar_Not_In_DB.sql
loadfile=/data/tmp/finalQC_KxxxMeta.unl

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogQCradar_Not_In_DB.${rundate}.log
DB_LOG_FILE=${LOG_DIR}/catalogQCradar_Not_In_DBSQL.log
runtime=`date -u`

umask 0002

#topdir=$QCDATADIR/$site2do
#if [ ! -d $topdir ]
#  then
#    echo "DIRECTORY $QCDATADIR/$site2do not found!"
#    exit 1
#fi

echo "=====================================================" | tee $LOG_FILE
echo " Catalog any uncataloged $site2do QC radar files for " | tee -a $LOG_FILE
echo "        $years" | tee -a $LOG_FILE
echo "-----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

#exit

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 5 ]
  then
    echo "Message from catalogQCradar.sh cron job on ${runtime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 5 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c todd.a.berendes@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 5." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

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
           1CUF )  case $2 in
                 NPOL )
                       # check the file pattern
                        echo $pathless | egrep '(npol|NPOL)1_[0-9]{4}_[0-9]{4}_[0-9]{6}(_rhi)*\.(uf|cf)*' > /dev/null
                        if [ $? = 1 ]
                          then
                            echo "Bad NPOL DP 1CUF filename: $pathless"
                            return
                          else
                            dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                   substr($1,1,2)":"substr($1,3,2)}'`
                        fi ;;
                     *)
                        echo $pathless | grep '_' > /dev/null
                        if [ $? = 0 ]
                          then
                            #echo "Catalog DP file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[A-Z]{4}_[0-9]{4}_[0-9]{4}_[0-9]{6}\.(uf|cf)*' > /dev/null
                            if [ $? = 1 ]
                              then
                                echo "Bad DP 1CUF filename: $pathless"
                                return
                              else
                                dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                          else
                            #echo "Catalog legacy 1CUF file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[0-9]{6}\.[0-9][0-9]?\.[A-Z]{4}\.[0-9]\.[0-9]{4}\.(uf|cf)*' > /dev/null
                            if [ $? = 1 ]
                              then
                                echo "Bad legacy 1CUF filename: $pathless"
                                return
                              else
                                dtime=`echo $pathless | cut -f5 -d'.' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                        fi ;;
                    esac ;;
  2A53 | 2A54 | 2A55 | 1C51 ) echo $pathless | \
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
#                            #echo "Catalog GIF file: $pathless"
#                            dtime=`echo $pathless | cut -f2 -d'.' | awk '{print \
#                               substr($1,1,2)":"substr($1,3,2)}'`
#                          else
#                            #echo "Catalog PNG file: $pathless"
#                            dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
#                                   substr($1,1,2)":"substr($1,3,2)}'`
#                        fi ;;
		 raw )  case $2 in
                           KING ) echo $pathless | grep '_' > /dev/null
                                  if [ $? = 0 ]
                                    then
                                      # have the full-volume file like WKR_201403122050_CONVOL.iri.gz
                                      echo $pathless | egrep 'WKR_[0-9]{12}_CONVOL\.**' > /dev/null
                                      if [ $? = 1 ]
                                        then
                                          echo "Bad raw KING filename: $pathless"
                                          return
                                        else
                                          dtime=`echo $pathless | cut -c13-16 | awk '{print \
                                            substr($1,1,2)":"substr($1,3,2)":00"}'`
                                      fi
                                    else
                                      # have the RHI file like WKR140312204431.RAWBWZY.gz
                                      echo "Ignoring file $1 in cataloging procedure."
                                      return
                                  fi ;;
                           KWAJ ) echo $pathless | egrep 'KWA[0-9]{12}\.RAW[0-9|A-Z]{4}\.**' > /dev/null
                                  if [ $? = 1 ]
                                    then
                                      echo "Bad raw KWAJ filename: $pathless"
                                      return
                                    else
                                      dtime=`echo $pathless | cut -c10-15 | awk '{print \
                                        substr($1,1,2)":"substr($1,3,2)":"substr($1,5,2)}'`
                                  fi ;;
                              * ) echo $pathless | egrep '[A-Z]{4}[0-9]{8}_[0-9]{6}\.*' > /dev/null
                                  # check the file pattern
                                  if [ $? = 1 ]
                                    then
                                      echo "Bad raw (Archive Level II) filename: $pathless"
                                      return
                                    else
                                      dtime=`echo $pathless | cut -f2 -d'_' | awk '{print \
                                        substr($1,1,2)":"substr($1,3,2)":"substr($1,5,2)}'`
                                  fi ;;
                        esac ;;
                   * )  return ;;
esac

# add preceding zero to hour if needed.  First cut hh out of hh or hh:mm string
dthr=`echo $dtime | cut -f1 -d':'`
# if hh < 10 AND length_of_hh_string = 1 THEN PREPEND '0' to timestring
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

echo ""

years="2017"

# List the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

#    cd $topdir

products2do=1CUF    #"1C51 1CUF level_2 raw"
#for Kxxx in `ls $QCDATADIR`
#for Kxxx in NPOL
for Kxxx in CHUVA
  do
    cd ${QCDATADIR}/${Kxxx}
    for prodtype in $products2do
      do
        for yr2do in $years
          do
            echo "Cataloging ${QCDATADIR}/${Kxxx}/${prodtype}/${yr2do}"
            for file in `ls ${prodtype}/${yr2do}/*/*`
              do
                #echo "Catalog file: $file" | tee -a $LOG_FILE
	        dbfileprep $file $Kxxx $loadfile | tee -a $LOG_FILE
            done
        done
    done
done

echo "" | tee -a $LOG_FILE
#head $loadfile
#tail $loadfile
#grep 1CUF $loadfile | head
#exit

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database.  New file count:" | tee -a $LOG_FILE
    wc -l $loadfile | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    cp -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
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
