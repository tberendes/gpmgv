#!/bin/sh

# catalog_geo_match_products.sh

# Runs through the listing of geometry-match netcdf files in ${PRODUCT_DIR}
# directory,and formats a database table entry for 'geo_match_product' table in
# the 'gpmgv' database.  Assigns default, fixed values to table columns
# 'pr_version', 'parameter_set', 'geo_match_version', and 'num_gr_volumes' as
# specified in ${TABLE_STATIC} variable.

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data/gpmgv
PRODUCT_DIR=${DATA_DIR}/netcdf/geo_match
TMP_DIR=${DATA_DIR}/tmp
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

PPS_VERSION="V07"        # controls which PR products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="PR"
export INSTRUMENT_ID
SAT_ID="TRMM"
export SAT_ID

SQL_BIN=${BIN_DIR}/catalog_geo_match_products.sql
loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

cd $PRODUCT_DIR

if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

for ncfile in `ls GRtoPR.*${PPS_VERSION}*`
  do
    radar_id=`echo ${ncfile} | cut -f2 -d '.'`
    orbit=`echo ${ncfile} | cut -f4 -d '.'`
    GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}"
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

echo ""
cat $loadfile

echo "\i $SQL_BIN" | psql -a -d gpmgv

exit
