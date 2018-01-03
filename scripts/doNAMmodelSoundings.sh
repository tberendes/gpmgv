#!/bin/sh
###############################################################################
#
# doNAMmodelSoundings.sh    Morris/SAIC/GPM GV    May 2012
#
# DESCRIPTION:
# Query gpmgv database for dates/times of GR events for each model cycle and
# assemble command file of GRIB files and related GR sites for which model
# soundings are to be produced by the IDL program get_model_sounding.pro.
#
# 5/22/2012   Morris        Created from doTMIGeoMatch4NewRainCases.sh.
# 5/31/2012   Morris        Incorporate 'modelsoundings' table into the queries
#                           that define which soundings need to be run.
#
###############################################################################


USER_ID=`whoami`
if [ "$USER_ID" = "morris" ]
  then
    GV_BASE_DIR=/home/morris/swdev
    IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/grib_utils
  else
    if [ "$USER_ID" = "gvoper" ]
      then
        GV_BASE_DIR=/home/gvoper
        IDL_PRO_DIR=${GV_BASE_DIR}/idl
      else
        echo "User unknown, can't set GV_BASE_DIR!"
        exit 1
    fi
fi
echo "GV_BASE_DIR: $GV_BASE_DIR"
export GV_BASE_DIR
export IDL_PRO_DIR       # IDL get_model_sounding.bat file needs this
IDL=/usr/local/bin/idl
BIN_DIR=${GV_BASE_DIR}/scripts
export BIN_DIR

MACHINE=`hostname | cut -c1-3`
if [ "$MACHINE" = "ds1" ]
  then
    DATA_DIR=/data/gpmgv
  else
    DATA_DIR=/data
fi
export DATA_DIR

GRIB_DIR=${DATA_DIR}/GRIB/NAMANL
export GRIB_DIR       # IDL get_model_sounding.bat file needs this
NC_DIR=${DATA_DIR}/netcdf/soundings/NAMANL
export NC_DIR         # IDL get_model_sounding.bat file needs this
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/doNAMmodelSoundings.${rundate}.log

umask 0002

   ################################################################################

   # Begin main script
   echo "Starting model sounding extractions on $rundate." | tee $LOG_FILE
   echo "========================================================"\
    | tee -a $LOG_FILE
   echo "" | tee -a $LOG_FILE

   # files to hold the delimited output from the database queries comprising the
   # control files for the sounding file creation in the IDL routines:
   # 'outfile' gets overwritten each time psql is called in the
   # loop over the new cycles, so its output is copied in append manner to
   # 'outfileall', which is run-date-specific.
    filelist=${DATA_DIR}/tmp/GRIBfiles4soundings_temp.txt
    outfile=${DATA_DIR}/tmp/GRsites4modelcycle_temp.txt
    outfileall=${DATA_DIR}/tmp/GRIB_files_sites4soundings.${rundate}.txt

    if [ -s $outfileall ]
      then
        rm -v $outfileall | tee -a $LOG_FILE 2>&1
    fi

   # Get a collated listing of GRIB files to process, put in file $filelist

    DBOUT2=`psql -a -A -t -o $filelist  -d gpmgv -c "select \
       count(distinct instrument_id), a.cycle at time zone 'UTC' as cycle, \
       a.filename as sndfile, coalesce(b.filename, 'No6hForecast') as pcp6file, \
       coalesce(c.filename, 'No3hForecast') as pcp3file \
       from overpass_event o join fixed_instrument_location f on o.radar_id=f.instrument_id \
       join modelgrids a on a.orbit=o.orbit left join modelgrids b on a.orbit=b.orbit \
       and (a.cycle+a.projection)=(b.cycle+b.projection) and b.Projection = '06:00:00' \
       left outer join modelgrids c on b.cycle=c.cycle and a.orbit=c.orbit \
       and c.projection = '03:00:00' left outer join modelsoundings s on \
       o.radar_id=s.radar_id and a.cycle=s.cycle and s.model='NAMANL' \
     where a.Projection='00:00:00' and o.radar_id>'KAA' and o.radar_id<'KWAJ' \
       and o.radar_id!='KMXX' and s.filename is null \
     group by 2,3,4,5 order by 2 desc limit 2;"` | tee -a $LOG_FILE 2>&1

    echo ""
    cat $filelist
    echo ""

   # - Get the list of ground radar site IDs and lat/lons for each included cycle,
   #  and prepare this date's control file for IDL to do sounding file creation.

    for row in `cat $filelist | sed 's/ /_/'`
      do
        file0=`echo $row | cut -f3 -d '|'`
        echo "${file0}"
	DBOUT3=`psql -a -A -t -o $outfile -d gpmgv -c "select distinct instrument_id, \
           latitude, longitude from overpass_event o join fixed_instrument_location f \
           on o.radar_id=f.instrument_id join modelgrids a on a.orbit=o.orbit \
           left outer join modelsoundings s on o.radar_id=s.radar_id and a.cycle=s.cycle and s.model='NAMANL' \
           where a.filename='${file0}' and a.Projection='00:00:00' and o.radar_id>'KAA' \
           and o.radar_id<'KWAJ' and o.radar_id!='KMXX' and s.filename is null order by instrument_id;"` \
        | tee -a $LOG_FILE 2>&1

       # copy the temp file outputs from psql to the daily control file
	echo $row >> $outfileall
        cat $outfile >> $outfileall
    done

    echo ""  | tee -a $LOG_FILE
    echo "Output file contents:"  | tee -a $LOG_FILE
    echo ""  | tee -a $LOG_FILE
    cat $outfileall  | tee -a $LOG_FILE
#exit
    if [ -s $outfileall ]
      then
        CONTROLFILE=$outfileall
        export CONTROLFILE          # IDL get_model_sounding.bat needs this
        echo "" | tee -a $LOG_FILE
        echo "=============================================" | tee -a $LOG_FILE
        echo "Calling IDL for yymmdd = ${rundate}, file = $CONTROLFILE" \
         | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
       
        $IDL < ${IDL_PRO_DIR}/get_model_sounding.bat | tee -a $LOG_FILE 2>&1
      else
        echo "ERROR in doNAMmodelSoundings.sh, control file $CONTROLFILE not found."
        exit 1
    fi

    echo "" | tee -a $LOG_FILE
    echo "========================================================"\
    | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

exit
