#!/bin/sh
################################################################################
#
#  CleanOutKWAJ_CSI_PR.sh     Morris/SAIC/GPM GV     January 2009
#
#  DESCRIPTION
#  -----------
#  PR orbital subsets for KWAJ are produced by the PPS whenever TRMM passes
#  within 750 km of the KWAJ site.  We only want to keep those orbits which
#  are within 250 km of the site, as tabulated in the overpass_event table in
#  the gpmgv database.  This script uses SQL commands to build a file listing
#  those KWAJ PR subset products where the orbit is not contained in the
#  overpass_event table (i.e., was beyond 250 km from KWAJ), and deletes those
#  files from the /data/prsubset/producttype directories for each such file.
#
#  Since there may be a lag in getting CT files which populate the entries in
#  the overpass_event table, or there may be missing CT files, there is a date
#  parameter in the SQL command file CleanOutKWAJ_CSI_PR.sql which must be set
#  to the date at/beyond which KWAJ PR subset files are not to be deleted.  The
#  user is prompted to validate that this date has been set in the SQL file
#  before the script will proceed in determining the files to be deleted.
#
#  The corresponding entries for the deleted files are NOT automatically removed
#  from the orbit_subset_product table.  If the file deletion proceeds normally,
#  then there is a commented-out command at the end of the SQL file that can be
#  run in psql to delete these entries, provided the kwaj_pr_to_rm table created
#  by the preceding SQL commands has not yet been dropped.
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
LOG_DIR=/data/logs
PR_DIR=${DATA_DIR}/prsubsets
#PR_BACK_DIR=/media/usbdisk$PR_DIR

BIN_DIR=${GV_BASE_DIR}/scripts
SQL_BIN=${BIN_DIR}/CleanOutKWAJ_CSI_PR.sql

rundate=`date -u +%y%m%d`

LOG_FILE=${LOG_DIR}/CleanOutKWAJ_CSI_PR.${rundate}.log
export rundate
echo "Starting file cleanup run for KWAJ PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "You must first modify the SQL file $SQL_BIN "
echo "to set the last date for which KWAJ subsets are to be deleted, "
echo "after checking the latest CT availability.  Also run "
echo "doMissingMetadata_wSubDS1.sh before running this script. "
echo ""
echo "Has this been done? (Y or N):"
read -r bail
if [ "$bail" != 'Y' -a "$bail" != 'y' ]
  then
     if [ "$bail" != 'N' -a "$bail" != 'n' ]
       then
         echo "Illegal response."
     fi
     echo "Quitting on user command." | tee -a $LOG_FILE
     exit
fi

#target=/media/usbdisk
#ls $target > /dev/null 2>&1
#if [ $? != 0 ]
#  then
#    echo ""
#    echo "Files will also be cleaned up from the USB backup drive, if mounted."
#    echo "USB disk is off or unmounted.  Do you want to continue anyway? (Y or N):"
#    read -r bail2
#    if [ "$bail2" != 'Y' -a "$bail2" != 'y' ]
#      then
#         if [ "$bail2" != 'N' -a "$bail2" != 'n' ]
#           then
#             echo "Illegal response."
#         fi
#         echo "Quitting on user command." | tee -a $LOG_FILE
#         exit
#    fi
#fi
echo ""

umask 0002
files2del=/data/tmp/CleanOutKWAJ_CSI_PR.files2del.${rundate}.txt

echo "" | tee -a $LOG_FILE

if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN"  |  psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
  else
    echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
      | tee -a $LOG_FILE
    exit 1
fi

echo "\t \a \f '|' \o $files2del \
     \\\select * from kwaj_pr_to_rm;" | psql gpmgv | tee -a $LOG_FILE 2>&1

# delete the files from the primary drive
for thisfile in `cat $files2del`
  do
    prfiledir=`echo $thisfile | cut -f1 -d '|'`
    rm -v ${PR_DIR}/${prfiledir}  | tee -a $LOG_FILE 2>&1 #DOES NOTHING UNTIL echo IS REMOVED FROM COMMAND
done

# delete the files from the USB backup drive
#target=/media/usbdisk
#ls $target > /dev/null 2>&1
#if [ $? != 0 ]
#  then
#    echo "USB disk off or unmounted.  Exit without deleting files from backup disk." \
#    | tee -a $LOG_FILE
#  else
#    for thisfile in `cat $files2del`
#      do
#        prfiledir=`echo $thisfile | cut -f1 -d '|'`
#        rm -v ${PR_BACK_DIR}/${prfiledir}  | tee -a $LOG_FILE 2>&1 #DOES NOTHING UNTIL echo IS REMOVED FROM #COMMAND
#    done
#fi

echo ""
echo "Can now run last query in $SQL_BIN "
echo "manually from psql to delete corresponding rows from database tables for "
echo "deleted files."
echo ""
echo "DONE"

exit
