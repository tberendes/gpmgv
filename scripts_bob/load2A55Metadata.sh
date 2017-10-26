#!/bin/sh
###############################################################################
#
# load2A55Metadata.sh    Morris/SAIC/GPM GV    November 2006
#
# DESCRIPTION
#
# Loads a delimited text file containing 2A55 file names and their included 
# NEXRAD volume scan times into the 'gvradvol_temp' table in the 'gpmgv'
# database in PostGRESQL.  Does a '\copy' of the data in the initial load step.

# Then checks these data rows against permanent metadata in the 'gvradarvolume'
# table for duplicates, and inserts non-duplicate (new) metadata into the
# permanent 'gvradarvolume' table.  Data are then deleted from the
# 'gvradvol_temp' table.
#
# FILES
#
# Takes the full-qualified file pathname of an ascii, delimited text file as
# the sole argument of the script, and loads its data into the gpmgv database.
#
# LOGS
#
# Logs output to temporary log file /data/tmp/load2A55Metadata_temp.log in an
# overwrite manner.  Calling script should capture output of this script in
# its own log file if a permanent record is needed.
#                     
# DATABASE
# Loads data into gvradvol_temp and gvradarvolume tables in 'gpmgv'
# database in PostGRESQL, via call to psql utility.
#
###############################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs
BIN_DIR=${GV_BASE_DIR}/scripts
EXIT_STATUS=0

echo ""
echo ">>>>>>>>>>  INSIDE SCRIPT load2A55Metadata.sh  <<<<<<<<<<"
echo ""

if [ $# != 1 ] 
  then
     THISRUN=`date -u +%y%m%d`
     LOG_FILE=${META_LOG_DIR}/load2A55Metadata.${THISRUN}.fatal.log
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

THISFILE=$1
THISRUN=`echo $THISFILE | cut -f2 -d '.'`
LOG_FILE=${META_LOG_DIR}/load2A55Metadata_temp.log
echo "Loading metadata file $THISFILE for rundate ${THISRUN}"\
 | tee $LOG_FILE
echo "into temporary holding table gvradvol_temp:" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $THISFILE ]
  then
    # load the data into the '_temp' table
    DBOUT=`psql -q -d gpmgv -c "\copy gvradvol_temp FROM '${THISFILE}'\
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
        DBOUT=`psql -q -t -d gpmgv -c "SELECT count(*) FROM gvradvol_temp;"`
	echo "$DBOUT rows loaded." | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "Move metadata to permanent table gvradarvolume,"\
	 | tee -a $LOG_FILE
	echo "where not duplicate of existing data:" | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
	echo "INSERT INTO gvradarvolume(filename,start_time)\
  SELECT t.* FROM gvradvol_temp t WHERE NOT EXISTS\
 (SELECT * FROM gvradarvolume p WHERE p.filename = t.filename\
 AND p.start_time = t.start_time);
 DELETE FROM gvradvol_temp;" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
    fi
  else
    echo "FATAL: File ${THISFILE} empty or nonexistent!" | tee -a $LOG_FILE
    EXIT_STATUS=1
fi

echo ""
echo "<<<<<<<<<<  LEAVING SCRIPT load2A55Metadata.sh  >>>>>>>>>>"
echo ""

exit $EXIT_STATUS