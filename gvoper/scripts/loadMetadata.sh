#!/bin/sh
###############################################################################
#
# loadMetadata.sh    Morris/SAIC/GPM GV    October 2006
#
# DESCRIPTION
#
# Loads a delimited text file containing PR or NEXRAD product metadata into
# tables in the the 'gpmgv' database in PostGRESQL.  Does a '\copy' of the
# data into the 'metadata_temp' table in the initial load step.  Then checks
# these data rows against permanent metadata in the 'event_meta_num' table for
# duplicates, and inserts non-duplicate (new) metadata into the permanent
# 'event_meta_num' table.  Data are then deleted from the 'metadata_temp'
# table.
#
# FILES
#
# Takes the full-qualified file pathname of an ascii, delimited text file as
# the sole argument of the script, and loads its data into the gpmgv database.
# Filename must be of the form '/path(s)/firstpart.YYMMDD.lastpart'.  The
# important thing is that YYMMDD must appear between the first and second
# period (.) characters in the full pathname.
#
# LOGS
#
# Logs output to temporary log file /data/logs/meta_logs/loadMetadata_temp.log
# in an overwrite manner.  Calling script should capture output of this
# script in its own log file if a permanent record is needed.
#                     
# DATABASE
# Loads data into metadata_temp and event_meta_numeric tables in 'gpmgv'
# database in PostGRESQL, via call to psql utility.
#
#  HISTORY
#    11/08/2013 - Morris, SAIC, GPM GV
#    - Using >> rather than "| tee -a" to capture any psql error output
#      in main queries.
#    08/26/2014 - Morris
#    - Changed LOG_DIR to /data/logs
#
###############################################################################

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts
EXIT_STATUS=0

echo ""
echo ">>>>>>>>>>  INSIDE SCRIPT loadMetadata.sh  <<<<<<<<<<"
echo ""

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/loadMetadata.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISFILE=$1
THISRUN=`echo $THISFILE | cut -f2 -d '.'`
LOG_FILE=${META_LOG_DIR}/loadMetadata_temp.log
echo "Loading metadata file $THISFILE for rundate ${THISRUN}"\
 | tee $LOG_FILE
echo "into temporary holding table metadata_temp:" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $THISFILE ]
  then
    # load the data into the 'metadata_temp' table
    DBOUT=`psql -q -d gpmgv -c "\copy metadata_temp FROM '${THISFILE}'\
     WITH DELIMITER '|'" 2>&1`
#    echo $DBOUT | tee -a $LOG_FILE  
#    echo "" | tee -a $LOG_FILE
    echo $DBOUT | grep -E '(ERROR)' > /dev/null
    if [ $? = 0 ]
      then
        echo $DBOUT | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "FATAL: Could not load data from ${THISFILE} to database!"\
	 | tee -a $LOG_FILE
        EXIT_STATUS=1
      else
        DBOUT=`psql -q -t -d gpmgv -c "SELECT count(*) FROM metadata_temp;"`
	echo "$DBOUT rows loaded." | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "Move metadata to permanent table event_meta_numeric,"\
	 | tee -a $LOG_FILE
	echo "where not duplicate of existing data:" | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "INSERT INTO event_meta_numeric\
  SELECT t.* FROM metadata_temp t WHERE NOT EXISTS\
 (SELECT * FROM event_meta_numeric p WHERE p.event_num = t.event_num\
 AND p.metadata_id = t.metadata_id);\
 DELETE FROM metadata_temp;" | psql -a -e -d gpmgv >> $LOG_FILE 2>&1
    fi
  else
    echo "FATAL: File ${THISFILE} empty or nonexistent!" | tee -a $LOG_FILE
    EXIT_STATUS=1
fi

echo ""
echo "<<<<<<<<<<  LEAVING SCRIPT loadMetadata.sh  >>>>>>>>>>"
echo ""

exit $EXIT_STATUS
