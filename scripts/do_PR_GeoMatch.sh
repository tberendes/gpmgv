#!/bin/sh
###############################################################################
#
# do_PR_GeoMatch.sh    Morris/SAIC/GPM GV    July 2014
#
# Wrapper to do PR-GV NetCDF geometric matchups for 1C21/2A25/2B31/1CUF files
# already received and cataloged, for cases meeting predefined criteria.
#
# Criteria are as defined in the query which is run to update the table
# "rainy100inside100" in the "gpmgv" database.  Includes cases where the PR
# indicates "rain certain" at 100 or more gridpoints within 100 km of the radar
# within the 4km gridded 2A-25 product.  See the SQL command file
# ${BIN_DIR}/'rainCases100kmAddNewEvents.sql'.
#
# NOTE:  When running dates that might have already had PR-GV matchup sets
#        run, the called script will skip these dates, as the 'appstatus' table
#        will say that the date has already been done.  Delete the entries
#        from this table where app_id='geo_match_PR', either for the date(s) to
#        be run, or for all dates.
#
# 7/2014      Morris         Created from doGeoMatch4NewRainCases.sh and
#                            do_DPR_GeoMatch.sh.  Modifed to work with GPM-era
#                            PPS product filenames with long directory paths,
#                            and to not exclude KWAJ from the processing.
# 10/2016    Morris          Cleanup, and removed optional arguments for SAT_ID
#                            and INSTRUMENT_ID overrides, as these never change.
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
    DATA_DIR=/data/gpmgv
fi
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

LOG_DIR=/data/logs
export LOG_DIR
TMP_DIR=/data/tmp
export TMP_DIR
PR_TOP_DIR=${DATA_DIR}/orbit_subset
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

PR_VERSION=7        # controls which PR products we process
export PR_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
GEO_MATCH_VERSION=3.0
export GEO_MATCH_VERSION

# set id of the instrument whose data file products are being matched
# and is used to identify the matchup product files' data type in the gpmgv
# database
PPS_VERSION="V07"        # controls which PR products we process
export PPS_VERSION
PARAMETER_SET=0  # set of polar2pr parameters (polar2pr.bat file) in use
export PARAMETER_SET
INSTRUMENT_ID="PR"
export INSTRUMENT_ID
SAT_ID="TRMM"
export SAT_ID
SUBSET="CONUS"
ALGORITHM21="1C21"
ALGORITHM23="2A23"
ALGORITHM25="2A25"
ALGORITHM31="2B31"

# override coded defaults with user-specified values
while getopts v:p:u: option
  do
    case "${option}"
      in
        v) PPS_VERSION=${OPTARG};;
        p) PARAMETER_SET=${OPTARG};;
        u) SUBSET=${OPTARG};;
    esac
done

echo ""
echo "SAT_ID: $SAT_ID"
echo "INSTRUMENT_ID: $INSTRUMENT_ID"
echo "PPS_VERSION: $PPS_VERSION"
echo "PARAMETER_SET: $PARAMETER_SET"
echo "ALGORITHM: $ALGORITHM"
echo "SUBSET: $SUBSET"


COMBO21=${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM21}/${PPS_VERSION}/${SUBSET}
COMBO23=${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM23}/${PPS_VERSION}/${SUBSET}
COMBO25=${SAT_ID}/${INSTRUMENT_ID}/${ALGORITHM25}/${PPS_VERSION}/${SUBSET}
COMBO31=${SAT_ID}/COMB/${ALGORITHM31}/${PPS_VERSION}/${SUBSET}

rundate=`date -u +%y%m%d`
#rundate=allYMD                                      # BOGUS for all dates
LOG_FILE=${LOG_DIR}/doGeoMatch4NewRainCases.${SUBSET}.${rundate}.log
export rundate

umask 0002

################################################################################
function catalog_to_db() {

# function finds matchup file names produced by IDL polar2pr procedure, as
# listed in the do_geo_matchup_catalog.yymmdd.txt file, in turn produced by
# do_geo_matchup4date.sh by examining the do_geo_matchup4date.yymmdd.log file. 
# Formats catalog entry for the geo_match_product table in the gpmgv database,
# and loads the entries to the database.

YYMMDD=$1
MATCHUP_LOG=${LOG_DIR}/do_geo_matchup4date.${YYMMDD}.log
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
   # PR_VERSION=`echo ${ncfile} | cut -f5 -d '.'`
    GEO_MATCH_VERSION_FILE=`echo ${ncfile} | cut -f6 -d '.' | sed 's/_/./'`
    # check for mismatch between input/coded geo_match_version and matchup file version
    if [ `expr $GEO_MATCH_VERSION_FILE = $GEO_MATCH_VERSION` = 0 ]
      then
        echo "Mismatch between script GEO_MATCH_VERSION ("${GEO_MATCH_VERSION}\
") and file GEO_MATCH_VERSION ("${GEO_MATCH_VERSION_FILE}")"
#      exit 1
    fi

    rowpre="${radar_id}|${orbit}|"
    # - For regular TRMM matchup products the 'scan_type' attribute is hard-coded as 'NS'
    #   and num_gr_volumes is hard-coded as 1 in the rows to be loaded.
    rowpost="|${PPS_VERSION}|${PARAMETER_SET}|${GEO_MATCH_VERSION_FILE}|1|${INSTRUMENT_ID}|${SAT_ID}|NS"

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

echo "Starting PR and GR matchup netCDF generation on $rundate."\
 | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# update the list of rainy overpasses in database table 'rainy100inside100'
SKIP_NEWRAIN=1
if [ "$SKIP_NEWRAIN" = "0" ]
  then
    # update the list of rainy overpasses in database table 'rainy100inside100'
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
      else
        echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        exit 1
    fi
  else
    echo "" | tee -a $LOG_FILE
    echo "Skipping update of database table rainy100inside100" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi

# Build a list of dates with precip events as defined in rainy100inside100 table.
# Modify the query to just run grids for range of dates/orbits.  Limit ourselves
# to the past 30 days, else we pick up a lot of unwanted cases for V6 vs V7 
# studies, etc.  Also, filter out sites KMXX, RGSN, RMOR for which we have
# no GR data.

datelist=${TMP_DIR}/doGeoMatchSelectedDates_temp.txt

# get today's YYYYMMDD
ymd=`date -u +%Y%m%d`

# get YYYYMMDD for 30 days ago
ymdstart=`offset_date $ymd -130`
datestart=`echo $ymdstart | awk \
  '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" 00:00:00+00"}'`
#echo $datestart
datestart="2014-10-03"
echo "Running PRtoGR matchups for dates since $datestart" | tee -a $LOG_FILE

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# here's a faster query pair with the "left outer join geo_match_product"
# connected to a simple temp table

# NOTE HOW SAT_ID OF "PR" IN overpass_event MAPS TO SAT_ID OF "TRMM" IN siteproductsubset
# -- overpass_event TABLE STILL HAS A SAT_ID OF "PR" FOR TRMM OVERPASSES

DBOUT=`psql -a -A -t -o $datelist -d gpmgv -c "SELECT b.sat_id, a.orbit, a.radar_id, a.overpass_time, date_trunc('hour'::text, a.overpass_time) AS nominal, b.subset, a.event_num, a.nearest_distance into temp tempevents \
from overpass_event a, siteproductsubset b, orbit_subset_product o, rainy100inside100 r \
  WHERE a.orbit = o.orbit AND b.subset = o.subset \
 and a.radar_id=b.radar_id and a.sat_id='PR' and b.sat_id='TRMM' \
 AND o.product_type = '2A25' and o.version='${PPS_VERSION}' and o.sat_id=b.sat_id \
   and b.subset = '${SUBSET}' and a.radar_id in (select radar_id from siteproductsubset \
where subset in ('sub-GPMGV1','KWAJ') and radar_id not in ('RGSN','KMXX','RMOR')) \
   and a.overpass_time at time zone 'UTC' > '${datestart}' \
   and a.event_num=r.event_num order by a.overpass_time; \
select DISTINCT date(date_trunc('day', c.overpass_time at time zone 'UTC')) \
  from tempevents c LEFT OUTER JOIN geo_match_product g \
    on c.radar_id=g.radar_id and c.orbit=g.orbit and c.sat_id=g.sat_id \
   and g.pps_version='${PPS_VERSION}' and g.instrument_id='${INSTRUMENT_ID}' \
   and g.PARAMETER_SET=${PARAMETER_SET}  \
 WHERE pathname is null order by 1;"`

echo ""
echo "Dates to attempt runs:" | tee -a $LOG_FILE
cat $datelist | tee -a $LOG_FILE
echo " "

exit

#date | tee -a $LOG_FILE 2>&1  # time stamp for query performance evaluation

# Step thru the dates, build an IDL control file for each date and run the grids.

for thisdate in `cat $datelist`
  do
    yymmdd=`echo $thisdate | sed 's/-//g' | cut -c3-8`
    YMD_DIR=`echo $thisdate | sed 's\-\/\g'`
   # get prior day's date fields in case the PR files overlap days and are
   # stored in a directory date on day earlier than the overpass date/time
    yyyymmdd=`echo $thisdate | sed 's/-//g'`
    yyyymmdd_prev=`offset_date $yyyymmdd -1`
    yymmdd_prev=`echo $yyyymmdd_prev | cut -c3-8`
    YMD_DIR_PREV=`echo $yyyymmdd_prev | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`

   # files to hold the delimited output from the database queries comprising the
   # control files for the 1C21/2A23/2A25/2B31 grid creation in the IDL routines:
   # 'filelist' and 'outfile' get overwritten each time psql is called in the
   # loop over the new dates, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    qfilelist=${TMP_DIR}/PR_filelist4geoMatch_2find.txt
    filelist=${TMP_DIR}/PR_filelist4geoMatch_temp.txt
    outfile=${TMP_DIR}/PR_files_sites4geoMatch_temp.txt
    outfileall=${TMP_DIR}/PR_files_sites4geoMatch.${yymmdd}.txt

    if [ -s $outfileall ]
      then
        rm $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a listing of PR 1C21/2A23/2A25/2B31 files to process, put in file $qfilelist
   # -- 2B31 file presence is considered optional for now

   # Added "and file1c21 is not null" to WHERE clause to eliminate duplicate rows
   # for RGSN's mapping to two subsets. Morris, 12/2008

    DBOUT2=`psql -a -A -t -o $qfilelist  -d gpmgv -c "select \
       '${COMBO21}/${YMD_DIR}/'||file1c21 as file2a21, \
       '${COMBO23}/${YMD_DIR}/'||COALESCE(file2a23, 'no_2A23_file') as file2a23, \
       '${COMBO25}/${YMD_DIR}/'||file2a25 as file2a25, \
       '${COMBO31}/${YMD_DIR}/'||COALESCE(file2b31, 'no_2B31_file') as file2b31,\
       c.orbit, count(*), '${yymmdd}', subset, version \
     from collatedPRtoTRMMproducts c left outer join geo_match_product b on \
       (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version \
        and b.instrument_id = '${INSTRUMENT_ID}') \
       join rainy100inside100 a on (a.orbit=c.orbit AND a.radar_id=c.radar_id) \
     where cast(nominal at time zone 'UTC' as date) = '${thisdate}' \
       and file1c21 is not null and pathname is null and version = '$PPS_VERSION' \
       and c.radar_id in (select radar_id from siteproductsubset \
where subset in ('sub-GPMGV1','KWAJ') and radar_id not in ('RGSN','KMXX','RMOR')) and c.subset='${SUBSET}' \
     group by file1c21, file2a23, file2a25, file2b31, c.orbit, subset, version \
     order by c.orbit;"`  | tee -a $LOG_FILE 2>&1

   # Step through the PR file groups to see whether the specified files are in
   # ${PR_TOP_DIR}/${COMBO21}/${YMD_DIR}, and if not look for them in
   # ${PR_TOP_DIR}/${COMBO21}/${YMD_DIR_PREV}.  If in the latter, then fix the path

     rm -v $filelist
     for filesline in `cat $qfilelist`
       do
         file1c2find=`echo $filesline | cut -f1 -d '|'`
         if [ -f ${PR_TOP_DIR}/${file1c2find} ]
           then
             echo "Found ${file1c2find} under ${PR_TOP_DIR}" | tee -a $LOG_FILE
             echo ${filesline} >> $filelist
           else
             # extract the file basename and dirname from $file1c2find
             thisPPSfile=${file1c2find##*/}
             thisPPSdir=${file1c2find%/*}
             if [ -f ${PR_TOP_DIR}/${COMBO21}/${YMD_DIR_PREV}/${thisPPSfile} ]
               then
                 echo ""
                 echo "Found ${thisPPSfile} under alternate directory: " | tee -a $LOG_FILE
                 echo "${PR_TOP_DIR}/${COMBO21}/${YMD_DIR_PREV}" | tee -a $LOG_FILE
                 filedate=`echo ${thisPPSfile} | cut -f5 -d '.' \
                          | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
                 echo "" | tee -a $LOG_FILE
                 echo "Substituting $filedate for ${YMD_DIR} in path:" | tee -a $LOG_FILE
                 echo "" | tee -a $LOG_FILE
                 echo "Old line: " | tee -a $LOG_FILE
                 echo $filesline | tee -a $LOG_FILE
                 echo "" | tee -a $LOG_FILE
                 echo "New line: " | tee -a $LOG_FILE
                 echo $filesline | sed "s%${YMD_DIR}%${filedate}%g" | tee -a $filelist | tee -a $LOG_FILE
               else
                 echo "No ${thisPPSfile} under ${PR_TOP_DIR}/${COMBO21}/${YMD_DIR_PREV}" | tee -a $LOG_FILE
                 exit
             fi
         fi
     done

#    date | tee -a $LOG_FILE 2>&1

   # - Get a list of ground radars where precip is occurring for each included orbit,
   #  and prepare this date's control file for IDL to do PR and GV grid file creation.
   #  For now will order by radar_id and have IDL handle where the same radar_id
   #  comes up more than once for a case.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        orbit=`echo $row | cut -f5 -d '|'`
        subset=`echo $row | cut -f8 -d '|'`
	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select a.event_num, a.orbit, \
            a.radar_id, date_trunc('second', d.overpass_time at time zone 'UTC'), \
            extract(EPOCH from date_trunc('second', d.overpass_time)), \
            b.latitude, b.longitude, \
            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') \
          from overpass_event a, fixed_instrument_location b, \
	    collatedGVproducts c, rainy100inside100 d, collatedPRtoTRMMproducts p \
            left outer join geo_match_product e on \
              (p.radar_id=e.radar_id and p.orbit=e.orbit and \
               p.version=e.pps_version and e.instrument_id = '${INSTRUMENT_ID}')
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id \
	    and a.radar_id = d.radar_id and a.radar_id = p.radar_id \
	    and a.orbit = c.orbit and a.orbit = d.orbit and a.orbit = p.orbit \
            and a.orbit = ${orbit} and c.subset = '${subset}' and c.subset=p.subset
            and cast(d.overpass_time at time zone 'UTC' as date) = '${thisdate}'
            and a.radar_id in (select radar_id from siteproductsubset \
where subset in ('sub-GPMGV1','KWAJ') and radar_id not in ('RGSN','KMXX','RMOR')) \
            and pathname is null and version = '$PPS_VERSION' order by 3;"` \
        | tee -a $LOG_FILE 2>&1

#        date | tee -a $LOG_FILE 2>&1

#        echo ""  | tee -a $LOG_FILE
#        echo "Output file $outfileall additions:"  | tee -a $LOG_FILE
        echo ""  | tee -a $LOG_FILE
       # copy the temp file outputs from psql to the daily control file
        echo $row | tee -a $outfileall | tee -a $LOG_FILE
        cat $outfile | tee -a $outfileall | tee -a $LOG_FILE
    done

    echo ""  | tee -a $LOG_FILE
#    echo "Output file $outfileall contents:"  | tee -a $LOG_FILE
#    echo ""  | tee -a $LOG_FILE
#    cat $outfileall
#    echo ""  | tee -a $LOG_FILE

cat $outfileall | grep '1CUF' | grep -v no_1CUF_file > /dev/null
if [ $? = '1' ]
   then
     echo "No valid UF files in $outfileall" | tee -a $LOG_FILE
     rm $outfileall
   else
     echo "Proceeding with matchups" | tee -a $LOG_FILE
#     rm $outfileall
#     echo "Output file $outfileall contents:"  | tee -a $LOG_FILE
#     cat $outfileall  | tee -a $LOG_FILE
fi
#sleep 3

#    exit  # if uncommented, creates the control file for first date, and exits

    if [ -s $outfileall ]
      then
       # Call the IDL wrapper scripts, do_geo_matchup.sh, to run
       # the IDL .bat files.  Let each of these deal with whether the yymmdd
       # has been done before.

        echo "" | tee -a $LOG_FILE
        start1=`date -u`
        echo "Calling do_geo_matchup4date.sh $yymmdd on $start1" | tee -a $LOG_FILE
        ${BIN_DIR}/do_geo_matchup4date.sh $yymmdd

        case $? in
          0 )
            echo ""
            echo "SUCCESS status returned from do_geo_matchup4date.sh"\
        	 | tee -a $LOG_FILE
           # extract the pathnames of the matchup files created this run, and 
           # catalog them in the geo_matchup_product table.  The following file
           # must be identically defined here and in do_geo_matchup4date.sh
            DBCATALOGFILE=${TMP_DIR}/do_geo_matchup_catalog.${yymmdd}.txt
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
            echo "FAILURE status returned from do_geo_matchup4date.sh, quitting!"\
	     | tee -a $LOG_FILE
	    exit 1
          ;;
          2 )
            echo ""
            echo "REPEAT status returned from do_geo_matchup4date.sh, do nothing!"\
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

done

echo ""
echo "See log file $LOG_FILE"
exit
