#!/bin/sh
#
# getPPSftpListings_v4test_NSSL.sh    Morris/SAIC/GPM GV    April 2014
#
# DESCRIPTION:
#
# Uses Perl script 'mirror' to create a local mirror of the PPS ftp location
# where ftp_url_YYMMDDHHMM.txt listing files are located.  Makes up to 10
# attempts to access the ftp site and download all the files not present in the
# local directory, $MIR_DATA_DIR.  Examines MIR_LOG_FILE to determine whether
# any errors occurred in the last run of mirror, and if so, makes a retry after
# a sleep period.
#
# FILES:
#
#                  mirror - Perl script to perform the directory mirroring via
#                           ftp.  Freeware download.
#
#         mirror.defaults - Default configuration items for mirror script.  Used
#                           by mirror but not referenced in this script.  May be
#                           augmented and/or overridden by package file.
#
# arthurhou.pps.eosdis.nasa.gov.v4test - Package file, holds configuration for
#                           mirror script to mirror files from ftp site.
#
#        pps_ftp_lists.log - Log file of mirror script.  Is examined to determine
#                           if download errors require mirror to be re-run.
#                           Is renamed mirror.YYMMDD.log and moved from
#                           $MIR_DATA_DIR to $LOG_DIR at end of script run.
#
#  DATABASE
#    Not used in this version of the script.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    getPPSftpListings_v4test.YYYYMMDD.log in data/logs subdirectory. 
#    YYYYMMDD is replaced by the current date.
#
#  CONSTRAINTS
#    - User must have write privileges in $MIR_DATA_DIR, $LOG_DIR directories
#
#  HISTORY
#    04/14/2014, Morris, SAIC, GPM GV
#    - Created from getPRdata.sh.
#    08/26/2014      - Morris
#    - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
#    03/29/16, Morris, SAIC, GPM GV
#    - Modified to run in OU environment without database I/O.
#
################################################################################

##### begin local configuration #####

GV_BASE_DIR=/oldeos/NASA_NMQ/satellite    # CHANGE THIS AS NEEDED, SEE BIN_DIR, MIR_BIN_DIR

TMP_DIR=/oldeos/NASA_NMQ/satellite/data/tmp
if [ ! -s $TMP_DIR ]
  then
    echo "getPPSftpListings_v4test_NSSL.sh:  Directory $TMP_DIR non-existent, please correct."
    exit 1
fi

LOG_DIR=/oldeos/NASA_NMQ/satellite/data/logs
if [ ! -s $LOG_DIR ]
  then
    echo "getPPSftpListings_v4test_NSSL.sh:  Directory $LOG_DIR non-existent, please correct."
    exit 1
fi

BIN_DIR=${GV_BASE_DIR}/scripts    # CHANGE AS NEEDED, NOTE THAT mirror DIRECTORY MUST BE UNDER HERE
if [ ! -s $BIN_DIR ]
  then
    echo "getPPSftpListings_v4test_NSSL.sh:  Directory $BIN_DIR non-existent, please correct."
    exit 1
fi

# All the ftp_url files are downloaded to MIR_DATA_DIR, and these files remain
# here so that mirror can determine which ftp_url fileson PPS ftp site are new.

### MIR_DATA_DIR MUST BE SAME AS TMP_CS_DATA IN get_PPS_CS_v4testdata_NSSL.sh ###

# Following two variables must be the same as specified for the variables
# 'local_dir' and 'update_log' in the package file:
#      $MIR_BIN_DIR/$MIR_PACKAGES_DIR/arthurhou.pps.eosdis.nasa.gov.v4test

MIR_DATA_DIR=${TMP_DIR}/PPS_v4test                # "local_dir"
MIR_LOG_FILE=${MIR_DATA_DIR}/pps_ftp_lists.log    # "update_log"
if [ ! -s $MIR_DATA_DIR ]
  then
    echo "getPPSftpListings_v4test_NSSL.sh:  Directory $MIR_DATA_DIR non-existent, please correct."
    exit 1
fi

MIR_BIN=mirror                  # do not change, is name of Perl script
MIR_BIN_DIR=${BIN_DIR}/mirror   # do not change
# The following are specified relative to MIR_BIN_DIR, as mirror expects:
MIR_PACKAGES_DIR=packages       # do not change
# do not change the following unless defining a different 'package' file
MIR_PACKAGE=${MIR_PACKAGES_DIR}/arthurhou.pps.eosdis.nasa.gov.v4test

##### end local configuration #####

# ZZZ is number of seconds to sleep between repeat mirror attempts if problems/errors
ZZZ=300
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getPPSftpListings_v4test.${rundate}.log
export rundate

umask 0002

echo "Starting mirroring run for PPS FTP listings for $rundate." | tee -a $LOG_FILE
echo "=======================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# mirror (apparently) must be run from its home directory
cd ${MIR_BIN_DIR}

if [ ! -x ${MIR_BIN} ]
  then
     echo "Executable file '${MIR_BIN}' not found in `pwd`, exiting." \
          | tee -a $LOG_FILE
     exit 1
fi

MIRCMD=./${MIR_BIN}' '${MIR_PACKAGE}
runagain='y'
timedout='n'
declare -i tries=0

until [ "$runagain" = 'n' ]
  do
     tries=tries+1
     echo "Try = ${tries}, max = 10." | tee -a $LOG_FILE
     echo "Running following command from `pwd` :"
     echo ${MIRCMD}

# ******* run mirror command here ********
     ${MIRCMD} | tee -a $LOG_FILE

# bailout mechanism for testing
#     echo "Enter q to quit or hit return to continue:"
#     read -r bail
#     if [ "$bail" = 'q' ]
#       then
#          exit
#     fi

# If mirror cannot make connection, it does not create a log file; so we first
# need to check its direct output, as piped to this script's log

     tail -n 3 $LOG_FILE | grep -E 'Cannot connect' > /dev/null
     if [ $? = 0 ]
     then
        echo "Connect failure in mirror!" | tee -a $LOG_FILE
        if [ $tries -eq 10 ]
          then
             timedout='y'
             runagain='n'
             echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
          else
             echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
             sleep $ZZZ
        fi
     else if [ -s $MIR_LOG_FILE ]
       then
          #  THIS WAS MODIFIED TO NOT JUST LOOK AT THE ENTIRE LOG FILE, ELSE
          #  WE END UP RE-TRYING AFTER A SUCCESSFUL TRANSFER IF THERE WAS AN
	  #  EARLIER FAILURE INDICATED "HIGHER UP" IN THE LOG FILE.
          #  (FOUND WHEN RUN 1ST TIME AS 'gvoper' AND HAD PERMISSION ISSUES)
          grep -E '(Fatal|Failed)' ${MIR_LOG_FILE} > /dev/null
          if [ $? = 0 ]
          then
             # check the last line only of the mirror log file to see if we had
	     # a successful transfer ("Got" in the text) or no files were found
	     # to transfer ("successful" in the last line) since the prior error
	     tail -n 1 $MIR_LOG_FILE | grep '(Got|successful)'  > /dev/null
	     if [$? = 0 ]
	     then
                echo "Transfer succeeded after earlier error.  Continuing." \
	           | tee -a $LOG_FILE
                runagain='n'
	     else
	        echo "Transfer failures in mirror log file!" | tee -a $LOG_FILE
                if [ $tries -eq 10 ]
                then
                   timedout='y'
                   runagain='n'
                   echo "Failed after 10 tries, giving up." | tee -a $LOG_FILE
                else
                   echo "Sleeping $ZZZ seconds..." | tee -a $LOG_FILE
                   sleep $ZZZ
                fi
	     fi
          else
             echo "No error found in mirror log file." | tee -a $LOG_FILE
             runagain='n'
          fi
       else if [ -f $MIR_LOG_FILE ]
         then
            # the 'EMPTY FILE' condition probably can't happen, mirror log
	    # file always exists and has content >IF< mirror gets a connection
	    echo "Empty mirror log file, no new data to transfer this run."
            runagain='n'
         else
            echo "No log file found!" | tee -a $LOG_FILE
            runagain='n'
         fi
       fi
     fi

done

if [ -s $MIR_LOG_FILE ]
  then
    echo "" | tee -a $LOG_FILE
    # see if any data files were actually downloaded, as indicated by the
    # existence of lines containing the filename pattern 'ftp_url' in the
    # 'mirror' log file.  Exit if none...
    grep ftp_url ${MIR_LOG_FILE} > /dev/null
    if [ $? != 0 ]
      then
        echo "No ftp listings files downloaded; exit." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        if [ "$timedout" = 'y' ]
	  then
            echo "Timed out after $tries failed tries." | tee -a $LOG_FILE
	fi
        echo "" | tee -a $LOG_FILE
        echo "See log file $LOG_FILE for script output."
        mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListingsBAD.${rundate}.log \
             | tee -a $LOG_FILE 2>&1
        exit 1
    fi
    echo ""  | tee -a $LOG_FILE
    echo "Renaming mirror log file to unique/datestamped:"  | tee -a $LOG_FILE
    mv -v $MIR_LOG_FILE ${LOG_DIR}/PPSftpListings_v4test.${rundate}.log | tee -a $LOG_FILE 2>&1
fi

#cat $LOG_FILE
echo ""  | tee -a $LOG_FILE
echo "SCRIPT getPPSftpListings_NSSL.sh COMPLETE, EXITING." | tee -a $LOG_FILE
echo "See log file $LOG_FILE for script output."
echo "" | tee -a $LOG_FILE
exit
