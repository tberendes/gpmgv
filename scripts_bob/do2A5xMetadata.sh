#!/bin/sh
###############################################################################
#
# do2A5xMetadata.sh    Morris/SAIC/GPM GV    April 2011
#
# Wrapper to do metadata extraction from 2A-53 and 2A-54 files for all matching
# 1C21/2A25 files already received and cataloged.
#
###############################################################################

USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
    IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/getmetadata
  else
    if [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
        IDL_PRO_DIR=${GV_BASE_DIR}/idl
      else
        echo "User unknown, can't set GV_BASE_DIR!"
        exit 1
    fi
fi
echo "GV_BASE_DIR: $GV_BASE_DIR"
BIN_DIR=${GV_BASE_DIR}/scripts
export IDL_PRO_DIR                 # IDL do_2a5354_metadata.bat needs this
IDL=/usr/local/bin/idl

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

LOG_DIR=${DATA_DIR}/logs
META_LOG_DIR=${LOG_DIR}/meta_logs

umask 0002

# satid is the id of the instrument whose data file products are being mirrored
# and is used to identify the orbit product files' data source in the gpmgv
# database
#satid="PR"

#rundate=`date -u +%y%m%d`
rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${META_LOG_DIR}/do2A5xMetadata.${rundate}.log
export rundate

umask 0002

echo "Starting metadata extract run for PR subsets for $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

datelist=${DATA_DIR}/tmp/doAllGrid_dates_temp.txt
# find the last orbit with complete GV metadata, and start 150 orbits back from
# that to find days to (re)process
echo "\t \a \f '|' \o $datelist \
  \\\select max(orbit) as maxorbit into temp maxgvmetaorbit\
     from overpass_event o where 3 = (select count(*) from event_meta_numeric\
     where event_num=o.event_num and metadata_id>500000);\
   select distinct a.filedate from orbit_subset_product a,\
     orbit_subset_product b, overpass_event c where a.orbit=b.orbit\
     and b.orbit = c.orbit and a.subset=b.subset and a.version=b.version\
     and a.version=7 and a.product_type='1C21' and b.product_type = '2A25'\
     and a.subset = 'sub-GPMGV1' AND A.ORBIT>(select maxorbit-150 from maxgvmetaorbit)\
     and 3 > (select count(*) from event_meta_numeric\
       where event_num=c.event_num and metadata_id>500000) \
     order by filedate;" | psql -q gpmgv | tee -a $LOG_FILE 2>&1

for thisdate in `cat $datelist`
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
   # files to hold the delimited output from the database queries comprising the
   # control files for the 1C21/2A25 grid creation in the IDL routines:
   # 'outfile' gets overwritten each time psql is called in the loop over the new
   # dates, so its output is copied in append manner to 'outfileall', which
   # is run-date-specific.
    filelist=${DATA_DIR}/tmp/PR_filelist4gvMeta_temp.txt
    outfile=${DATA_DIR}/tmp/PR_files_sites4gvMeta_temp.txt
    outfileall=${DATA_DIR}/tmp/PR_files_sites4gvMeta.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

    # Get a listing of 1C21/2A25 files to be matched, put in file $filelist
    # Ideally we'd check against TMI 2A12, but the View SQL doesn't include it
    # - using version 7 in query now that v6 is no longer coming in
    echo "\t \a \f '|' \o $filelist \
         \\\ select file1c21, file2a25, orbit, subset, count(*) from collatedPRproductswsub\
         where cast(nominal at time zone 'UTC' as date) = '${thisdate}'\
         and file1c21 is not null and version=7 and subset = 'sub-GPMGV1'\
         group by file1c21, file2a25, orbit, subset\
         order by orbit;" | psql gpmgv  | tee -a $LOG_FILE 2>&1

    # - Prepare the control file for IDL to do 2A53-54 metadata extraction.

    for row in `cat $filelist`
      do
        orbit=`echo $row | cut -f3 -d '|'`
        subset=`echo $row | cut -f4 -d '|'`
        echo "\t \a \f '|' \o $outfile \\\ select a.event_num, a.radar_id, \
          extract(EPOCH from a.overpass_time), b.latitude, b.longitude, \
          COALESCE(c.file2a53, 'no_2A53_file'), COALESCE(c.file2a54, 'no_2A54_file') \
        from overpass_event a, fixed_instrument_location b, \
          collatedgvproducts c \
        where a.radar_id = b.instrument_id and a.radar_id = c.radar_id and \
          a.orbit = c.orbit and a.orbit = ${orbit} and c.subset='${subset}';" | psql gpmgv \
           | tee -a $LOG_FILE 2>&1

        echo ""  | tee -a $LOG_FILE
        echo "Orbit overpass files/site:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
       # copy the temp file outputs from psql to the daily control file
        echo $row | tee -a $outfileall  | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall  | tee -a $LOG_FILE
    done

#exit

    if [ -s $outfileall ]
      then
        # Call IDL to run the do_2a5354_metadata.bat file.
        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_2a5354_metadata.bat in IDL on $start1" | tee -a $LOG_FILE
        GVMETACONTROL=$outfileall
        export GVMETACONTROL
        DBOUTFILE=${DATA_DIR}/tmp/gvMetadata.${yymmdd}.unl
        export DBOUTFILE
        if [ -f $DBOUTFILE ]
          then
            rm -v $DBOUTFILE
        fi
        echo "Control file: $GVMETACONTROL"
        echo "Database load file: $DBOUTFILE"
        echo "" | tee -a $LOG_FILE
        
        $IDL < ${IDL_PRO_DIR}/do_2a5354_metadata.bat | tee -a $LOG_FILE 2>&1
	
        echo "=============================================" | tee -a $LOG_FILE

        if [ -s $DBOUTFILE ]
          then
            echo "SUCCESS from IDL do_2a5354_metadata for ${yymmdd}"\
        	 | tee -a $LOG_FILE

           # load the data into the 'metadata_temp' table
            DBOUT=`psql -q -d gpmgv -c "\copy metadata_temp FROM '${DBOUTFILE}'\
              WITH DELIMITER '|'" 2>&1`
#           echo $DBOUT | tee -a $LOG_FILE  
#           echo "" | tee -a $LOG_FILE
            echo $DBOUT | grep -E '(ERROR)' > /dev/null
            if [ $? = 0 ]
              then
                echo $DBOUT | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
	        echo "FATAL: Could not load data from ${DBOUTFILE} to database!"\
	         | tee -a $LOG_FILE
                exit 1
            else
                DBOUT=`psql -q -t -d gpmgv -c "SELECT count(*) FROM metadata_temp;"`
	        echo "$DBOUT rows loaded." | tee -a $LOG_FILE
	        echo "" | tee -a $LOG_FILE
	        echo "Move metadata to permanent table event_meta_numeric,"\
	         | tee -a $LOG_FILE
	        echo "where not duplicate of existing data:" | tee -a $LOG_FILE
	        echo "" | tee -a $LOG_FILE
                echo "INSERT INTO event_meta_numeric \
SELECT t.* FROM metadata_temp t WHERE NOT EXISTS \
(SELECT * FROM event_meta_numeric p WHERE p.event_num = t.event_num \
AND p.metadata_id = t.metadata_id) and value != -999;
DELETE FROM metadata_temp;" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
            fi
        else
            echo "FAILURE extracting GV metadata in IDL for ${yymmdd}" | tee -a $LOG_FILE
            exit 1
        fi
        echo "" | tee -a $LOG_FILE
        end=`date -u`
        echo "GV metadata processing for $yymmdd completed on $end."\
        | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
        rm -v $DBOUTFILE
        sleep 1
        echo "" | tee -a $LOG_FILE
        echo "=================================================================="\
        | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
    fi

done

echo "See log file: $LOG_FILE"

exit
