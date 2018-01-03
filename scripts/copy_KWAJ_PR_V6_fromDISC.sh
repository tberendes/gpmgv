#!/bin/sh

################################################################################
#
#  wgetKWAJ_PR_CSI.sh     Morris/SAIC/GPM GV     December 2008
#
#  DESCRIPTION
#    Retrieves KWAJ CSI subset PR files from DAAC site: disc2.nascom.nasa.gov.
#    Intended to be called from within the 'getPRdata.sh' script.
#    Retrieves files for a date or list of dates, as indicated by the date of
#    the script run and the status of previous runs.  Expects to get all 4 types
#    (1C21,2A23,2A25,2B31) of PR products for a given date.  If not, flags the
#    date as incomplete in the appstatus table in the gpmgv database, and tries
#    to get the missing data files in subsequent runs.  Catalogs files for
#    complete retrievals in the database and moves them into the operational
#    directory tree under /data/prsubsets.  Writes a list of cataloged files
#    into a log file 'KWAJ_PR_CSI_newfiles.yymmdd.log' to be appended to the
#    mirror.yymmdd.log file so that get2A23-25Meta.sh will extract the PR
#    metadata for the KWAJ PR CSI files as well as from those retrieved via
#    'mirror' within the original getPRdata.sh script.
#
#  ROUTINES CALLED
#    wgetPRtypes4date() - included function
#    PRproductsToDB() - included function
#
#  FILES
#
#  DATABASE
#    Catalogs data in 'orbit_subset_products' table in 'gpmgv' database in
#    PostGRESQL via call to psql utility.  Tracks status of file retrieval
#    in 'appstatus' table.
#
#  LOGS
#    1) Output for day's script run logged to daily log file
#       wgetKWAJ_PR_CSI.YYMMDD.log in data/logs subdirectory, where YYMMDD is
#       the date when the script is run.
#    2) List of retrieved files is written to the additional log file
#       KWAJ_PR_CSI_newfiles.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to
#      PostGRESQL database 'gpmgv', and INSERT privilege on table. 
#    - Utility 'psql' must be in user's $PATH.
#    - User must have write privileges in $CT_DATA, $LOG_DIR directories
#
#  HISTORY
#    December 2008 - Morris - Created.
#
################################################################################

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data/gpmgv
PR_BASE=${DATA_DIR}/prsubsets
TMP_KWAJ_DATA=${DATA_DIR}/tmp/PR_KWAJ_DAAC
BIN_DIR=${GV_BASE_DIR}/scripts
LOG_DIR=${DATA_DIR}/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/copyKWAJ_PR_CSI.${rundate}.log
LOG_DATA_FILE=${LOG_DIR}/KWAJ_PR_CSI_newfiles.${rundate}.log
PATH=${PATH}:${BIN_DIR}
ZZZ=1800

umask 0002

# re-usable file to hold output from database queries
DBTEMPFILE=${TMP_KWAJ_DATA}/dbtempfile
# file listing status of each date's download attempts
THE_SCOOP=${TMP_KWAJ_DATA}/DateStatus
rm -f $THE_SCOOP

# Constants for possible status of downloads, for appstatus table in database
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error
INCOMPLETE='I' # got fewer than all 4 PR files for an orbit

have_retries='f'  # indicates whether we have missing prior filedates to retry
status=$UNTRIED   # assume we haven't yet tried to get current file

today=`date -u +%Y%m%d`
echo "===================================================" | tee $LOG_FILE
echo " Attempting download of KWAJ CSI PR files on $today." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from wgetKWAJ_PR_CSI.sh cron job on ${thistime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications


# DEFINE FUNCTIONS

################################################################################
function wgetPRtypes4date() {

     # Use wget to download PR KWAJ subsets for each type from DAAC ftp site. 
     # Repeat attempts at intervals of $ZZZ seconds if file(s) not retrieved in
     # first attempt.  If file is still not found, record the failure in the
     # log file and do not increment $found variable.

 declare -i tries=0
 declare -i found=0
 ZZZ=1

 for type in 2A12 #1C21 2A23 2A25 2B31
   do
     runagain='y'
     while [ "$runagain" != 'n' ]
       do
          tries=tries+1
          echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE

          # select the proper directory subtree for the product type
          case $type in
                                  1C21 )  LDIR='TRMM_L1' ;;
             2A12 | 2A23 | 2A25 | 2B31 )  LDIR='TRMM_L2' ;;
                                     * )  ;;
          esac

#          wget -P $2 -N \
#            hector.gsfc.nasa.gov:/cloud/wolff/TRMM/KWAJ/V07/$1/${type}*
#          filelist4type=`ls $2/${type}*.7.HDF.gz`
          wget -P $2 -N \
            ftp://disc2.nascom.nasa.gov/data/s4pa/${LDIR}/TRMM_${type}_CSI_KWAJ/$1/${type}_CSI.$3.*.KWAJ.6.HDF.Z
          filelist4type=`ls $2/${type}_CSI.$3.*.KWAJ.6.HDF.Z`
          if [ $? = 1 ]
            then
               if [ $tries -eq 2 ]
                 then
                    runagain='n'
                    echo "Failed after 2 tries, giving up." | tee -a $LOG_FILE
                 else
                    echo "Failed to get file, sleeping $ZZZ s before next try."\
	              | tee -a $LOG_FILE
                    sleep $ZZZ
               fi
            else
               runagain='n'
               found=found+1
          fi
     done
     tries=0
     #sleep 2
 done
 return $found
}
################################################################################
function PRproductsToDB() {

   # satid is the id of the instrument whose data file products are being
   # mirrored and is used to identify the orbit product files' data source
   # in the gpmgv database
    satid="PR"

   # catalog the files in the database - need separate logic for the GPM_KMA
   # subset files, as they have a different naming convention
    for type in 2A12 #1C21 2A23 2A25 2B31
      do
        for file in `ls ${type}*.$1*`
          do
           #  Check for presence of downloaded files, process if any
	    if [ -s  $2/${type}/${file} ]
	      then
	        echo "File $2/${type}/${file} already exists.  Skip cataloging."\
		  | tee -a $LOG_FILE 2>&1
		rm -v ${file}  | tee -a $LOG_FILE 2>&1
            else
	        dateString=`echo $file | cut -f2 -d '.' | awk \
                  '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
#                  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
                orbit=`echo $file | cut -f3 -d '.'`
                echo $file | grep "GPM_KMA" > /dev/null
                if  [ $? = 0 ]
                  then
                    subset='GPM_KMA'
                    version=`echo $file | cut -f4 -d '.'`
                  else
	            temp1=`echo $file | cut -f4 -d '.'`
	            temp2=`echo $file | cut -f5 -d '.'`
	            # The product version number precedes (follows) the subset ID
	            # in the GPMGV (baseline CSI) product filenames.  Find which of
	            # temp1 and temp2 is the version number.
	            expr $temp1 + 1 > /dev/null 2>&1
	            if [ $? = 0 ]   # is $temp1 a number?
	              then
	                version=$temp1
		        subset=$temp2
	              else
	                expr $temp2 + 1 > /dev/null 2>&1
		        if [ $? = 0 ]   # is $temp2 a number?
		          then
		            subset=$temp1
		            version=$temp2
		          else
		            echo "Cannot find version number in PR filename: $file"\
		              | tee -a $LOG_FILE
		            exit 2
	    	        fi
	            fi
                fi
	        echo "subset ID = $subset" | tee -a $LOG_FILE
                #echo "file = ${file}, dbdate = ${dateString}, orbit = $orbit"
	        echo "INSERT INTO orbit_subset_product VALUES \
		 ('${satid}',${orbit},'${type}','${dateString}','${file}','${subset}',${version});" \
	         | psql -a -d gpmgv  | tee -a $LOG_FILE 2>&1
	       # move file into the baseline PR product directory
	        mv -v $file $2/${type} | tee -a $LOG_FILE
	       # tally the PR file in the data log file - filename must be 2nd 'word'
	       # to match the mirror log file to which data log will be appended
	        echo "Got $file" | tee -a $3
               echo "" | tee -a $LOG_FILE
	    fi
        done
    done
    return
}
################################################################################

# BEGIN MAIN SCRIPT

cd $TMP_KWAJ_DATA

echo "Getting KWAJ CSI files." | tee -a $LOG_FILE
#for year in 2008 2009 2010
for year in 2008
  do
#    for month in 01 02 03 04 05 06 07 08 09 10 11 12
    for month in 07
      do
        ndays=`monthdays $year $month`
        case $ndays in
          28 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28' ;;
          29 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29' ;;
          30 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30' ;;
          31 )  days='01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31' ;;
           * )  ;;
        esac
days='11'
        for day in `echo $days`
          do
            ctdate=$year$month$day

            #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
            julctdate=`ymd2yd $ctdate`

            #  Get the subdirectory on the ftp site under which our day's data are located,
            #  in the format YYYY/jjj
            jdaydir=`echo $julctdate | awk '{print substr($1,1,4)"/"substr($1,5,3)}'`
            echo "Get files for ${jdaydir} from ftp site." | tee -a $LOG_FILE

            #  Trim date string to use a 2-digit year, as in filename convention
            yymmdd=`echo $ctdate | cut -c 3-8`

            echo "" | tee -a $LOG_FILE

            wgetPRtypes4date $jdaydir $TMP_KWAJ_DATA $yymmdd
#        if [ $? -eq 4 ]
            if [ $? -eq 1 ]
              then
                echo "Got all 4 types for $yymmdd"
                echo "Mark success in database:" | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
	        echo "UPDATE appstatus SET status = '$SUCCESS' WHERE \
	          app_id = 'wgetKWAJ' AND datestamp = '$yymmdd';" \
		  | tee -a $LOG_FILE 2>&1
                # Move the files into the baseline product directories
                # and catalog them in the database.
                echo "" | tee -a $LOG_FILE
                echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" | tee -a $LOG_FILE
                PRproductsToDB $yymmdd $PR_BASE $LOG_DATA_FILE
                echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%" | tee -a $LOG_FILE
            else
                echo "" | tee -a $LOG_FILE
                echo "Only got $? of the 4 types for $yymmdd" | tee -a $LOG_FILE
            fi
        done
    done
done


echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
