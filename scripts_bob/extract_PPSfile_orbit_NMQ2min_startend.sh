#!/bin/sh
#
################################################################################
#
# extract_PPSfile_orbit_NMQ2min_startend.sh      Morris/GPM/GV     April 2016
#
# DESCRIPTION
# -----------
# Given the pathname of a GPM or GPM Constellation data file in the PPS naming
# convention, parses the file to get the satellite ID, orbit number, starting
# datetime of the data, and ending datetime of the data in the file, and rounds
# these datetimes to the nearest 2 minutes (even minutes) to correspond to the
# times of the 2-minute MRMS (a.k.a., Q2, NMQ) grids.
#
# It is assumed that all files to be evaluated are the 2AGPROF files.  To assure
# that the rounded data start and end times for GPM also cover the times of the
# DPR data products, the GPM GMI 2AGROF start and end time ranges are extended
# outward by 30 seconds to help capture the matching MRMS times for all GPM data
# products.
#
# Writes the satellite ID, starting MRMS datetime text, starting MRMS datetime
# in ticks, ending MRMS datetime text, ending MRMS datetime in ticks, and orbit
# number, in "|" delimited format, to the output text file pathname provided as
# the second argument to the script.  Writes a bogus Ascending/Descending flag
# "U" after the satellite ID for compatibility with NSSL legacy code.
#
################################################################################

#for thisPPSfilepath in `ls /data/gpmgv/orbit_subset/GPM/GMI/2AGPROF/V03D/CONUS/2015/10/31/* | grep HDF`
#for thisPPSfilepath in `ls /data/gpmgv/orbit_subset/METOPA/MHS/2AGPROF/V03C/CONUS/2015/10/31/* | grep HDF`

verbose=0
while [ $# -gt 0 ]
  do
    case $1 in
      -v|--verbose) verbose=1; shift 1; thisPPSfilepath=$1; shift 1; outfile=$1; shift 1 ;;
                 *) thisPPSfilepath=$1; shift 1; outfile=$1; shift 1 ;;
    esac
done

if [ $verbose -eq 1 ]
  then
    echo ""
    echo "$0:  Verbose Mode ON"
#  else
#    echo "$0: Verbose Mode OFF"
fi

if [ ! -s $thisPPSfilepath ]
  then
    if [ $verbose = 1 ]
      then
        echo ""
        echo "PPS filename does not exist or is empty: $thisPPSfilepath"
        echo ""
    fi
#    exit 2   # if we require the file to exist, then this is an error
fi

#for thisPPSfilepath in `echo $1`   # leftover from testing
#  do

    # extract the file basename and dirname from thisPPSfilepath
    file=${thisPPSfilepath##*/}
    #dir_only=${thisPPSfilepath%/*}
    # cut out the needed parts of the file name
    sat=`echo $file | cut -f2 -d '.'`
    orbit=`echo $file | cut -f6 -d '.' | cut -c3-6`
    # extract the full data date and start/end time field out of filename
    datatimes=`echo $file | cut -f5 -d '.'`
    # extract the YYYYMMDD data start date field out of the datetimes
    yyyymmdd=`echo $datatimes | cut -f1 -d '-'`
    date=`echo $yyyymmdd | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
    starttime=`echo $datatimes | cut -f2 -d '-' \
              | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)}'`
    endtime=`echo $datatimes | cut -f3 -d '-' \
            | awk '{print substr($1,2,2)":"substr($1,4,2)":"substr($1,6,2)}'`
    starthr=`echo $starttime | cut -f1 -d ':'`
    endhr=`echo $endtime | cut -f1 -d ':'`
    if [ $starthr \> $endhr ]
      then
        if [ $verbose = 1 ]; then echo "Incrementing end date for file: $file"; fi
        endyyyymmdd=`offset_date $yyyymmdd 1`
        enddate=`echo $endyyyymmdd | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)}'`
      else
        enddate=$date
    fi
    ticks_start=`env TZ=UTC date -d "$date $starttime" "+%s"`
    ticks_end=`env TZ=UTC date -d "$enddate $endtime" "+%s"`
    #echo "ticks_start=$ticks_start  ticks_end=$ticks_end"

    # set up time rounding based on satellite - if GPM, then extend time range
    # by 30 seconds to account for potential GMI/DPR differences.  Otherwise,
    # just round Start and End times to the nearest 2 minutes.
    if [ "$sat" = "GPM" ]
      then
        soff=30
        eoff=90
        #echo "sat, soff, eoff: $sat $soff, $eoff"
      else
        soff=60
        eoff=60
        #echo "sat, soff, eoff: $sat $soff, $eoff"
    fi

    a=$(($ticks_start+$soff))
    b=$(($a/120))
    ticksQ2start=$(($b*120))
    dtime_Q2start=`env TZ=UTC date -d @$ticksQ2start "+%Y-%m-%d %T"`
    a=$(($ticks_end+$eoff))
    b=$(($a/120))
    ticksQ2end=$(($b*120))
    dtime_Q2end=`env TZ=UTC date -d @$ticksQ2end "+%Y-%m-%d %T"`

    if [ $verbose = 1 ]
      then
        echo "$sat|U|$date $starttime|$enddate $endtime|$orbit  File_Times"
        echo "$sat|U|$dtime_Q2start|$dtime_Q2end|$orbit  NMQ_Times"
        echo ""
    fi

    # write the computed NMQ times to the end of the output file
    echo "$sat|U|$dtime_Q2start|$dtime_Q2end|$orbit" >> $outfile

    if [ $verbose = 1 ]; then ls -al $outfile; fi

#done   # leftover from testing

exit
