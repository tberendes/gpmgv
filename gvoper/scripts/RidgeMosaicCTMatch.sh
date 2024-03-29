#!/bin/sh
################################################################################
#
#  RidgeMosaicCTMatch.sh     Morris/SAIC/GPM GV     August 2006
#
#  DESCRIPTION
#    Matches renamed CONUS radar mosaic files 'YYYY-Mon-DD.HH:MM:SS.gif' 
#    from NWS site to the TRMM overpass coincident periods in the CT.yyyymmdd.7
#    files from the PPS ftp site.  The CT file was parsed, processed, and its
#    pertinent fields were previously loaded to the PostGRESQL 'gpmgv' database
#    table 'ct_temp' by the script wgetCTdaily.sh, which invokes this script.
#    Datetimes and names of the latest.gif files have been written into the
#    database table 'heldmosaic' by the ingest script.  Mosaic image files for
#    coincident with the TRMM overpasses will be moved from the 'holding'
#    directory into the 'archivedmosaic' directory, and non-coincident images
#    will be deleted.
#
#  FILES
#
#    YYYY-Mon-DD_HH:MM.gif - Renamed latest.gif files, located in
#                            /data/gpmgv/mosaicimages/holding directory.
#
#    mosaic2del.lis - List of mosaic filenames which are non-coincident with
#                     TRMM overpasses.  These files will be deleted.
#
#    mosiac2sav.lis - List of mosaic filenames which are coincident with the
#                     TRMM overpasses.  These files will be moved from the
#                     'holding' directory into the 'archivedmosaic' directory.
#                     
#  DATABASE
#    Uses data from 'ct_temp' and 'heldmosaic' tables in 'gpmgv' database to
#    determine matching times between NEXRAD mosaics and TRMM overpasses. 
#    Logic is contained in SQL commands in file new_mosaicCTmatch.sql, run in
#    PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    RidgeMosaicCTMatch.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', and SELECT,UPDATE,INSERT,DELETE privileges on tables. 
#      Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $MOSAIC_DATA, $LOG_DIR directories
#
#  HISTORY
#    Oct 2010 - Morris - Removed redundant "Moving" Deleting" echo commands,
#                        now just shows the 'mv -v' and 'rm -v' output in logs.
#    Nov 2013 - Morris - Using >> rather than "| tee -a" to capture any psql
#                        error output in main queries.
#    Mar 2014 - Morris - Calling new_mosaicCTmatch.sql in place of
#                        mosaicCTmatch.sql for multi-satellite situation.
#    Aug 2014 - Morris - Changed LOG_DIR to /data/logs
#                        Moved the non-archive directories under /data/tmp
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
TMP_DIR=/data/tmp
MOSAIC_BASE_DATA=${DATA_DIR}/mosaicimages
MOSAIC_ARCHIVE=${MOSAIC_BASE_DATA}/archivedmosaic
MOSAIC_TMP_DATA=${TMP_DIR}/mosaicimages
MOSAIC_TRASH=${MOSAIC_TMP_DATA}/trashedmosaic
MOSAIC_DATA_HOLD=${MOSAIC_TMP_DATA}/holding
BIN_DIR=${GV_BASE_DIR}/scripts
SQL_BIN=${BIN_DIR}/new_mosaicCTmatch.sql
PATH=${PATH}:${BIN_DIR}
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/RidgeMosaicCTMatch.${rundate}.log
runtime=`date -u`

umask 0002

echo "===================================================" | tee $LOG_FILE
echo " Match up prior day's Ridge mosaic files on $runtime." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ $# = 1 ] 
  then
     delmov=$1
     if [ $delmov != 'd' -a $delmov != 'm' ]
       then
         echo "Unknown delete/move flag '${delmov}' specified in"\
          | tee -a $LOG_FILE
         echo "arguments, assume move for safety." | tee -a $LOG_FILE
         delmov='m'
     fi
  else
     delmov='m'
     echo "No delete/move flag specified in arguments, assume move for safety."\
      | tee -a $LOG_FILE
fi

cd ${MOSAIC_DATA_HOLD}

echo "Remove prior day's list files:" | tee -a $LOG_FILE

rm -fv mosaic2*.lis | tee -a $LOG_FILE 2>&1

echo "" | tee -a $LOG_FILE
echo "Run the matchup SQL command to get lists of files to delete and move:" \
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN"  |  psql -a -d gpmgv >> $LOG_FILE 2>&1
  else
    echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
      | tee -a $LOG_FILE
    exit 1
fi

echo "" | tee -a $LOG_FILE
sleep 1

if [ -s ${MOSAIC_DATA_HOLD}/mosaic2sav.lis ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Moving coincident mosaic images to mosaicarchive directory:" \
      | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE
     for savfil in `cat ${MOSAIC_DATA_HOLD}/mosaic2sav.lis`
       do
         #echo "Moving $savfil" | tee -a $LOG_FILE
         mv -v ${MOSAIC_DATA_HOLD}/${savfil} ${MOSAIC_ARCHIVE} \
          | tee -a $LOG_FILE 2>&1
     done
  else
    echo "No coincident files to move!" | tee -a $LOG_FILE
fi

if [ -s ${MOSAIC_DATA_HOLD}/mosaic2del.lis ]
  then
     if [ $delmov = 'm' ]
       then
	  echo "" | tee -a $LOG_FILE
          echo "Move non-coincident mosaic images to trashedmosaic directory:" \
	   | tee -a $LOG_FILE
	  echo "" | tee -a $LOG_FILE
          for delfil in `cat ${MOSAIC_DATA_HOLD}/mosaic2del.lis`
            do
              #echo "Moving $delfil" | tee -a $LOG_FILE
              mv -v ${MOSAIC_DATA_HOLD}/$delfil ${MOSAIC_TRASH} \
	       | tee -a $LOG_FILE 2>&1
          done
       else if [ $delmov = 'd' ]
         then
	    echo "" | tee -a $LOG_FILE
            echo "Deleting non-coincident mosaic images:" | tee -a $LOG_FILE
	    echo "" | tee -a $LOG_FILE
            for delfil in `cat ${MOSAIC_DATA_HOLD}/mosaic2del.lis`
              do
                #echo "Deleting $delfil" | tee -a $LOG_FILE
                rm -fv ${MOSAIC_DATA_HOLD}/$delfil | tee -a $LOG_FILE 2>&1
            done
       fi
     fi
  else
    echo "No files to delete!" | tee -a $LOG_FILE
fi

exit 0

