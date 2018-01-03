#!/bin/sh

################################################################################
#
# pr2tmi_nn_driver.sh    Morris/SAIC/GPM GV    April 2013
#
# DESCRIPTION
#   Runs IDL in batch mode to generate PR-TMI matchups and write them to netCDF
#   files, for a specified set of dates for files whose YY[YY]MMDD date part
#   is provided as the single argument to this script.
#
# ARGUMENTS
#   YYYYMMDD - A single string listing the 4-digit year, month, and (optional)
#              day of the file timestamps for which matchups are to be generated.
#              No validity checks are performed on the value of this date string,
#              other than that it must be > 201001.
#
# FILES
#   /data/gpmgv/tmp/fullOrbit2A12.txt  (OUTPUT) - lists the current data file to
#                                      be processed by IDL's pr2tmi_nn_driver. 
#                                      YYMMDD is passed to this script as the
#                                      sole argument.  YYMMDD is the yr, month,
#                                      day of the data.  The file pathnames are
#                                      generated within this script.
#   pr2tmi_nn_driver.bat               (BATCH) - Batch file of IDL commands
#                                      to run pr2tmi_nn_driver procedure.
#
#  RETURN VALUES
#    0 = normal, successfully created new matchup files
#    1 = error in processing or no input data; no matchup files created
#
################################################################################


if [ $# != 1 ] 
  then
     echo "FATAL: Exactly one argument required, $# given." | tee -a $LOG_FILE
     exit 1
fi

datepattern=$1
if [ `expr $datepattern \< 201001` = 1 ]
  then
    echo "Argument must include both a year and 2-digit month."
    echo "Value provided = $datepattern"
    exit 1
fi

GV_BASE_DIR=/home/morris/swdev
BIN_DIR=${GV_BASE_DIR}/scripts
USER_ID=`whoami`
IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev
export IDL_PRO_DIR                    # IDL pr2tmi_nn_driver.bat needs this
IDL=/usr/local/bin/idl
fileOut=/data/gpmgv/tmp/fullOrbit2A12.txt

for file2do in `ls /data/gpmgv/fullOrbit/2A12/*.${datepattern}*.7.HDF.Z`
  do
    echo $file2do | tee $fileOut
    $IDL < ${IDL_PRO_DIR}/pr2tmi_nn_driver.bat
done

exit
