#!/bin/sh
catqcproc=`ps -ef | grep catalogQCradar | grep -v grep | wc -l`
if [ ${catqcproc} -eq 0 ]
  then
    echo "Waiting 5 minutes for catalogQCradar to finish." | tee -a $LOG_FILE
    declare -i tries=0
    waitforqc=1
    while [ ${waitforqc} -eq 1 ]
      do
        tries=tries+1
        if [ $tries -eq 6 ]
          then
            echo "Too many tries, quitting." | tee -a $LOG_FILE
            exit 1
        fi
        echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
        sleep 3
        catqcproc=`ps -ef | grep catalogQCradar | grep -v grep | wc -l`
        if [ ${catqcproc} -eq 1 ]
          then
            waitforqc=0
            echo "catalogQCradar finished, proceeding." | tee -a $LOG_FILE
        fi
    done
fi

