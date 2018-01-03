#!/bin/sh
###############################################################################
#
# get_Q2_TRMM_time_matches.sh    Morris/SAIC/GPM GV    November 2012
#
# DESCRIPTION:
# Determines the Q2 times corresponding to the TRMM overpass entry and exit of
# the latitude/longitude box extending from 37N-24N latitude to 125W-75W
# longitude.  Uses a modified version of the NASA/GSFC/PPS TRMM Overflight
# Finder to predict the TRMM orbit overpasses for the upcoming month for
# sectors 10 degrees wide in longitude for the fixed latitudes above, rounds
# the overpass times to the nearest 5 minutes, and figures out the first and
# last time of the TRMM overpasses in the full lat/lon domain for each orbit.
#
# 11/15/2012   Morris      Created.
# 2/19/2013    Morris      - Fixed argument to monthdays calls.
#                          - Fixed handling of time zone in 'date' calls.
#                          - Moved definition of TMPFILE1 into 'for' loop to
#                            create a separate file for each longitude.
#                          - Added status checking of configured files and
#                            directories.
#                          - Added Quiet/Verbose command option, conditional
#                            output of diagnostic messages.
#
###############################################################################

# check command line option for verbose output
verbose=1
while [ $# -gt 0 ]
  do
    case $1 in
      -q|--quiet) verbose=0; shift 1 ;;
      *) echo "Ignoring unknown option: $1" ; shift 1 ;;
    esac
done

if [ $verbose -eq 1 ]
  then
    echo "$0:  Verbose Mode ON"
#  else
#    echo "$0: Verbose Mode OFF"
fi

###############################################################################
# the following two directories are to be locally configured.  TOFF_BASE must
# reflect the installation of the TRMM_Overflight_Finder code and data files
###############################################################################

TOFF_BASE=/home/morris/swdev/TRMM_Overflight_Finder/TOFF
TMP_DIR=/tmp

if [ ! -d ${TOFF_BASE} ]
  then
    echo "TOFF_BASE directory: ${TOFF_BASE} non-existent!"
    echo "Check configuration in script.  Exiting."
    exit 1
fi

if [ ! -d ${TMP_DIR} ]
  then
    echo "TMP_DIR directory: ${TMP_DIR} non-existent!"
    echo "Check configuration in script.  Exiting."
    exit 1
  else
    if [ ! -w ${TMP_DIR} ]
      then
        echo "TMP_DIR directory: ${TMP_DIR} has no write privilege!  Exiting."
        exit 1
    fi
fi

# the Overflight Finder is hard-coded to look/be in these locations
# -- PPSFILES is needed by the binary program, FindOrbitsQ2_exe
PPSFILES=${TOFF_BASE}/FIL
TOFF_BIN_DIR=${TOFF_BASE}/toff

if [ ! -d ${PPSFILES} ]
  then
    echo "PPSFILES directory: ${PPSFILES} non-existent!  Exiting."
    exit 1
fi

if [ ! -d ${TOFF_BIN_DIR} ]
  then
    echo "TOFF_BIN_DIR directory: ${TOFF_BIN_DIR} non-existent!  Exiting."
    exit 1
fi

if [ ! -x ${TOFF_BIN_DIR}/FindOrbitsQ2_exe ]
  then
    echo "File: ${TOFF_BIN_DIR}/FindOrbitsQ2_exe"
    echo "is non-existent or non-executable!  Exiting."
    ls -al ${TOFF_BIN_DIR}/FindOrbitsQ2_exe
    exit 1
fi

# all script output and temporary files are written in TMP_DIR
# -- see 'for' loop for definition of TMPFILE1, now using multiple files
#TMPFILE1=${TMP_DIR}/raw_overpass_sector.txt  # takes output from FindOrbitsQ2_exe
TMPFILE2=${TMP_DIR}/Q2_overpass.txt          # merger of above, all 3 sectors
if [ -s $TMPFILE2 ]
  then
    if [ $verbose -eq 1 ]
      then
        echo "Removing temporary file:  $TMPFILE2"
        rm -v $TMPFILE2
      else
        rm $TMPFILE2
    fi
fi

# figure out the next month following today's date
today=`date -u +%Y%m%d`
thisYYYYMM=`echo $today | cut -c 1-6`
daysInYYYYMM=`monthdays $today`
daysLeft=`grgdif $thisYYYYMM$daysInYYYYMM $today`
daysNext=`expr $daysLeft + 1`
nextmonthbeg=`offset_date $today $daysNext`
nextYYYYmm=`echo $nextmonthbeg | cut -c 1-6`

OUTFILE=${TMP_DIR}/Q2_overpasses_${nextYYYYmm}.txt
if [ -s $OUTFILE ]
  then
    if [ $verbose -eq 1 ]
      then
        # give user the option to overwrite file or leave it and exit early
        echo ""
        echo "Output file for date ${nextYYYYmm} already exists:"
        ls -al $OUTFILE
        echo ""
        rm -iv $OUTFILE
      else
        # just delete the file quietly
        rm $OUTFILE
    fi
fi
if [ -s $OUTFILE ]
  then
    echo "Quitting and leaving existing output file in place."
    exit 2
fi

# get the beginning and ending dates of the next month in toff's input format

daysInYYYYMM=`monthdays $nextmonthbeg`
nextmonthend=$nextYYYYmm$daysInYYYYMM
date1=`echo $nextmonthbeg | awk '{print substr($1,1,4)" "substr($1,5,2)" "substr($1,7,2)" "}'`
date2=`echo $nextmonthend | awk '{print substr($1,1,4)" "substr($1,5,2)" "substr($1,7,2)" "}'`
if [ $verbose -eq 1 ]
  then
    echo ""
    echo "Start date: $date1"
    echo "  End date: $date2"
    echo ""
fi

# Call the FindOrbitsQ2_exe program to get the month's overpasses of each subsector,
# defined by their 'center' lons.  The program defines a rectangle +/- 5 degrees
# in longitude from the center lons, between 24-37 deg. N latitude (hard coded).
# Cut out only the orbit numbers/node direction and date/times, compute the Q2
# time (overflight time rounded to nearest 5 minutes) and save desired fields
# to a holding file

cd $TOFF_BIN_DIR
for lons in -120.0 -110.0 -100.0 -90.0 -80.0
  do
    # define a longitude-specific file to take the output of FindOrbitsQ2_exe
    TMPFILE1=${TMP_DIR}/raw_overpass_sector${lons}.txt
    if [ -s $TMPFILE1 ]
      then
        if [ $verbose -eq 1 ]
          then
            echo "Removing temporary file:  $TMPFILE1"
            rm -v $TMPFILE1  # clean out last run's file
          else
            rm $TMPFILE1
        fi
    fi
    # determine the orbit overpass times for each sector for the month
    # -- the 30.5 degree lat value is just a placeholder and is not used
    ./FindOrbitsQ2_exe $date1 $date2 30.5 $lons 20 | grep end | \
        cut -c 3-8,23-33,49-64 | sed 's/end  */end|/' | sed 's/ /|/' > $TMPFILE1

    # check whether FindOrbits produced any valid output, exit with error if no
    if [ ! -s $TMPFILE1 ]
      then
        echo "ERROR! No result returned from call: ./FindOrbitsQ2_exe $date1 $date2 30.5 $lons 20"
        exit 1
      else
        if [ $verbose -eq 1 ]
          then
            echo "New orbit prediction file for center longitude $lons:"
            ls -al $TMPFILE1
        fi
    fi
    # read the results and convert the TRMM time to the nearest Q2 time
    while read line
      do
        orbit=`echo $line | cut -f1 -d '|'`
        direction=`echo $line | cut -f2 -d '|'`
        # round datetime to nearest 5 minutes (Q2 time stamps)
        textdate=`echo $line | cut -f3 -d '|'`
        ticks=`env TZ=UTC date -d "$textdate" "+%s"`  # date option to convert to ticks
        a=$(($ticks+150))   # bash arithmetic syntax: $(( some operation ))
        b=$(($a/300))
        ticksQ2=$(($b*300))
        dtimeQ2=`env TZ=UTC date -d @$ticksQ2 "+%Y-%m-%d %T"`  # convert back FROM ticks
        # output the orbit #, Q2 times, etc. to delimited file
        echo "$orbit|$ticksQ2|TRMM|$direction|$dtimeQ2" >> $TMPFILE2
    done < $TMPFILE1
done

if [ $verbose -eq 1 ]
  then
    echo ""
    echo "Q2 start, end times for each orbit: "
    echo ""
fi

# loop over the sorted orbit/Q2time combos and determine the first and last
# (i.e., entry and exit) Q2 times for each
lastorbit=0
while read line2
  do
    orbit=`echo $line2 | cut -f1 -d '|'`
    if [ $orbit -gt $lastorbit ]
      then
        if [ $lastorbit -gt 0 ]
          then
            # output prior orbit's start and end Q2 times, etc.
            if [ $verbose -eq 1 ]
              then
                echo ${others}'|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} | tee -a $OUTFILE
              else
                echo ${others}'|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} >> $OUTFILE
            fi
        fi
        # grab the new orbit's data, setting end time same as start
        # in case it's the only entry for this orbit
        others=`echo $line2 | cut -f3-4 -d '|'`
        q2dtime=`echo $line2 | cut -f5 -d '|'`
        q2dtime2=$q2dtime
        q2ticks=`echo $line2 | cut -f2 -d '|'`
        q2ticks2=$q2ticks
      else
        # just get the new end time for the current orbit
        q2dtime2=`echo $line2 | cut -f5 -d '|'`
        q2ticks2=`echo $line2 | cut -f2 -d '|'`
   fi
   lastorbit=$orbit
done <<< "`cat $TMPFILE2 | sort -u`"

#output the last orbit read from the file also
if [ $verbose -eq 1 ]
  then
    echo ${others}'|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} | tee -a $OUTFILE
  else
    echo ${others}'|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} >> $OUTFILE
fi

echo ""
echo "Output written to $OUTFILE"
if [ $verbose -eq 1 ]
  then
    ls -al $OUTFILE
fi
echo ""

exit 0
