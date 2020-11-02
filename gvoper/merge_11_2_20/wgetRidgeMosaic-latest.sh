#!/bin/sh
################################################################################
#
#  wgetRidgeMosaic-latest.sh     Morris/SAIC/GPM GV     August 2006
#
#  DESCRIPTION
#    Retrieves latest CONUS radar mosaic file 'latest.gif' from NWS site:
#
#       http://radar.weather.gov/ridge/Conus/RadarImg/latest.gif
#
#    Files are posted every 10 minutes, overwriting the previous latest.gif file
#    on the web page.  File contains no time information other than the file
#    time stamp, and the date/time burned into the image (unavailable except by
#    viewing). File data time as indicated in the image is about 3 minutes
#    earlier than file modification time.  We will rename the latest.gif file,
#    using the date/time as the filename to make it unique and time-manipulable.
#    The new filenames and their modification datetime values are written into
#    the PostGRESQL database 'temp' table 'heldmosaic', to facilitate later
#    time matchup to the TRMM Coincidence Table data in table 'ct_temp'.
#
#    If PostGRESQL is not up, an e-mail notification of the condition is sent,
#    and the file name and time fields are written to a temporary flat file.
#    Once the database is restarted, the data from the flat file are loaded to
#    the database and the temp file is deleted if the load is successful.
#
#  FILES
#    latest.gif - Reflectivity mosaic file retrieved from NWS web site.  Nominal
#                 time of data as burned into image is about 3 min earlier 
#                 than modification time of the file itself.
#
#    YYYY-Mon-DD_HH:MM.gif - Renamed latest.gif file, with date/time derived
#                            from file modification time.
#                     
#  DATABASE
#    Loads data into 'heldmosaic' table in 'gpmgv' database in PostGRESQL via
#    call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    wgetRidgeMosaic.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', and INSERT privilege on table "heldmosaic".  Utility
#    'psql' must be in user's $PATH.
#    - User must have write privileges in $MOSAIC_DATA, $LOG_DIR directories
#
#  HISTORY
#    November 2013 - Morris - Using >> rather than "| tee -a" to capture any
#                             psql error output in INSERT query.
#    January 2014  - Morris - Added 'export TZ=UTC' command to force 'ls' to
#                             show times in UTC rather than local time.  Has
#                             been messing up file timestamping for ages.
#    August 2014   - Morris - Changed LOG_DIR to /data/logs, TMP_DIR to /data/tmp
#                           - Changed download directories to be under
#                             /data/tmp/mosaicimages
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

GV_BASE_DIR=/home/gvoper
DATA_DIR=/data/gpmgv
TMP_DIR=/data/tmp
#MOSAIC_BASE_DATA=${DATA_DIR}/mosaicimages  # no longer used here
MOSAIC_TMP_DATA=${TMP_DIR}/mosaicimages
MOSAIC_DATA_HOLD=${MOSAIC_TMP_DATA}/holding
MOSAIC_DATA=${MOSAIC_TMP_DATA}/radar.weather.gov/ridge/Conus/RadarImg
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
TMP_DIR=/data/tmp
HELDTEMPFILE=${TMP_DIR}/wgetRidgeMosaic_dbtempfile
LOG_DIR=/data/logs
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/wgetRidgeMosaic.${rundate}.log
runtime=`date -u`
DBERRMSG_FILE=/tmp/PG_MAIL_ERROR_MSG_RIDGEMOS.txt
umask 0002
export TZ=UTC

echo "===================================================" | tee -a $LOG_FILE
echo " Attempting download of Ridge mosaic file on $runtime." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

db_up='y'
pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    db_up='n'
    echo "Database server down. Trying to restart postgresql." \
      | tee -a $LOG_FILE
    sudo /etc/init.d/postgresql start | tee -a $LOG_FILE 2>&1
    sleep 10
    pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`
    if [ ${pgproccount} -lt 3 ]
      then
        if [ ! -f $DBERRMSG_FILE ]
          then
            echo "Message from wgetRidgeMosaic-latest.sh cron job on ${runtime}:" \
              > $DBERRMSG_FILE
            echo "" >> $DBERRMSG_FILE
            echo "${pgproccount} Postgres processes active, should be >= 3 !!" \
              >> $DBERRMSG_FILE
            echo "UNABLE TO RESTART POSTGRESQL ON ds1-gpmgv." >> $DBERRMSG_FILE
	    # \ makofski@radar.gsfc.nasa.gov -c
            mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
                  -c kenneth.r.morris@nasa.gov < $DBERRMSG_FILE
            cat $DBERRMSG_FILE | tee -a $LOG_FILE
          else
	    echo "${pgproccount} Postgres processes active, should be >= 3." \
             | tee -a $LOG_FILE
        fi
      else
        db_up='y'
        echo "Message from wgetRidgeMosaic-latest.sh cron job on ${runtime}:" \
          > $DBERRMSG_FILE
        echo "" >> $DBERRMSG_FILE
        echo "${pgproccount} Postgres processes active, should be >= 3" \
          >> $DBERRMSG_FILE
        echo "NOTE: HAD TO RESTART POSTGRESQL ON ds1-gpmgv." >> $DBERRMSG_FILE
        mailx -s 'postgresql restart on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
              -c kenneth.r.morris@nasa.gov < $DBERRMSG_FILE
        cat $DBERRMSG_FILE | tee -a $LOG_FILE
    fi
  else
    #echo "${pgproccount} Postgres processes active, should be 3." \
    #  | tee -a $LOG_FILE
    #echo "" | tee -a $LOG_FILE
    # Recover from prior database error condition
    if [ -s $HELDTEMPFILE ]
      then
        echo "Postgresql database is back up!" | tee -a $LOG_FILE
	echo "Need to load filenames in temp file to database:" \
         | tee -a $LOG_FILE
        # load the data into the 'metadata_temp' table
        DBOUT=`psql -q -d gpmgv -c "\copy heldmosaic FROM '${HELDTEMPFILE}'\
         WITH DELIMITER '|'" 2>&1`
        echo $DBOUT | tee -a $LOG_FILE  
        echo "" | tee -a $LOG_FILE
        echo $DBOUT | grep -E '(ERROR)' > /dev/null
        
	if [ $? = 0 ]
          then
            db_up='n'
	    echo $DBOUT | tee -a $LOG_FILE
	    echo "" | tee -a $LOG_FILE
            echo "Message from wgetRidgeMosaic-latest.sh on ${runtime}:" \
              > $DBERRMSG_FILE
	    echo "FATAL: Could not load data from ${HELDTEMPFILE} to database!"\
	      >> $DBERRMSG_FILE
            echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> $DBERRMSG_FILE
            mailx -s 'postgresql error on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
                  -c kenneth.r.morris@nasa.gov < $DBERRMSG_FILE
            cat $DBERRMSG_FILE | tee -a $LOG_FILE
          else
	    echo "Removing temp file ${HELDTEMPFILE}:" | tee -a $LOG_FILE
	    rm -v ${HELDTEMPFILE} | tee -a $LOG_FILE
            if [ -f $DBERRMSG_FILE ]
              then
                rm -v $DBERRMSG_FILE | tee -a $LOG_FILE
            fi
	fi
    fi
fi
#exit  #uncomment for just testing e-mail notifications

cd ${MOSAIC_TMP_DATA}

# Directory $MOSAIC_DATA will not exist 1st time, so skip check in this case.
if [ -d ${MOSAIC_DATA} ]
  then
     numfound=`ls ${MOSAIC_DATA}/latest*.* | wc -l`
     if [ `expr $numfound \> 1` = 1 ]
       then
          echo "$numfound leftover latest.gif file(s) found in" \
            | tee -a $LOG_FILE
          echo "directory ${MOSAIC_DATA}" | tee -a $LOG_FILE
          echo "at beginning of script run, deleting all:" | tee -a $LOG_FILE
          rm -fv ${MOSAIC_DATA}/latest*.*  | tee -a $LOG_FILE
          echo "" | tee -a $LOG_FILE
     fi
fi

# do the download

/usr/bin/wget --tries=1 --mirror -P ${MOSAIC_TMP_DATA} \
   http://radar.weather.gov/ridge/Conus/RadarImg/latest.gif

numfound=`ls ${MOSAIC_DATA}/latest*.* | wc -l`

if [ `expr $numfound = 1` = 1 ]
  then
     # have one and only one latest.gif file in download, rename, check, and
     # copy to holding directory if new data time
     time=`ls -l --time-style='+%Y-%m-%d %H:%M' ${MOSAIC_DATA} \
       | sed 's/  */ /g' | cut -f 6-7 -d ' ' | awk 'NR==2 {print $1, $2}'`
     name=`echo ${time} | awk '{print $1"_"$2".gif"}' | sed 's/://'`
     echo "time, name = $time , $name"  | tee -a $LOG_FILE
     if [ -s ${MOSAIC_DATA_HOLD}/${name} ]
       then
          echo "Already have ${name}, skipping."  | tee -a $LOG_FILE
       else
          echo "Copying latest.gif to:" | tee -a $LOG_FILE
          echo "  ${MOSAIC_DATA_HOLD}/${name}"  | tee -a $LOG_FILE
          cp ${MOSAIC_DATA}/latest.gif ${MOSAIC_DATA_HOLD}/${name}
	  if [ $db_up = 'y' ]
	    then
              echo "Copying metadata to test database:"  | tee -a $LOG_FILE
              echo "insert into heldmosaic values( '$time', '$name' );" \
                |  psql -a -d gpmgv >> $LOG_FILE 2>&1
	    else
	      echo "DB down, copying metadata to temp file:"  | tee -a $LOG_FILE
	      echo ${time}'|'${name} | tee -a $HELDTEMPFILE | tee -a $LOG_FILE
	  fi
     fi
  else
     echo "No latest.gif file in ${MOSAIC_DATA}," | tee -a $LOG_FILE
     echo "download failed." | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE

exit
