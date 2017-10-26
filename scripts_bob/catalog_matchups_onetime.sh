#!/bin/sh

GV_BASE_DIR=/home/morris/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv
export DATA_DIR
TMP_DIR=/data/tmp
export TMP_DIR
LOG_DIR=/data/logs
export LOG_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION=V03A        # controls which GMI products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2tmi parameters (polar2tmi.bat file) in use
export PARAMETER_SET
MAX_DIST=250  # max radar-to-subtrack distance for overlap

# set ids of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="TMI"
export INSTRUMENT_ID
SAT_ID="TRMM"
export SAT_ID
ALGORITHM="2AGPROF"
export ALGORITHM

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2tmi procedure, as
# listed in the do_GMI_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_GMI_geo_matchup4date.sh by examining the do_GMI_geo_matchup4date.yymmdd.log 
# file. Formats catalog entry for the geo_match_product table in the gpmgv
# database, and loads the entries to the database.

YYMMDD=$1
DBCATALOGFILE=$2
SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql
echo "Cataloging new matchup files listed in $DBCATALOGFILE"
# this same file is used in catalog_geo_match_products.sh and is also defined
# this way in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the name or format must be coordinated in all 3 files.

loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

for ncfile in `cat $DBCATALOGFILE`
  do
    radar_id=`echo ${ncfile} | cut -f4 -d '.'`
    orbit=`echo ${ncfile} | cut -f6 -d '.'`
    PR_VERSION=`echo ${ncfile} | cut -f7 -d '.'`
   # GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|1.0|1|${INSTRUMENT_ID}|PR"
    gzfile=`ls ${ncfile}\.gz`
    if [ $? = 0 ]
      then
        echo "Found $gzfile" | tee -a $LOG_FILE
        rowdata="${rowpre}${gzfile}${rowpost}"
        echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
      else
        echo "Didn't find gzip version of $ncfile" | tee -a $LOG_FILE
        ungzfile=`ls ${ncfile}`
        if [ $? = 0 ]
          then
            echo "Found $ungzfile" | tee -a $LOG_FILE
            rowdata="${rowpre}${ungzfile}${rowpost}"
            echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
        fi
    fi
done

if [ -s $loadfile ]
  then
   # load the rows to the database
    echo "\i $SQL_BIN2" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
fi

return
}
################################################################################

# Begin main script

yymmdd=$1

           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_GMI_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE, quitting!"\
	         | tee -a $LOG_FILE
#                exit 1
            fi
exit
