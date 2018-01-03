#!/bin/sh
#

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
TMP_DIR=${DATA_DIR}/prsubsets/
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogPRfullOrbitV7test225.${rundate}.log

SQL_BIN=${BIN_DIR}/catalogPRnon_mirror.sql
loadfile=${TMP_DIR}/catalogPRdbtemp.unl
DB_LOG_FILE=${LOG_DIR}/catalogPRnon_mirrorSQL.log

echo "Catalog PR full-orbit products in gpmgv database, and" | tee $LOG_FILE
echo "move files from download directory." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# satid is the id of the instrument whose data file products are being cataloged
# and is used to identify the orbit product files' data source in the gpmgv
# database
satid="PR"

if [ -s $loadfile ]
  then
    rm -v $loadfile
fi

subset="sub-GPMGV1"         # hard-wire subset

    # catalog the files in the database
    for type in 1C21 2A23 2A25 2B31
      do
        cd ${TMP_DIR}  # ftp download directory for PR product files
        for file in `ls ${type}.*ITE_225*`
          do
            mv -v $file ${DATA_DIR}/prsubsets/${type} | tee -a $LOG_FILE
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
	    version=225 #`echo $file | cut -f4 -d '.'`
	    #echo "subset ID = $subset" | tee -a $LOG_FILE
            #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	    echo ${satid}'|'${orbit}'|'${type}'|'${dateString}'|'${file}'|'${subset}'|'${version} \
	      | tee -a $loadfile | tee -a $LOG_FILE
        done
    done
#exit

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

exit
