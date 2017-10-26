#!/bin/sh
################################################################################
#
#  notify_vn_status.sh     Morris/SAIC/GPM GV     June 2012
#
#  DESCRIPTION
#    Determines the status of the daily operational ingest scripts and puts
#    together and sends an e-mail message with the summary information.
#
#  HISTORY
#    11/27/13  Morris/GPM GV/SAIC
#    - Fixed bug in 'if' test for $proccount, had misspelled variable name.
#    - Moved check for still-running processes up above 'else' for
#      'if [ -s ${LOG_DIR}/${proc}.${rundate}.log ]'
#    03/13/14  Morris/GPM GV/SAIC
#    - Replaced process wgetCTdaily with GPM-era process wgetCTdailies.
#    03/23/14  Morris/GPM GV/SAIC
#    - Replaced processes getPRdata, wgetKWAJ_PR_CSI with GPM-era process
#      get_PPS_CS_data.
#    08/26/14 - Morris
#    - Changed LOG_DIR to /data/logs
#    10/12/14 - Morris
#    - Changed to only report one instance/format of a downloaded CT file.
#    - Removed check of Default QC radar files, this script is no longer
#      pertinent.
#    03/06/15 - Morris
#    - Changed to report a count-by-type of all downloaded orbit subset files
#      rather than a full listing of only downloaded GPM and TRMM files.
#    - Removed catalogRAWradar from for loop in main script to prevent it from
#      being reported as missing since it isn't run anymore.
#    09/11/15 - Morris
#    - Removed getNAMANLgrids4RainCases from for loop in main script to prevent
#      it from being reported as missing since it isn't run anymore.
#    02/01/16 - Morris
#    - Added metadata processing reporting to script.
#    06/08/16 - Morris
#    - Added ground track prediction file processing reporting to script.
#    06/30/16 - Morris
#    - Changed "cut -f3 -d '-'" to "cut -f3- -d '-'" to handle "1C-R-CS-subset"
#      filenames with the extra '-' in the beginning of the name.  Not perfect,
#      but works.
#    08/25/16 - Morris
#    - Added orbit definition file processing reporting to script.
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

LOG_DIR=/data/logs
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

     wgetCTdailies ) echo "CT file downloads and DB conversions:" | tee -a $VN_STATUS_FILE
#                     cat $1 | grep coincidence_table | grep -vE '(copy|pset)' | tee -a $VN_STATUS_FILE ;;
                     cat $1 | grep coincidence_table | grep -vE '(Got|copy|pset|unl)' | tee -a $VN_STATUS_FILE ;;

     catalogQCradar ) echo "Final QC UF Radar files cataloged: " | tee -a $VN_STATUS_FILE
                      cat $1 | grep 1CUF | tee -a $VN_STATUS_FILE ;;

#     getNAMANLgrids4RainCases ) echo "NAM/NAMANL GRIB file download status:" | tee -a $VN_STATUS_FILE
#                                cat $1 | grep finished | grep -v table | tee -a $VN_STATUS_FILE
#                                echo "" | tee -a $VN_STATUS_FILE
#                                cat $1 | grep ERROR | grep -v table | tee -a $VN_STATUS_FILE ;;

     get_PPS_CS_data ) echo "PPS Subset files download status:" | tee -a $VN_STATUS_FILE
                       for filetypes in `cat $1 | grep Got | grep -v ftp_url |  cut -f3- -d '-' \
                                        | cut -f 1-4 -d '.' | sort -u`
                         do
                           numtype=`cat $1 | grep Got | grep $filetypes | wc -l`
                           # clean up stuff in pattern after last '-' for e-mail report
                           echo "${filetypes%-*} :  Got ${numtype} files." | tee -a $VN_STATUS_FILE
                       done ;;

     RidgeMosaicCTMatch ) echo "CT table loading and RIDGE Mosaic matchups:" | tee -a $VN_STATUS_FILE
                          cat $1 | grep -i insert | tee -a $VN_STATUS_FILE
                          cat $1 | grep archivedmosaic | tee -a $VN_STATUS_FILE ;;

     get2ADPRMeta )  echo "Metadata extraction:" | tee -a $VN_STATUS_FILE
                     line1=`cat $1 | grep file2aDPRsites`   # did we generate control file(s)?
                     if [ $? = 0 ]
                       then            # if yes, then report the name(s)
                         echo $line1 | tee -a $VN_STATUS_FILE
                         # also find out if anything was produced/loaded by get2ADPRMeta4date.sh
                         yymmdd=`echo $1 | cut -f2 -d '.'`
                         metalogdir=${1%/*}
                         cat $metalogdir/get2ADPRMeta4date.$yymmdd.log | grep Calling \
                            | tee -a $VN_STATUS_FILE
                         cat $metalogdir/get2ADPRMeta4date.$yymmdd.log | grep oad \
                            | grep -v SCRIPT | tee -a $VN_STATUS_FILE
                       else            # if no Control file, then report missing CT date(s)
                         cat $1 | grep FATAL | tee -a $VN_STATUS_FILE
                     fi ;;

     wget_GT7_GPM ) echo "GPM GT prediction download and processing:" | tee -a $VN_STATUS_FILE
                          cat $1 | grep -E '(GT-7|GPM_1s)' | tee -a $VN_STATUS_FILE ;;

     wget_orbdef_GPM ) echo "GPMCORE ORBDEF download and processing:" | tee -a $VN_STATUS_FILE
                          line1=`cat $1 | grep Got`
                          if [ $? = 0 ]
                            then            # if yes, then report the name(s)
                              echo $line1 | tee -a $VN_STATUS_FILE
                            else
                              echo "No new ORBDEF files downloaded." | tee -a $VN_STATUS_FILE
                          fi ;;

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

for proc in wgetRidgeMosaic wgetCTdailies RidgeMosaicCTMatch get_PPS_CS_data \
            catalogQCradar meta_logs/get2ADPRMeta wget_GT7_GPM wget_orbdef_GPM
  do
    echo "Looking for ${proc}.${rundate}.log:" | tee -a $VN_STATUS_FILE
    if [ -s ${LOG_DIR}/${proc}.${rundate}.log ]
      then
        proccount=`ps -ef | grep ${proc} | grep -v grep | wc -l`
        if [ ${proccount} -gt 0 ]
          then
            echo "Process for ${proc} is still running:" | tee -a $VN_STATUS_FILE
            ps -ef | grep ${proc} | grep -v grep | tee -a $VN_STATUS_FILE
            echo "" | tee -a $VN_STATUS_FILE
        fi
        extract_run_info ${LOG_DIR}/${proc}.${rundate}.log
      else
        echo "No log file found for ${proc}.${rundate}.log" | tee -a $VN_STATUS_FILE
    fi
    echo "" | tee -a $VN_STATUS_FILE
    echo "---------------------------" | tee -a $VN_STATUS_FILE
    echo "" | tee -a $VN_STATUS_FILE
done

if [ -s $VN_STATUS_FILE ]
  then
    mail -s 'Processing status on ds1-gpmgv' -c "kbobmorris@hotmail.com,todd.a.berendes@nasa.gov" \
         kenneth.r.morris@nasa.gov < $VN_STATUS_FILE
    cat $VN_STATUS_FILE >> $LOG_FILE
  else
    mail -s 'Processing status missing on ds1-gpmgv' kenneth.r.morris@nasa.gov
fi

echo "See log file $LOG_FILE and status summary $VN_STATUS_FILE"

exit
