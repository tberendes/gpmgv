#!/bin/sh
###############################################################################
#
# loadMetadataGPROF.sh    Morris/SAIC/GPM GV    May 2016
#
# DESCRIPTION
#
# Loads a delimited text file containing 2A-GPROF product metadata into
# tables in the the 'gpmgv' database in PostGRESQL.  Does a '\copy' of the
# data into the 'metadata_temp' table in the initial load step.  Then checks
# these data rows against permanent metadata in the 'event_meta_numeric_copy'
# table for duplicates, and inserts non-duplicate (new) metadata into the
# permanent 'event_meta_numeric_copy' table.  Data are then deleted from the
# 'metadata_temp' table.
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
# Logs output to temporary log file /data/tmp/loadMetadataGPROF_temp.log in an
# overwrite manner.  Calling script should capture output of this script in
# its own log file if a permanent record is needed.
#                     
# DATABASE
# Loads data into metadata_temp and event_meta_numeric_copy tables in 'gpmgv'
# database in PostGRESQL, via call to psql utility.
#
###############################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
LOG_DIR=/data/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts
EXIT_STATUS=0

echo ""
echo ">>>>>>>>>>  INSIDE SCRIPT loadMetadataGPROF.sh  <<<<<<<<<<"
echo ""

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/loadMetadataGPROF.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISFILE=$1
THISRUN=`echo $THISFILE | cut -f2 -d '.'`
LOG_FILE=${META_LOG_DIR}/loadMetadataGPROF_temp.log
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
	echo "Move metadata to permanent table event_meta_numeric_copy,"\
	 | tee -a $LOG_FILE
	echo "where not duplicate of existing data:" | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "INSERT INTO event_meta_numeric_copy\
  SELECT t.* FROM metadata_temp t WHERE NOT EXISTS\
 (SELECT * FROM event_meta_numeric_copy p WHERE p.event_num = t.event_num\
 AND p.metadata_id = t.metadata_id);
 DELETE FROM metadata_temp;" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    fi
  else
    echo "FATAL: File ${THISFILE} empty or nonexistent!" | tee -a $LOG_FILE
    EXIT_STATUS=1
fi

echo ""
echo "<<<<<<<<<<  LEAVING SCRIPT loadMetadataGPROF.sh  >>>>>>>>>>"
echo ""

exit $EXIT_STATUS
