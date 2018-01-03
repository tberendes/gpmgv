#!/bin/sh

#===============================================================================
#
# catalogPRnon_mirror.sh
#
# For PR files that have been downloaded and moved into the baseline product
# subdirectories under /data/prsubsets, finds all files of a subset specified
# by the variable csi_id, parses the filenames for metadata fields needed to
# identify the product in the 'gpmgv' database, and prepares a catalog file of
# data for loading into the database by the SQL commands contained in
# catalogPRnon_mirror.sql.  The SQL ignores any duplicate files (those that
# have already been cataloged), and loads metadata for new files into the
# database table 'orbit_subset_product'.
#
#===============================================================================

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogPRnon_mirror.${rundate}.log

SQL_BIN=${BIN_DIR}/catalogPRnon_mirror.sql
loadfile=${TMP_DIR}/catalogPRdbtemp.unl
DB_LOG_FILE=${LOG_DIR}/catalogPRnon_mirrorSQL.log

# satid is the id of the instrument whose data file products are being cataloged
# and is used to identify the orbit product files' data source in the gpmgv
# database
satid="PR"

if [ -s $loadfile ]
  then
    rm $loadfile
fi

#csi_id="DARW"
#csi_id="GPM_KMA"
csi_id="KWAJ"
    # catalog the files in the database
    for type in 1C21 2A23 2A25 2B31
      do
        cd ${DATA_DIR}/prsubsets/${type}
        for file in `ls *${csi_id}*`
          do
            # Assumes all data files are Y2K and later - could be smarter (KWAJ issue?)
            dateString=`echo $file | cut -f2 -d '.' | awk \
              '{print "20"substr($1,1,2)"-"substr($1,3,2)"-"substr($1,5,2)}'`
            orbit=`echo $file | cut -f3 -d '.'`
            # handle the special case of uncompressed files from the PPS (and mess up "mirror"? !!)
            echo $file | grep "GPM_KMA" > /dev/null
            if  [ $? = 0 ]
              then
                subset=$csi_id
                version=`echo $file | cut -f4 -d '.'`
                # these files from PPS are generally uncompressed - squeeze them
                echo $file |  grep -E '(.gz$|.Z$)' > /dev/null
                if  [ $? = 1 ]
                  then
                    echo "Compressing "$file
                    gzip $file
                    file2=${file}.gz
                    file=$file2
                    echo "New file name:" `ls $file`
                fi
              else
	        temp1=`echo $file | cut -f4 -d '.'`
	        temp2=`echo $file | cut -f5 -d '.'`
	        # The product version number precedes (follows) the subset ID
	        # in the GPMGV (baseline CSI) product filenames.  Find which of
	        # temp1 and temp2 is the version number.
	        expr $temp1 + 1
	        if [ $? = 0 ]   # is $temp1 a number?
	          then
	            version=$temp1
		    subset=$temp2
	          else
	            expr $temp2 + 1
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
	    echo ${satid}'|'${orbit}'|'${type}'|'${dateString}'|'${file}'|'${subset} \
	      | tee -a $loadfile | tee -a $LOG_FILE
        done
    done

echo ""; echo "NOTE: Loading to database is disabled in script." ; exit  # uncomment for testing

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee $DB_LOG_FILE 2>&1
	if [ ! -s $DB_LOG_FILE ]
	  then
            echo "FATAL: SQL log file $DB_LOG_FILE empty or not found!"\
              | tee -a $LOG_FILE
	    echo "Saving catalog file:"
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
            exit 1
	fi
	cat $DB_LOG_FILE >> $LOG_FILE
	grep -i ERROR $DB_LOG_FILE > /dev/null
	if  [ $? = 0 ]
	  then
	    echo "Error loading file to database.  Saving catalog file:"\
	     | tee -a $LOG_FILE
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
	fi
      else
        echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
          | tee -a $LOG_FILE
	echo "Saving catalog file:"
	mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
        exit 1
    fi
  else
    echo "No new file catalog info to load to database for this run."\
     | tee -a $LOG_FILE
fi

exit
