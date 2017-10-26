#!/bin/sh
###############################################################################
#
# do_DPRGMI_GeoMatch_from_ControlFiles.sh    Morris/SAIC/GPM GV    July 2016
#
# DESCRIPTION:
# -----------
# When the script do_DPRGMI_GeoMatch.sh is run with the '-c' option, it will
# query the gpmgv database for dates/times of rainy DPR or GR events and write
# daily control files used as input to do the DPRGMI-GR geometry matching for
# events with data, but will stop short of doing the actual matchups.  This
# script will look at a series of these control files for a range of dates
# internally defined by 'dateStart' and 'dateEnd', locate the matching control
# files for the $SAT_ID/$ALGORITHM/$PPS_VERSION and date combination, and
# for each such control file, will call do_DPRGMI_geo_matchup4date.sh which
# then runs IDL to do the GR/DPRGMI matchups.  This mode allows more than one
# IDL matchup process to run at a time, on the same host or a different host,
# against a set of non-overlapping dates. This is useful to speed up
# reprocessing a complete set of matchups for a new version of GPM or ground
# radar data.
#
# Completed geometry match files are cataloged in a delimited text file that
# can be loaded into the 'gpmgv' database table 'geo_match_product', present
# on ds1-gpmgv.  This file is written to in append mode in the function
# catalog_to_db() contained in this script file, so it always grows until it is
# manually deleted, hopefully following a successful manual loading to the
# database.  Unlike in other scripts, catalog_to_db() only prepares the data to
# load to the database, and does not do the actual loading step.  This allows
# this script to be run on a 2nd machine that does not have database access.
# See SQL_BIN2 in the catalog_to_db() documentation.
#
#
# SYNOPSIS
# --------
#
#    do_DPRGMI_GeoMatch_from_ControlFiles.sh [OPTION]...
#
#
#    OPTIONS/ARGUMENTS:
#    -----------------
#    -v PPS_VERSION         Override default PPS_VERSION to the specified PPS_VERSION.
#                           This determines which version of the 2B product will be
#                           processed in the matchups.  STRING type.
#
#    -p PARAMETER_SET       Override default PARAMETER_SET to the specified PARAMETER_SET
#                           This tracks which version of IDL batch file was used in
#                           processing matchups, when changes are made to the batch file.
#                           This value does not actually control anything, but it gets
#                           written to the geo_match_product table in the gpmgv database
#                           as a descriptive attribute.  It is up to the user to keep
#                           track of its use and meaning.  INTEGER type.
#
#    -m GEO_MATCH_VERSION   Override default GEO_MATCH_VERSION to the specified
#                           GEO_MATCH_VERSION.  This only changes if the IDL code that
#                           produces the output netCDF file now produces a new or
#                           different version of the matchup file.  If the value of
#                           GEO_MATCH_VERSION is not the same as the version encoded in
#                           the output netCDF filename a fatal error occurs.  FLOAT type.
#
#    -f                     If specified, then instruct matchup programs to create
#                           and overwrite any existing matchups for a date even if
#                           the database says they have been run already (see NOTE).
#                           Takes no argument value.
#
#    -r                     If specified, then configure to run matchups to RHI
#                           ground radar scans instead of the default PPI scans.
#                           This capability is not yet supported, so this option
#                           has no effect on the output.  Script will gracefully
#                           exit if it is specified.
#
#
# HISTORY
#
# 7/13/2016   Morris         Created from do_DPRGMI_GeoMatch.sh.
#
###############################################################################

HOME_DIR=/home/morris
GV_BASE_DIR=${HOME_DIR}/swdev
export GV_BASE_DIR
DATA_DIR=/data/gpmgv   # not used here or in do_DPRGMI_geo_matchup4date.sh?
export DATA_DIR
TMP_DIR=${HOME_DIR}/data/tmp
export TMP_DIR
LOG_DIR=${HOME_DIR}/data/logs
export LOG_DIR
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR

PPS_VERSION=V04A        # controls which DPRGMI products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2tmi parameters (polar2tmi.bat file) in use
export PARAMETER_SET

# set ids of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
INSTRUMENT_ID="DPRGMI"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
ALGORITHM="2BDPRGMI"
export ALGORITHM
GEO_MATCH_VERSION=1.3
export GEO_MATCH_VERSION

FORCE_MATCH=0    # if 1, ignore appstatus for date(s) and (re)run matchups
DO_RHI=0         # if 1, then matchup to RHI UF files -- CURRENTLY IGNORED

# override coded defaults with user-specified values
while getopts v:p:m:fr option
  do
    case "${option}"
      in
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
        f) FORCE_MATCH=1;;
        r) DO_RHI=1
    esac
done

echo "FORCE_MATCH: $FORCE_MATCH"
echo "DO_RHI: $DO_RHI"


rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/doDPRGMIGeoMatch4NewRainCases.${PPS_VERSION}.${rundate}.log

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2dprgmi procedure, as
# listed in the do_DPRGMI_geo_matchup_catalog.yymmdd.txt file, in turn produced
# by do_DPRGMI_geo_matchup4date.sh by examining the
# do_DPRGMI_geo_matchup4date.yymmdd.log  file. Formats catalog entry for the
# geo_match_product table in the gpmgv database, and loads the entries to the
# database.

YYMMDD=$1
DBCATALOGFILE=$2

# We don't actually call psql to run the following SQL command file to do the
# loading to the database, this is left as a manual step since this script may
# be running on a machine that doesn't have access to the database.
# SQL_BIN2=${BIN_DIR}/catalog_geo_match_products.sql

echo "Cataloging new matchup files listed in $DBCATALOGFILE"
# this same file is used in catalog_geo_match_products.sh and is also defined
# this way in catalog_geo_match_products.sql, which both scripts execute under
# psql.  Any changes to the name or format must be coordinated in all 3 files.

loadfile=${TMP_DIR}/catalogGeoMatchProducts.unl
if [ -f $loadfile ]
  then
    echo "loadfile before catalog_to_db()" | tee -a $LOG_FILE
    ls -al $loadfile | tee -a $LOG_FILE
fi

for ncfile in `cat $DBCATALOGFILE`
  do
    radar_id=`echo ${ncfile} | cut -f2 -d '.'`
    orbit=`echo ${ncfile} | cut -f4 -d '.'`
    PR_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
#    GEO_MATCH_VERSION=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|1.0|1|${INSTRUMENT_ID}|${SAT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}|NA"
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
   echo "loadfile after catalog_to_db()" | tee -a $LOG_FILE
   ls -al $loadfile | tee -a $LOG_FILE
fi

return
}
################################################################################

# Begin main script
echo "Starting COMB-GR matchups on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

CTL_DIR=${DATA_DIR}/netcdf/geo_match/$SAT_ID/$ALGORITHM/$PPS_VERSION/CONTROL_FILES
export CTL_DIR
echo "" | tee -a $LOG_FILE

# re-used file to hold list of dates to run
datelist=${TMP_DIR}/doCOMBGeoMatchSelectedDates_temp.txt

if [ -f $datelist ]
  then
    rm -v $datelist | tee -a $LOG_FILE
fi

dateStart='2014-12-02'
echo "Running GRtoGMI matchups for dates since $dateStart" | tee -a $LOG_FILE
dateEnd='2014-12-02'

# find control file dates between dateStart and dateEnd and write to $datelist
yyyymmddstart=`echo $dateStart | sed 's/-//g'`
yyyymmddend=`echo $dateEnd | sed 's/-//g'`
# add start date to the temp file
echo $yyyymmddstart >> ${datelist}

DATEGAP=`grgdif $yyyymmddend $yyyymmddstart`
echo $DATEGAP $yyyymmddend $yyyymmddstart
while [ `expr $DATEGAP \> 0` = 1 ]
  do
    yyyymmddstart=`offset_date $yyyymmddstart 1`
   # add this date to the temp file
    echo $yyyymmddstart >> ${datelist}
    DATEGAP=`grgdif $yyyymmddend $yyyymmddstart`
done

echo " "
echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

#exit

# Step thru the dates, find an IDL control file for each date and run the grids.

while read thisdate
  do
    yymmdd=`echo $thisdate | cut -c3-8`
    echo "yymmdd = $yymmdd"
   # files to hold the delimited output from the database queries comprising the
   # control files for the COMB-GR matchup file creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
#    filelist=${TMP_DIR}/COMB_filelist4geoMatch_temp.txt
#    outfile=${TMP_DIR}/COMB_files_sites4geoMatch_temp.txt
    outfileall=${CTL_DIR}/COMB_files_sites4geoMatch.${yymmdd}.txt

#exit

    echo ""
    echo "Control file ${outfileall} contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE

#    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_DPRGMI_geo_matchup.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_DPRGMI_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_DPRGMI_geo_matchup4date.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_DPRGMI_geo_matchup4date.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_DPRGMI_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE, quitting!"\
	         | tee -a $LOG_FILE
#                exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_DPRGMI_geo_matchup4date.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_DPRGMI_geo_matchup4date.sh, do nothing!"\
	     | tee -a $LOG_FILE
          ;;
        esac

        echo "" | tee -a $LOG_FILE
        end=`date -u`
        echo "Matchup script for $yymmdd completed on $end" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        echo "=================================================================="\
        | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
      else
        echo "" | tee -a $LOG_FILE
        echo "Skipping matchup step for $yymmdd." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
    fi

done < $datelist

echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "See log file: $LOG_FILE"
exit
