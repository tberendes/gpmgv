#!/bin/sh
################################################################################
#
#  notify_vn_status.sh     Morris/SAIC/GPM GV     June 2012
#
#  DESCRIPTION
#    Determines the status of the daily operational ingest scripts and puts
#    together and sends an e-mail message with the summary information.
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

MACHINE=`hostname | cut -c1-3`
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac

LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/notify_vn_status.${rundate}.log
runtime=`date -u`
VN_STATUS_FILE=/tmp/VN_STATUS_MAIL_MSG.txt
export VN_STATUS_FILE

umask 0002

function extract_run_info() {

   ls -al ${1} | tee -a $VN_STATUS_FILE
   echo "" | tee -a $VN_STATUS_FILE
   s=$1
   proc_log=${s##*/}
   proc_id=`echo $proc_log | cut -f1 -d '.'`
   echo "proc_id: $proc_id"

   case $proc_id in
     wgetRidgeMosaic ) ngifs=`cat $1 | grep  holding | wc -l`
                       lastgif=`cat $1 | grep  holding | tail -n1`
                       echo "# RIDGE Mosaic GIFs downloaded so far:  $ngifs" | tee -a $VN_STATUS_FILE
                       echo "Latest mosaic: $lastgif" | tee -a $VN_STATUS_FILE ;;

     wgetCTdaily ) echo "CT file downloads and DB conversions:" | tee -a $VN_STATUS_FILE
                   cat $1 | grep coincidence_table | grep -v appstatus | tee -a $VN_STATUS_FILE ;;

     catalogQCradar ) echo "UF QC Radar files cataloged: " | tee -a $VN_STATUS_FILE
                      cat $1 | grep 1CUF | tee -a $VN_STATUS_FILE ;;

     getNAMANLgrids4RainCases ) echo "NAM/NAMANL GRIB file download status:" | tee -a $VN_STATUS_FILE
                                cat $1 | grep download | grep -v table | tee -a $VN_STATUS_FILE ;;

     getPRdata ) echo "See mirror e-mails." | tee -a $VN_STATUS_FILE ;;

     wgetKWAJ_PR_CSI )  echo "KWAJ PR CSI file download status:" | tee -a $VN_STATUS_FILE
                        cat $1 | grep CSI | tee -a $VN_STATUS_FILE ;;

     RidgeMosaicCTMatch ) echo "CT table loading and RIDGE Mosaic matchups:" | tee -a $VN_STATUS_FILE
                          cat $1 | grep -i insert | tee -a $VN_STATUS_FILE
                          cat $1 | grep archivedmosaic | tee -a $VN_STATUS_FILE ;;

     * ) echo "Unknown process type: $proc_id" | tee -a $VN_STATUS_FILE ;;
   esac

   return
}

#==================================================

# begin main script

#if [ -f $VN_STATUS_FILE ]
#  then
#    rm $VN_STATUS_FILE
#fi

echo "------------------------------------------------------------------------" | tee $VN_STATUS_FILE
echo " Check gvoper cron-run process statuses on $runtime" | tee -a $VN_STATUS_FILE
echo "------------------------------------------------------------------------" | tee -a $VN_STATUS_FILE
echo "" | tee -a $VN_STATUS_FILE

# loop through the log files for the gvoper cron-run parent and child processes

for proc in wgetRidgeMosaic wgetCTdaily RidgeMosaicCTMatch getPRdata \
            wgetKWAJ_PR_CSI catalogQCradar getNAMANLgrids4RainCases
  do
    echo "Looking for ${proc}.${rundate}.log:" | tee -a $VN_STATUS_FILE
    if [ -s ${LOG_DIR}/${proc}.${rundate}.log ]
      then
        extract_run_info ${LOG_DIR}/${proc}.${rundate}.log
      else
        proccount=`ps -ef | grep ${proc} | grep -v grep | wc -l`
        if [ ${pgproccount} -gt 0 ]
          then
            echo "Process for ${proc} is running:" | tee -a $VN_STATUS_FILE
            ps -ef | grep ${proc} | grep -v grep | tee -a $VN_STATUS_FILE
          else
            echo "No log file found for ${proc}.${rundate}.log" | tee -a $VN_STATUS_FILE
        fi
    fi
    echo "" | tee -a $VN_STATUS_FILE
    echo "---------------------------" | tee -a $VN_STATUS_FILE
    echo "" | tee -a $VN_STATUS_FILE
done

if [ -s $VN_STATUS_FILE ]
  then
    mail -s 'Processing status on ds1-gpmgv' kenneth.r.morris@nasa.gov \
         -c kbobmorris@hotmail.com < $VN_STATUS_FILE
    cat $VN_STATUS_FILE >> $LOG_FILE
  else
    mail -s 'Processing status missing on ds1-gpmgv' kenneth.r.morris@nasa.gov
fi

echo "See log file $LOG_FILE and status summary $VN_STATUS_FILE"

exit
