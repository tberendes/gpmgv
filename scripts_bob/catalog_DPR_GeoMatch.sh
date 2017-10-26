#!/bin/sh
###############################################################################
#
# catalog_DPR_GeoMatch.sh    Morris/SAIC/GPM GV    Sep 2015
#
# Wrapper to catalog DPR-GV NetCDF geometric matchups for existing files
# already produced but not in database, using the temp files $DBCATALOGFILE
# from the script do_DPR_GeoMatch.sh.  Used for case where database entries
# were lost.
#
###############################################################################


USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
  else
    if [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
      else
        echo "User unknown, can't set GV_BASE_DIR!"
        exit 1
    fi
fi
echo "GV_BASE_DIR: $GV_BASE_DIR"
export GV_BASE_DIR

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

LOG_DIR=/data/logs
export LOG_DIR
TMP_DIR=/data/tmp
export TMP_DIR
#GEO_NC_DIR=${DATA_DIR}/netcdf/geo_match
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
#INSTRUMENT_ID="DPR"
#export INSTRUMENT_ID
#SAT_ID="GPM"
#export SAT_ID

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/catalog_DPR_GeoMatch.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2dpr procedure, as
# listed in the do_DPR_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_DPR_geo_matchup4date.sh by examining the do_DPR_geo_matchup4date.yymmdd.log file. 
# Formats catalog entry for the geo_match_product table in the gpmgv database,
# and loads the entries to the database.

YYMMDD=$1
MATCHUP_LOG=${LOG_DIR}/do_DPR_geo_matchup4date.${YYMMDD}.log  # NOT USED
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
    radar_id=`echo ${ncfile} | cut -f2 -d '.'`
    orbit=`echo ${ncfile} | cut -f4 -d '.'`
    PPS_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
    GEO_MATCH_VERSION=`echo ${ncfile} | cut -f8 -d '.' | sed 's/_/./'`
    INSTRUMENT_ID_FILE=`echo ${ncfile} | cut -f6 -d '.'`
    case $INSTRUMENT_ID_FILE
      in
        DPR)  INSTRUMENT_ID=DPR ;;
         KA)  INSTRUMENT_ID=Ka ;;
         KU)  INSTRUMENT_ID=Ku ;;
          *)  echo "Undefined INSTRUMENT_ID name match: $INSTRUMENT_ID_FILE" \
              | tee -a $LOG_FILE
              echo "Exiting with error." | tee -a $LOG_FILE
              exit 1 ;;
    esac
    SAT_ID=`echo ${ncfile} | cut -f6 -d '/'`
    SWATH=`echo ${ncfile} | cut -f7 -d '.'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}|${SWATH}"
    gzfile=`ls ${ncfile}`
    if [ $? = 0 ]
      then
        echo "Found $gzfile" | tee -a $LOG_FILE
        rowdata="${rowpre}${gzfile}${rowpost}"
        echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
      else
        echo "Didn't find gzip version of $ncfile" | tee -a $LOG_FILE
        ungzfile=`ls ${ncfile} | sed 's/.gz//'`
        if [ $? = 0 ]
          then
            echo "Found $ungzfile" | tee -a $LOG_FILE
            rowdata="${rowpre}${ungzfile}${rowpost}"
            echo $rowdata | tee -a $loadfile | tee -a $LOG_FILE
            echo ""  | tee -a $loadfile | tee -a $LOG_FILE
        fi
    fi
done

if [ -s $loadfile ]
  then
   # load the rows to the database
    echo "\i $SQL_BIN2" | psql -a -d gpmgv >> $LOG_FILE 2>&1
    tail $LOG_FILE | grep INSERT
#    echo ""
#    echo "LOADFILE:"
#    cat $loadfile
#    echo ""
fi

return
}
################################################################################

# Begin main script

echo "Catalog matchup netCDF generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""

ls /data/gpmgv/netcdf/geo_match/GPM/2AKu/NS/V03B/1_1/2015/* > ${TMP_DIR}/do_DPR_geo_matchup_catalog.temp.txt

for DBCATALOGFILE in `ls ${TMP_DIR}/do_DPR_geo_matchup_catalog.temp.txt`
  do
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $rundate $DBCATALOGFILE
              else
                echo "No matchup files listed in $DBCATALOGFILE !"\
                 | tee -a $LOG_FILE
                ls -al $DBCATALOGFILE
            fi
done

exit
