#!/bin/sh

################################################################################
# get_CT_entries4new_sites.sh
#
# Walks through all the CT files (current and archived in tar.gz files) in
# /data/coincidence_table, and calls CT_to_DBmore.sh to process the overpasses
# FOR NEW GROUND SITES DEFINED IN THAT SCRIPT into a delimited data file ready
# for loading into the ct_temp table in the gpmgv database.  Then runs SQL
# commands in CT_to_DBmore.sql via call to psql utility to load the new entries
# into the overpass_event table in the database.
################################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
CT_DATA=${DATA_DIR}/coincidence_table
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/get_CT_entries4new_sites.log
PATH=${PATH}:${BIN_DIR}
TMP_DIR=/data/tmp/ct_tmp

SQL_BIN=${BIN_DIR}/CT_to_DBmore.sql
loadfile=${TMP_DIR}/ct_temp.unl
DB_LOG_FILE=${LOG_DIR}/CT_to_DBmore.sql.log

umask 0002

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from get_CT_entries4new_sites.sh on ${thistime}:" \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      | tee -a $LOG_FILE
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." | tee -a $LOG_FILE
    exit 1
#  else
#    echo "${pgproccount} Postgres processes active, should be 3." \
#      | tee -a $LOG_FILE
#    echo "" | tee -a $LOG_FILE
fi

mkdir -p $TMP_DIR
cd $TMP_DIR

if [ -s $loadfile ]
  then
    rm -v $loadfile | tee -a $LOG_FILE 2>&1
fi

for file in `ls ${CT_DATA}/CT.*.6`
  do
    ${BIN_DIR}/CT_to_DBmore.sh $file $loadfile
done

for file in `ls ${CT_DATA}/CT*archive.tar.gz`
  do
    cp $file CTTEMP.tar.gz
    tar -xvzf CTTEMP.tar.gz
    rm -v CTTEMP.tar.gz
    rm CT*.unl
    for file in `ls CT.*.6`
      do
        ${BIN_DIR}/CT_to_DBmore.sh $file $loadfile
    done
    rm CT.*.6
done

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading new overpass event data to database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    if [ -s $SQL_BIN ]
      then
        echo "Load following .unl file from CT_to_DBmore.sh to database:" \
          | tee -a $LOG_FILE
        ls -al $loadfile | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "\copy ct_temp FROM '${loadfile}' WITH DELIMITER '|'" \
          | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
        echo "" | tee -a $LOG_FILE
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee $DB_LOG_FILE 2>&1
	if [ ! -s $DB_LOG_FILE ]
	  then
            echo "FATAL: SQL log file $DB_LOG_FILE empty or not found!"\
              | tee -a $LOG_FILE
	    echo "Saving overpass events file:"
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
            exit 1
	fi
	cat $DB_LOG_FILE >> $LOG_FILE
	grep -i ERROR $DB_LOG_FILE > /dev/null
	if  [ $? = 0 ]
	  then
	    echo "Error loading file to database.  Saving overpasses file:"\
	     | tee -a $LOG_FILE
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
	    echo "delete from ct_temp;" | psql -a -d gpmgv \
	      | tee -a $LOG_FILE 2>&1
	fi
      else
        echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
          | tee -a $LOG_FILE
	echo "Saving overpass events file:"
	mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
        exit 1
    fi
  else
    echo "No new overpass events to load to database for this run."\
     | tee -a $LOG_FILE
fi

exit