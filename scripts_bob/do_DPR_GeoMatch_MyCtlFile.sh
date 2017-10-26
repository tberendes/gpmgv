#!/bin/sh
###############################################################################
#
# do_DPR_GeoMatch_MyCtlFile.sh    Morris/SAIC/GPM GV    May 2015
#
# Wrapper to do DPR-GR NetCDF geometric matchups for 2AKa/2AKu/2ADPR/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# NOTE:  When running dates that might have already had DPR-GR matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match', either for the date(s) to be
#        run, or for all dates.
#
#        ALSO, it is up to the user to make sure that the command-line options
#        for SAT_ID, INSTRUMENT_ID, PPS_VERSION, ALGORITHM, and SWATH each
#        match up to the file types and control parameters in the supplied
#        control file so that the output matchup files get cataloged correctly
#        in the 'gpmgv' database.
#
# 5/28/2015   Morris       - Created from do_DPR_GeoMatch.sh.
#                            Added capability to accept an argument that is the
#                            pathname to an existing polar2dpr control file.
#                            This allows manual overrides or corrections to be
#                            made to the automatically-generated control files
#                            output by do_DPR_GeoMatch.sh, for instance, when
#                            there is a disconnect between the GR siteID and
#                            the data directories (e.g., NPOL_MD vs. /NPOL).
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
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PPS_VERSION="V03B"        # controls which PR products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="Ku"
export INSTRUMENT_ID
SAT_ID="GPM"
export SAT_ID
SWATH="NS"
export SWATH
GEO_MATCH_VERSION=1.1
export GEO_MATCH_VERSION

# override coded defaults with user-specified values
while getopts s:i:v:p:d:w:m: option
  do
    case "${option}"
      in
        s) SAT_ID=${OPTARG};;
        i) INSTRUMENT_ID=${OPTARG};;
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        w) SWATH=${OPTARG};;
        m) GEO_MATCH_VERSION=${OPTARG};;
    esac
done

ALGORITHM=2A$INSTRUMENT_ID
export ALGORITHM

echo ""
echo "SAT_ID: $SAT_ID"
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
echo "PPS_VERSION: $PPS_VERSION"
echo "PARAMETER_SET: $PARAMETER_SET"
echo "ALGORITHM: $ALGORITHM"
echo "SWATH: $SWATH"

COMBO=${SAT_ID}_${INSTRUMENT_ID}_${ALGORITHM}_${SWATH}

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/do_DPR_GeoMatch.${rundate}.log
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
   # PPS_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
    GEO_MATCH_VERSION_FILE=`echo ${ncfile} | cut -f8 -d '.' | sed 's/_/./'`
    # check for mismatch between input/coded geo_match_version and matchup file version
    if [ `expr $GEO_MATCH_VERSION_FILE = $GEO_MATCH_VERSION` = 0 ]
      then
        echo "Mismatch between script GEO_MATCH_VERSION ("${GEO_MATCH_VERSION}\
") and file GEO_MATCH_VERSION ("${GEO_MATCH_VERSION_FILE}")"
      exit 1
    fi
    rowpre="${radar_id}|${orbit}|"
#    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|2.1|1|${INSTRUMENT_ID}"
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION}|1|${INSTRUMENT_ID}|${SAT_ID}|${SWATH}"
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
    echo "\i $SQL_BIN2" | psql -a -d gpmgv >> $LOG_FILE 2>&1
    tail $LOG_FILE | grep INSERT
fi

return
}
################################################################################

# Begin main script

echo "Starting DPR and GR matchup netCDF generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo ""
outfileall=$1
yymmdd=`echo $outfileall | cut -f5 -d '.'`

echo ""
echo "Output control file:"
ls -al $outfileall
cat $outfileall
echo "yymmdd: $yymmdd"
#exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper script, do_DPR_geo_matchup4date.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_DPR_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_DPR_geo_matchup4date.sh -f 1 $yymmdd $outfileall

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_DPR_geo_matchup4date.sh"\
             | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_DPR_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_DPR_geo_matchup_catalog.${yymmdd}.txt
            if [ -s $DBCATALOGFILE ] 
              then
                catalog_to_db $yymmdd $DBCATALOGFILE
              else
                echo "but no matchup files listed in $DBCATALOGFILE !"\
                 | tee -a $LOG_FILE
                #exit 1
            fi
          ;;
          1 )
            echo ""
            echo "FAILURE status returned from do_DPR_geo_matchup4date.sh, quitting!"\
             | tee -a $LOG_FILE
            exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_DPR_geo_matchup4date.sh, do nothing!"\
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
    fi

#    echo "Continue to next date? (Y or N):"
#    read -r go_on
    go_on=Y
    if [ "$go_on" != 'Y' -a "$go_on" != 'y' ]
      then
         if [ "$go_on" != 'N' -a "$go_on" != 'n' ]
           then
             echo "Illegal response: ${go_on}, exiting." | tee -a $LOG_FILE
         fi
         echo "Quitting on user command." | tee -a $LOG_FILE
         exit
    fi

exit
