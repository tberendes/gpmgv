#!/bin/sh

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
BIN_DIR=${GV_BASE_DIR}/scripts

# Following two variables must be the same as specified in the "package" file!
MIR_DATA_DIR=${DATA_DIR}/prsubsets
MIR_LOG_FILE=${MIR_DATA_DIR}/gpmprsubsets.log

MIR_BIN=mirror
MIR_BIN_DIR=${BIN_DIR}/mirror
# The following are specified relative to MIR_BIN_DIR, as mirror expects:
MIR_PACKAGES_DIR=packages
MIR_PACKAGE_TEMPLATE=${MIR_BIN_DIR}/${MIR_PACKAGES_DIR}/pps_gsfc_nasa_gov.template
MIR_PACKAGE=${MIR_BIN_DIR}/${MIR_PACKAGES_DIR}/pps.gsfc.nasa.gov
#MIR_PACKAGE=${MIR_BIN_DIR}/${MIR_PACKAGES_DIR}/ftppps.gsfc.nasa.gov  # testing

# prepare the filename patterns for files mirror is to consider - as either one
# or two YYMM dates, from the current year/month to the year/month 28 days ago

today=`date -u +%Y%m%d`
startdate=`offset_date $today -28`
yyyymmend=`echo $today | cut -c1-6`
yyyymmstart=`echo $startdate | cut -c1-6`
if [ `expr $yyyymmend \> $yyyymmstart` = 1 ]
  then
#    need to consider this month and last month in file patterns
     yymmstart=`echo $yyyymmstart | cut -c3-6`
     yymmend=`echo $yyyymmend | cut -c3-6`
     fp1c21=`echo "(^1C21.${yymmstart}.*|^1C21.${yymmend}.*)"`
     fp2a23=`echo "(^2A23.${yymmstart}.*|^2A23.${yymmend}.*)"`
     fp2a25=`echo "(^2A25.${yymmstart}.*|^2A25.${yymmend}.*)"`
     fp2b31=`echo "(^2B31.${yymmstart}.*|^2B31.${yymmend}.*)"`
  else
#    otherwise file pattern is just for this month
     yymmstart=`echo $yyyymmstart | cut -c3-6`
     fp1c21=`echo "(^1C21.${yymmstart}.*)"`
     fp2a23=`echo "(^2A23.${yymmstart}.*)"`
     fp2a25=`echo "(^2A25.${yymmstart}.*)"`
     fp2b31=`echo "(^2B31.${yymmstart}.*)"`
fi

echo "Pattern = $fp1c21"

# substitute the computed file patterns for the placeholders in the template
# package file, and write to the operational package file

cat $MIR_PACKAGE_TEMPLATE | sed "s/__1C21__/${fp1c21}/g" \
                          | sed "s/__2A23__/${fp2a23}/g" \
                          | sed "s/__2A25__/${fp2a25}/g" \
                          | sed "s/__2B31__/${fp2b31}/g" | tee $MIR_PACKAGE
