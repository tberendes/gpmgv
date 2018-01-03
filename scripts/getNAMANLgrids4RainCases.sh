#!/bin/sh
###############################################################################
#
# getNAMANLgrids4RainCases.sh    Morris/SAIC/GPM GV    Feb 2011
#
# DESCRIPTION:
# Query gpmgv database for dates/times of rainy PR overpasses and assemble
# command string to download NAM Analysis grid subsets for the nearest
# cycle date/time from the NCDC NOMADS archives.  Uses PERL scripts
# get_inv.pl and get_grib.pl provided by NCEP to subset the GRIB files to
# the variables/levels of interest and download the subsetted GRIB files,
# which are then compressed using gzip.  Downloaded files are cataloged in the
# 'gpmgv' database table 'modelgrids'.
#
###############################################################################

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR
GRIB_DATA=${DATA_DIR}/GRIB/NAMANL
export GRIB_DATA
rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getNAMANLgrids4RainCases.${rundate}.log
export LOG_FILE
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
export BIN_DIR
export PATH
SQL_BIN=${BIN_DIR}/rainCases100kmAddNewEvents.sql

umask 0002

echo "Starting NAM Analysis grid acquisition on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getNAMANLdata_dbtempfile
# list of cycle datetimes to retrieve, as URL/file specs
NAMTOGET=${TMP_DIR}/getNAMANLdata_URLtempfile
if [ -f $NAMTOGET ]
  then
    rm -v $NAMTOGET | tee -a $LOG_FILE 2>&1
fi

################################################################################
function getgribspec() {

# function acquires NAM GRIB file given a partial pathname, stores it in the
# directory defined by $GRIB_DATA, and catalogs the file in the table
# 'modelgrids' in 'gpmgv' database. Determines which variables to retrieve in
# the GRIB file based on the model forecast projection (0 or 6 hour forecast).
#
# Takes 3 args: partial file pathname, model projection, and switchover date

filespec=$1
source=`echo $filespec | cut -f3 -d '/' | cut -f1 -d'_'`
echo "Using data dir $source" | tee -a $LOG_FILE
file_yyyymmdd=`echo $filespec | cut -f2 -d'/'`
echo "lastyr: $3    fileyr: $file_yyyymmdd" | tee -a $LOG_FILE

if [ $source = "namanl" ]
  then
   # check whether data date is more than 1 year ago; if so then get .inv
   # from namanl, otherwise get from nam archive
    if [ $file_yyyymmdd -gt $lastyr_yyyymmdd ]
      then
       # generate the matching .inv file name for retrieval from the nam archive
       # since the namanl archive has missing .inv files for most recent 11 mos. or so
        invfilespec=`echo $filespec | sed 's/namanl/nam/'`
        b="http://nomads.ncdc.noaa.gov/data/nam/${invfilespec}"
      else
       # just generate the .inv file name for retrieval from the namanl achive
        b="http://nomads.ncdc.noaa.gov/data/namanl/${filespec}"
    fi
  else
   # check whether data date is more than 330 days ago; if so then the data
   # will no longer be available from then nam archive
    if [ $file_yyyymmdd -lt $lastyr_yyyymmdd ]
      then
        echo "Date too old, no nam forecast files present, skipping." | tee -a $LOG_FILE
        return
      else
        b="http://nomads.ncdc.noaa.gov/data/nam/${filespec}"
    fi
fi
echo "Using NOMADS inventory file: $b" | tee -a $LOG_FILE
# generate the output .grb filename prefix
outfile=`echo $filespec | cut -f3 -d'/'`
a="http://nomads.ncdc.noaa.gov/data/${source}/${filespec}"
echo "Using NOMADS GRIB file: $a" | tee -a $LOG_FILE

# check whether we already have a version of ${outfile}.grb
havegribfile="n"
ls ${GRIB_DATA}/${outfile}.grb* > /dev/null 2>&1
if [ $? = 0  ]
  then
    havegribfile="y"
   # is it gzipped?
    ls ${GRIB_DATA}/${outfile}.grb* | grep '.gz' | grep -v grep > /dev/null 2>&1
    if [ $? = 0 ]
      then
        echo ""
        echo "Already have ${outfile}.grb.gz" | tee -a $LOG_FILE
        echo ""
        dbfile=${outfile}.grb.gz
      else
        echo ""
        echo "Already have ${outfile}.grb" | tee -a $LOG_FILE
        echo ""
        dbfile=${outfile}.grb
    fi
  else
   # try to retrieve the grib file
    case $2 in
          0 ) get_inv.pl $b.inv | \
              egrep "(:(TMP|RH|UGRD|VGRD):[1-9][0-9]* mb)|TMP:sfc|TSOIL:0-10|SOILW:0-10"  | \
              get_grib.pl $a.grb ${GRIB_DATA}/${outfile}.grb;;
      3 | 6 ) get_inv.pl $b.inv | grep "APCP"  | \
              get_grib.pl $a.grb ${GRIB_DATA}/${outfile}.grb;;
          * ) echo "Unknown forecast projection "$2", must be 0 or 6." | tee -a $LOG_FILE;;
    esac
            if [ -s ${GRIB_DATA}/${outfile}.grb ]
              then
                havegribfile="y"
                echo "" | tee -a $LOG_FILE
                echo "finished downloading ${outfile}.grb" | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
                gzip -v ${GRIB_DATA}/${outfile}.grb | tee -a $LOG_FILE 2>&1
                if [ $? = 0 ]
                  then
                    dbfile=${outfile}.grb.gz
                  else
                    echo "Error compressing ${outfile}.grb, store as-is." | tee -a $LOG_FILE
                    dbfile=${outfile}.grb
                fi
              else
                echo "" | tee -a $LOG_FILE
                echo "ERROR -- File ${outfile}.grb not downloaded!" | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
                dbfile=${outfile}.grb
            fi
        fi

       # tally the download result in the permanent table if we got the gridfile,
       # otherwise tally in missingmodelgrids table for later attempts
        if [ $havegribfile = "y"  ]
          then
            gridtable='modelgrids'
          else
            gridtable='missingmodelgrids'
        fi
       # find the orbit(s) associated to this model cycle, and catalog in DB
       # - do a unique sorting to eliminate orbit/filespec duplicates from
       #   original DB query
        for orbitfile in `grep $filespec $NAMTOGET | sort -u`
          do
            orbit=`echo $orbitfile | cut -f1 -d '|'`
            dbdate=`echo $orbitfile | cut -f2 -d '|'`
            dbcycle=`echo $orbitfile | cut -f3 -d '|'`
            fcsttime=`echo $orbitfile | cut -f4 -d '|'`
            model=`echo $source | tr '[:lower:]' '[:upper:]'`
            echo "insert into ${gridtable}(orbit,cycle,projection,model,filetype,filename) values \
 (${orbit}, '${dbdate} ${dbcycle}', '$fcsttime hours', '$model', 'GRIB', '${dbfile}');" \
 | psql -a gpmgv  | tee -a $LOG_FILE 2>&1
        done

return
}
################################################################################

# Begin script

# update the list of rainy overpasses in database table 'rainy100inside100'
if [ -s $SQL_BIN ]
  then
    echo "\i $SQL_BIN" | psql -a -d gpmgv | tee -a $LOG_FILE 2>&1
  else
    echo "ERROR: SQL command file $SQL_BIN not found, exiting." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

# update the list of rainy overpasses in database table 'rainy100by2a53'
if [ -x $BIN_DIR/do2A5xMetadata.sh ]
  then
    $BIN_DIR/do2A5xMetadata.sh
  else
    echo "ERROR: $BIN_DIR/do2A5xMetadata.sh not found or not executable, exiting." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    exit 1
fi

echo "" | tee -a $LOG_FILE
echo "-----------------------------------------------------------" | tee -a $LOG_FILE
echo "                Resuming main script" | tee -a $LOG_FILE
echo "-----------------------------------------------------------" | tee -a $LOG_FILE

# set the first orbit to be considered in the downloads
FIRSTORBIT=82078    # matching GRIB data left off here

# find the latest orbit with 2A-5x products available.  Don't want to consider
# orbits beyond this, since rain case metadata will be incomplete for these.
DBOUT=`psql -A -t -d gpmgv -c "select max(orbit) from collatecolswsub a,\
 gvradar f, gvradar c WHERE a.nominal = f.nominal AND a.radar_id = f.radar_id\
 AND f.product = '2A53' and a.nominal = c.nominal AND a.radar_id = c.radar_id\
 AND c.product = '2A54';"`

echo "" | tee -a $LOG_FILE
echo "Latest orbit with 2A-5x data: $DBOUT" | tee -a $LOG_FILE 2>&1
echo "" | tee -a $LOG_FILE

# find the latest orbit with matching model data and store its value in database
# -- we will start looking for new matching GRIB 50 orbits prior to this
#    to pick up missing model runs (see follow-on query)
#echo "Drop table maxmodelorbit;"  | psql gpmgv | tee -a $LOG_FILE 2>&1
echo "Delete from maxmodelorbit;\
      Insert into maxmodelorbit Select max(orbit) from modelgrids;" \
    | psql -q gpmgv | tee -a $LOG_FILE 2>&1
DBOUT2=`psql -A -t -d gpmgv -c "select maxorbit from maxmodelorbit;"`
echo "Latest orbit with matching GRIB data: $DBOUT2" | tee -a $LOG_FILE 2>&1
echo "We will start looking for new matching GRIB 50 orbits prior to this." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# query finds orbits and times where either of the PR "100 rain certain 4-km gridpoints within 100km"
# or the GR "100 2-km non-zero 2A-53 rainrate gridpoints" criteria are met.  The latter query is much
# more likely to be met for a set of overpassed GR sites.  Excludes orbits whose matching model run
# has already been downloaded/cataloged, and those for which 2A-5x products have not been recieved yet.

# NOTE THAT WE CAN GET TWO HITS FOR AN ORBIT IF THE FIRST SITE WHERE RAIN OCCURS DIFFERS

echo "\t \a \o $DBTEMPFILE \\\select a.orbit, min(overpass_time at time zone 'UTC')\
 from rainy100inside100 a, orbit_subset_product b where a.orbit=b.orbit and b.product_type='2A12'\
 and a.orbit > (select maxorbit-50 from maxmodelorbit) and a.orbit<${DBOUT}\
 and not exists (select * from modelgrids m where b.orbit=m.orbit and model='NAMANL' and filetype='GRIB')\
 group by a.orbit\
 UNION select a.orbit, min(overpass_time at time zone 'UTC') from rainy100by2a53 a,\
 orbit_subset_product b where a.orbit=b.orbit and b.product_type='2A12'\
 and a.orbit > (select maxorbit-50 from maxmodelorbit) and a.orbit<${DBOUT}\
 and not exists (select * from modelgrids m where b.orbit=m.orbit and model='NAMANL' and filetype='GRIB')\
 group by a.orbit order by 1 limit 250;" \
  | psql gpmgv | tee -a $LOG_FILE 2>&1

echo "Contents of DBTEMPFILE ${DBTEMPFILE}:" | tee -a $LOG_FILE
cat $DBTEMPFILE | tee -a $LOG_FILE
# exit

while read line
  do
    prdatetime=`echo $line`
    orbit=`echo $prdatetime | cut -f1 -d '|'`
    yyyymmdd=`echo $prdatetime | cut -f2 -d '|' | cut -f1 -d ' ' | sed "s/-//g"`
    yyyymm=`echo $yyyymmdd | cut -c1-6`
    hh=`echo $prdatetime | cut -f2 -d ' ' | cut -c1-2`
    echo "" | tee -a $LOG_FILE
    echo "=====================================================================" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo $prdatetime | tee -a $LOG_FILE
    echo hh: $hh | tee -a $LOG_FILE
    cycle1=`expr $hh + 3`
    cycle2=`expr $cycle1 / 6`
    cycle=`expr $cycle2 \* 6`
    if [ `expr $cycle = 24` = 1 ]
      then
        echo "" | tee -a $LOG_FILE
        echo "Mapping $yyyymmdd $hh to 00Z cycle of the following day, and incrementing day." | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        cycle=0
        newyyyymmdd=`offset_date $yyyymmdd 1`
        yyyymmdd=$newyyyymmdd
        yyyymm=`echo $yyyymmdd | cut -c1-6`
    fi
    if [ `expr $cycle \< 10` = 1 ]
      then
        cycle=0$cycle
    fi
   # go 6 hours back to get the cycle datetime of the GRIB file to use as the
   # source of the 0-6h precip accumulation grid
    yyyymmddpcp=$yyyymmdd
    yyyymmpcp=$yyyymm
    case $cycle in
      00 ) cyclepcp=18
           yyyymmddpcp=`offset_date $yyyymmdd -1`
           yyyymmpcp=`echo $yyyymmddpcp | cut -c1-6`;;
      06 ) cyclepcp=00;;
      12 ) cyclepcp=06;;
      18 ) cyclepcp=12;;
       * ) echo "Invalid cycle time: $cycle";;
    esac
    echo yyyymmdd: $yyyymmdd | tee -a $LOG_FILE
    echo yyyymm: $yyyymm | tee -a $LOG_FILE
    echo cycle: $cycle | tee -a $LOG_FILE
    echo yyyymmddpcp: $yyyymmddpcp | tee -a $LOG_FILE
    echo yyyymmpcp: $yyyymmpcp | tee -a $LOG_FILE
    echo cyclepcp: $cyclepcp | tee -a $LOG_FILE
    namfile="${yyyymm}/${yyyymmdd}/namanl_218_${yyyymmdd}_${cycle}00_000"
    namfilepcp="${yyyymmpcp}/${yyyymmddpcp}/nam_218_${yyyymmddpcp}_${cyclepcp}00_006"
    dbdate=`echo $yyyymmdd | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    dbdatepcp=`echo $yyyymmddpcp | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    dbcycle=${cycle}:00:00+00
    dbcyclepcp=${cyclepcp}:00:00+00
    echo "${orbit}|${dbdate}|${dbcycle}|0|${namfile}" \
     | tee -a $NAMTOGET | tee -a $LOG_FILE
    echo "${orbit}|${dbdatepcp}|${dbcyclepcp}|6|${namfilepcp}" \
     | tee -a $NAMTOGET | tee -a $LOG_FILE
   # if the forecast cycle is 06 or 18, 6-h projection only has 3-6h precip,
   # so we need to also get the 3-h projection with the 0-3h precip accumulation
    if [[ $cyclepcp = 06 || $cyclepcp = 18 ]]
      then
        echo "Forecast cycle is $cyclepcp, must get 3-h projection also." | tee -a $LOG_FILE
        namfilepcp="${yyyymmpcp}/${yyyymmddpcp}/nam_218_${yyyymmddpcp}_${cyclepcp}00_003"
        echo "${orbit}|${dbdatepcp}|${dbcyclepcp}|3|${namfilepcp}" \
         | tee -a $NAMTOGET | tee -a $LOG_FILE
    fi

done < $DBTEMPFILE

wc $NAMTOGET | tee -a $LOG_FILE


#exit   # uncomment just for testing download set-up


echo "" | tee -a $LOG_FILE
echo "=====================================================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

if [ -s $NAMTOGET ]
  then
   # get the date ~11 mos. ago.  NAM archive only goes back 1 year (11 months, actually),
   # and NAMANL archive is missing .inv files for most recent 10 2/3 months or so, 
   # so get .inv files from NAMANL (NAM) if before (after) this date.  This also means
   # that the precipitation accumulation grids from the NAM forecasts are not
   # available for dates older than 11 months ago.

    yyyymmddnow=`date -u +%Y%m%d`
    lastyr_yyyymmdd=`offset_date $yyyymmddnow -330`

   # list and acquire the unique model cycles
    for filespecs in `cat $NAMTOGET | cut -f4-5 -d '|' | sort -u`
      do
        forecast_time=`echo $filespecs | cut -f1 -d '|'`
        filespec=`echo $filespecs | cut -f2 -d '|'`
        getgribspec $filespec $forecast_time $lastyr_yyyymmdd
    done
fi

echo "Clean up the missingmodelgrids table based on latest downloads:" | tee -a $LOG_FILE
echo "select * from missingmodelgrids where 1 = (select count(*) from modelgrids where \
filename=missingmodelgrids.filename||'.gz' and orbit=missingmodelgrids.orbit);" \
 | psql -a gpmgv  | tee -a $LOG_FILE 2>&1
echo "delete from missingmodelgrids where 1 = (select count(*) from modelgrids where \
filename=missingmodelgrids.filename||'.gz' and orbit=missingmodelgrids.orbit);" \
 | psql -a gpmgv  | tee -a $LOG_FILE 2>&1

echo "" | tee -a $LOG_FILE
echo "Done!"

exit
