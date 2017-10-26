#!/bin/sh

# catalog_geo_match_products.sh

# Runs through the listing of geometry-match netcdf files in ${PRODUCT_DIR}
# directory,and formats a database table entry for 'geo_match_product' table in
# the 'gpmgv' database.  Assigns default, fixed values to table columns
# 'pr_version', 'parameter_set', 'geo_match_version', and 'num_gr_volumes' as
# specified in ${TABLE_STATIC} variable.
#

echo "NO LONGER APPLIES AS THE STRUCTURE OF THE MATCHUP FILE DIRECTORIES"
echo "HAS CHANGED TO BE SATELLITE/PRODUCT/VERSION/YEAR SPECIFIC !
exit 0

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data/gpmgv
PRODUCT_DIR=${DATA_DIR}/netcdf/geo_match
TMP_DIR=${DATA_DIR}/tmp
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

SQL_BIN=${BIN_DIR}/catalog_geo_match_products.sql
loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
TABLE_STATIC='6|0|1.0|1'
cd $PRODUCT_DIR

if [ -f $loadfile ]
  then
    rm -v $loadfile
fi

for ncfile in `ls GRtoPR.*`
  do
    site=`echo $ncfile | cut -f2 -d '.'`
    orbit=`echo $ncfile | cut -f4 -d '.'`
    rowdata="${site}|${orbit}|${PRODUCT_DIR}/${ncfile}|${TABLE_STATIC}"
    echo $rowdata >> $loadfile
done

echo ""
cat $loadfile

#DBOUT=`psql -a -d gpmgv -c "\copy geo_match_product FROM '${loadfile}' WITH DELIMITER '|'"`
#echo $DBOUT
echo "\i $SQL_BIN" | psql -a -d gpmgv

exit
