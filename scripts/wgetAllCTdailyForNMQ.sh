#!/bin/sh
#
################################################################################
#
#  wgetAllCTdailyForNMQ.sh     Morris/SAIC/GPM GV     February 2014
#
#  DESCRIPTION
#    Retrieves core/constellation satellite coincidence files from PPS site:
#
#       arthurhou.eosdis.nasa.gov
#
#    CT files for a given date get posted at around 1502 UTC on the next day.
#    CT file pattern is "CT.SSSS.yyyymmdd.jjj.txt" and they are located in the
#    subdirectory TBD.
#
#    The CT file naming convntion is CT.SSSS.yyyymmdd.jjj.txt, where:
#
#          CT - literal characters 'CT'
#        SSSS - ID of the satellite, variable length character field
#    yyyymmdd - year (4-digit), month, and day of the overpass data
#         jjj - day of year (Julian day), zero-padded to 3 digits
#         txt - literal characters 'txt'
#
#    Following the successful download of the CT file(s), the utility script
#    get_Q2_time_matches_from_CTs.sh is invoked to identify those Q2 times
#    coincident with the satellite overpasses.
#
#  INTERNAL ROUTINES CALLED
#    get_Q2_time_matches_from_CTs()  - Matches up Q2 product times
#                                      to satellite coincidence times.
#
#  FILES
#    CT.SSSS.yyyymmdd.jjj.txt
#      - CT files to be retrieved from PPS ftp site.  Date yyyymmdd
#        is determined by time script is run, and is either
#        yesterday or day-before-yesterday.
#    Q2_for_SSSS.yyyymmdd.jjj.txt
#      - Output file listing rounded NMQ start/end times for CONUS site orbit
#        overpasses contained in CT.SSSS.yyyymmdd.jjj.txt.
#    CTs_All_today
#      - Temporary file listing the 'SSSS.yyyymmdd' values of all
#        the new PPS CT files we expect to get in the current run.
#    CTs_All_missing
#      - Status file holding a listing the 'SSSS.yyyymmdd' values of all
#        expected CT files that failed to be found and/or downloaded in prior
#        script runs.
#    CTs_All_missing_COPY
#      - Temporary copy of file CTs_All_missing.
#    CTs_All_FailedAfter5times
#      - Status file holding a listing the 'SSSS.yyyymmdd' values of all
#        CT files that failed to be found and/or downloaded after 5 tries.
#    CTs_To_Process
#      - File holding a listing of file pathnames of CT files
#        successfully downloaded in this script run, and which are to be
#        processed to compute NMQ times for the CONUS site overpasses.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    wgetAllCTdailyForNMQ.YYMMDD.log in $LOG_DIR subdirectory.
#
#  CONSTRAINTS
#    - User must have write privileges in $CT_DATA, $LOG_DIR directories
#
#  HISTORY
#    Feb 2014 - Morris - Created from wgetCTdaily.sh.
#
################################################################################


##################### local configuration items ############################
DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_tables      # original and transformed CTs
export CT_DATA
#SAT_LIST=${CT_DATA}/SATELLITES_FOR_CT.txt  # using hard-coded list instead
LOG_DIR=${DATA_DIR}/logs

###################### ftp account/location details ########################
USERPASS=kenneth.r.morris@nasa.gov
FIXEDPATH='ftp://arthurhou.pps.eosdis.nasa.gov/pub/gpmuser/gpmgv/coincidence'

############################################################################

today=`date -u +%Y%m%d`
LOG_FILE=${LOG_DIR}/wgetAllCTdaily.${today}.log  # datestamped fixed name
PATH=${PATH}:${BIN_DIR}
ZZZ=2

umask 0002

# file listing partial file pathnames from missed CT download attempts
DBTEMPFILE=${CT_DATA}/CTs_All_missing

# file listing new partial file pathnames for today's CT download attempt
TODAYSFILES=${CT_DATA}/CTs_All_today
rm -fv $TODAYSFILES | tee $LOG_FILE

# temporary file copy of $DBTEMPFILE
TEMPCOPY=${CT_DATA}/CTs_All_missing_COPY

# file listing partial file pathnames from five-time failed CT download attempts
CTFAILURE=${CT_DATA}/CTs_All_FailedAfter5times

# file listing full pathnames of all downloaded files to be post-processed to
# compute matching NMQ start/end times
FILES2DO=${CT_DATA}/CTs_To_Process
rm -fv $FILES2DO | tee -a $LOG_FILE

# Constants for possible status of downloads (probably don't use many of these)
UNTRIED='U'    # haven't attempted initial download yet
SUCCESS='S'    # got the desired file
MISSING='M'    # initial tries failed, try again next time
FAILED='F'     # failed Nth round of tries, no more attempts
DUPLICATE='D'  # prior attempt was successful as file exists, but db was in error
INCOMPLETE='I' # got fewer than all configured CT files for a date

status=$SUCCESS   # initializes to optimistic outcome
have_retries='f'  # indicates whether we have missing prior CT filedates to retry


################################################################################
function get_Q2_time_matches_from_CTs() {
#
# get_Q2_time_matches_from_CTs()    Morris/SAIC/GPM GV    February 2014
#
# DESCRIPTION:
# Determines the Q2 times corresponding to the ground site overpasses of GPM
# and constellation satellites, given the day- and satellite-specific file
# pathname to a CT file in fixed-formatted text.  CT files contain
# the daily overpass predictions for a given satellite in the format:
#
# TRMM SATELLITE-GROUND SITE COINCIDENCE FILE
# 
# YEAR 2005     DAY 011
# 
#  ORBIT  +------------------ CLOSEST APPROACH ------------------+         SITE
#  NUMBER | DISTANCE  LATITUDE  LONGITUDE           TIME         |         CODE
#         |   (KM)     (DEG)      (DEG)    YYYY-MM-DDTHH:mm:SS.s |
# --------+------------------------------------------------------+---------------------
#   40790,   184.5,    12.102,   145.802,  2005-01-11T00:10:55.6,  GUAM
#   40790,   702.5,    23.921,   -98.484,  2005-01-11T00:40:08.8,  TEXS
#   40790,   702.6,    23.920,   -98.481,  2005-01-11T00:40:08.8,  HSTN
#   40791,   498.5,     1.414,   107.718,  2005-01-11T01:38:29.2,  SCSS
#   40791,   618.7,   -15.412,   -64.650,  2005-01-11T02:31:04.3,  LBXD
#
# where the leading '# ' characters are not included in the actual CT files.
# The CT file naming convntion is CT.SSSS.yyyymmdd.jjj.txt, where:
#
#       CT - literal characters 'CT'
#     SSSS - ID of the satellite, variable length character field
# yyyymmdd - year (4-digit), month, and day of the overpass data
#      jjj - day of year (Julian day), zero-padded to 3 digits
#      txt - literal characters 'txt'
#
# The ID of the satellite is included in the first line of the CT file, as well
# as in the SSSS field in the CT file name.  We are only interested in CONUS
# WSR-88D sites for determining NMQ times, so we filter out all site codes not
# consisting of a 4-letter ID beginning with "K".  Then we throw out the two
# other site codes in the CT file that aren't CONUS WSR-88Ds: KWAJ and KORA.
#
# Rounds the overpass times to the nearest 2 minutes, and outputs a new file
# with the NMQ/Q2 starting and ending times for each orbit in unix ticks and
# ASCII text, preceded by the satellite ID and a placeholder "U" character,
# and delimited by '|'.  Output example line:
#
# TRMM|U|2005-01-11 08:30:00|1105432200|2005-01-11 08:30:00|1105432200|40795
#
# The output file name is the input file name with 'Q2_for_' in place of 'CT.',
# and is written to the directory 'CT_DATA' whose value is defined in the caller
# script. If the output file pathname already exists and the caller specifies
# the '-v' argument (for verbose output, then the user will be prompted
# whether to overwrite (delete) it or exit the script leaving the file as-is.
# Otherwise the output file will be overwritten silently if it exists.
#
# HISTORY:
# 02/20/2014   Morris      Created from get_Q2_TRMM_time_matches.sh.
#
###############################################################################

# check command line option for verbose output -- not a rigorous arguments check
verbose=0
while [ $# -gt 0 ]
  do
    case $1 in
      -v|--verbose) verbose=1; shift 1; predictfile=$1 ;;
                 *) predictfile=$1; shift 1 ;;
    esac
done

if [ $verbose -eq 1 ]
  then
    echo "$0:  Verbose Mode ON"
#  else
#    echo "$0: Verbose Mode OFF"
fi

if [ ! -d ${CT_DATA} ]
  then
    echo "CT_DATA directory: ${CT_DATA} non-existent!"
    echo "Check configuration in script.  Exiting."
    exit 1
  else
    if [ ! -w ${CT_DATA} ]
      then
        echo "CT_DATA directory: ${CT_DATA} has no write privilege! Exiting."
        exit 1
    fi
fi

if [ ! -s $predictfile ]
  then
    echo "Input filename does not exist or is empty: $predictfile"
    exit 2
fi

# cut the file base name out of the supplied pathname, and replace the leading
# 'CT.' characters
predictbase1=${predictfile##*/}
predictbase=`echo $predictbase1 | sed 's/^CT\./Q2_for_/'`
filedate=`echo $predictbase1 | cut -f3 -d '.'`

# NEW WAY - put output Q2 times file in same date-specific directory as the
# CT files are downloaded to

# cut the path to predictfile out, then prepend it to predictbase
predictdir=${predictfile%/*}
OUTFILE=${predictdir}/${predictbase}

TMPFILE1=${CT_DATA}/raw_overpass.$predictbase1
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
TMPFILE2=${CT_DATA}/Q2_overpass.$predictbase1
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


#OUTFILE=${CT_DATA}/${predictbase}  # OLD WAY, uses fixed directory, not yyyy/mm/dd
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

# get the satellite ID from the 1st line of the file (could get it from
# $predictbase1 or $predictfile)

bird=`head -1 $predictfile | cut -f1 -d ' '`

# run predict file through multiple sed commands to filter and format it,
# and output the the filtered/formatted lines to $TMPFILE1

# sed command 1: delete 9 header lines of CT file
# sed command 2: remove trailing space(s) at end of lines
# sed command 3: remove spaces between values on a line
# sed command 4: delete all lines not ending with a site code like 'Kxxx'
# sed command 5: delete all lines ending with the site code 'KWAJ'
# sed command 6: delete all lines ending with the site code 'KORA'
# sed command 7: replace comma between fields with a single | character
# sed command 8: replace T separator between date and time with a space
# sed command 9: strip decimal seconds from time

sed '
1,8 d
s/  *$//
s/  *//g
/.*,K[A-Z]\{3\}$/ !d
 /.*,KWAJ$/ d
 /.*,KORA$/ d
s/,/|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([:][0-9][0-9]\)\(.[0-9]\)|/\1|/g' <$predictfile >$TMPFILE1

if [ ! -s $TMPFILE1 ]
  then
    echo ""
    echo "No qualifying overpass events found in $predictfile"
    echo ""
    exit 1
fi

# read the filtered/formatted results and convert the TRMM time to the nearest Q2 time

# IF WE REALLY WANTED TO BE RIGOROUS, WE WOULD HAVE A FILE LISTING ALL THE CONUS
# NEXRAD SITE IDs AND grep AGAINST IT TO MAKE SURE WE DON'T CAPTURE ANY
# UNEXPECTED OVERPASS TIMES

while read line
  do
    # grab the orbit number
    orbit=`echo $line | cut -f1 -d '|'`
    # grab the datetime string
    textdate=`echo $line | cut -f5 -d '|'`
    # round datetime to nearest 5 minutes (Q2 time stamps)
    ticks=`env TZ=UTC date -d "$textdate" "+%s"`  # date option to convert to ticks
    a=$(($ticks+60))   # bash arithmetic syntax: $(( some operation ))
    b=$(($a/120))
    ticksQ2=$(($b*120))
    dtimeQ2=`env TZ=UTC date -d @$ticksQ2 "+%Y-%m-%d %T"`  # convert back FROM ticks
    # output the satellite, Q2 times, etc. to delimited file
    echo "$orbit|$ticksQ2|$bird|$dtimeQ2|$textdate" >> $TMPFILE2
done < $TMPFILE1

if [ $verbose -eq 1 ]
  then
    echo ""
    echo "$filedate NMQ 2-minute start, end times for each $bird orbit: "
    echo ""
fi

# loop over the sorted orbit/Q2time combos and determine the first and last
# (i.e., entry and exit) Q2 times for each.  Add a bogus "U" indicator for
# compatibility with prior code given to U of OK, since we don't have
# Ascending/Descending indicators in the CT files like in the TOFF output

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
                echo ${others}'|U|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} | tee -a $OUTFILE
              else
                echo ${others}'|U|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} >> $OUTFILE
            fi
        fi
        # grab the new orbit's data, setting end time same as start
        # in case it's the only entry for this orbit
        others=`echo $line2 | cut -f3 -d '|'`
        q2dtime=`echo $line2 | cut -f4 -d '|'`
        q2dtime2=$q2dtime
        q2ticks=`echo $line2 | cut -f2 -d '|'`
        q2ticks2=$q2ticks
      else
        # just get the new end time for the current orbit
        q2dtime2=`echo $line2 | cut -f4 -d '|'`
        q2ticks2=`echo $line2 | cut -f2 -d '|'`
   fi
   lastorbit=$orbit
done <<< "`cat $TMPFILE2`"

#output the last orbit read from the file also
if [ $verbose -eq 1 ]
  then
    echo ${others}'|U|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} | tee -a $OUTFILE
  else
    echo ${others}'|U|'${q2dtime}'|'${q2ticks}'|'${q2dtime2}'|'${q2ticks2}'|'${lastorbit} >> $OUTFILE
fi

# clean up this run's temporary files
if [ -s $TMPFILE1 ]
  then
    if [ $verbose -eq 1 ]
      then
        echo "Removing temporary file:  $TMPFILE1"
        rm -v $TMPFILE1
      else
        rm $TMPFILE1
    fi
fi

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

echo ""
echo "get_Q2_time_matches_from_CTs(): Output written to $OUTFILE:"
ls -al $OUTFILE
echo ""

exit 0

return
}
################################################################################

# Begin script

echo "====================================================" | tee -a $LOG_FILE
echo " Attempting download of coincidence files on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# USING HARD CODED LIST INSTEAD, FOR NOW - DEFINED IN 2 PLACES IN THIS SCRIPT!
#if [ ! -s ${SAT_LIST} ]
#  then
#    echo "Nonexistent or empty satellite list file: ${SAT_LIST}, exiting with error."\
#         | tee -a $LOG_FILE
#    exit 1
#fi

#  Get the date string for desired day's date by calling offset_date.
#  $switchtime is UTC HHMM after which yesterday's CT files are expected to
#  be available in PPS ftp directory.
switchtime=1503
now=`date -u "+%H%M"`

if [ `expr $now \> $switchtime` = 1 ]
  then
#    yesterday's file should be ready, get it
     ctdate=`offset_date $today -1`
  else
#    otherwise get file from two days back
     ctdate=`offset_date $today -2`
fi

#  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
julctdate=`ymd2yd $ctdate`
jjj=`echo $julctdate | cut -c 5-7`  # extracting just the jjj part

#  Get the subdirectory on the ftp site under which our day's data are located,
#  in the format YYYY/MM/DD
daydir=`echo $ctdate | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`

# make the new date-specific directory as required
mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE

#  Trim date string to use a 2-digit year for DB timestamp
yymmdd=`echo $ctdate | cut -c 3-8`

echo "Time is $now UTC, getting CT files for date $yymmdd" | tee -a $LOG_FILE

for sat in TRMM GPM GCOMW1 F15 F16 F17 F18 METOPA NOAA18 NOAA19
  do
    echo "" | tee -a $LOG_FILE
    echo "Checking whether we have necessary $sat files for this CT date."\
      | tee -a $LOG_FILE
    TARGET_CT=${daydir}/CT.${sat}.${ctdate}.${jjj}.txt
    ctfile=`ls ${CT_DATA}/${TARGET_CT}`
    if [ $? = 0 ]
      then
        echo "NOTE: Already have file ${ctfile}, not downloading again."\
    	      | tee -a $LOG_FILE
      else
        grep ${TARGET_CT} ${DBTEMPFILE} > /dev/null
        if  [ $? = 0 ]
          then
            echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
          else
            status=$UNTRIED
            echo "Adding ${TARGET_CT} to download list for today." | tee -a $LOG_FILE
            echo ${TARGET_CT} >> $TODAYSFILES
        fi
    fi
done

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "Checking whether we have prior missing CT datestamps to process."\
  | tee -a $LOG_FILE

echo "Check for actual prior attempts which failed for external reasons:"\
  | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
if [ -s ${DBTEMPFILE} ]
  then
    echo "Satellite/Dates of prior MISSING:" | tee -a $LOG_FILE
    cat ${DBTEMPFILE} | cut -f1 -d '|' | tee -a $LOG_FILE
    status=$MISSING
  else
    echo "No prior dates with status MISSING." | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Check for prior dates never attempted due to local problems:"\
  | tee -a $LOG_FILE
# Do so by looking for a gap in dates of >1 between last log file's datestamp
# and the current attempt date


nlogs=`ls ${LOG_DIR}/wgetAllCTdaily.* | grep -v $today | wc -l`
#echo "nlogs: "${nlogs}
if [ `expr $nlogs \> 0` = 1 ]
  then
    STAMPLAST=`ls ${LOG_DIR}/wgetAllCTdaily.* | grep -v $today | cut -f2 -d '.' | sort | tail -1`
    echo "" | tee -a $LOG_FILE
    echo "Date of last run logged was on $STAMPLAST" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    DATELAST=`echo $STAMPLAST | sed 's/ //'`
    DATEGAP=`grgdif $today $DATELAST`
    echo "Date gap: $DATEGAP days." | tee -a $LOG_FILE

    if [ `expr $DATEGAP \> 10` = 1 ]
      then
        echo "Date of last run ($DATELAST) more than 10 days ago, limiting lookback to 10 days."
        DATELAST=`offset_date $today -10`  # immediately gets incremented by 1, below
    fi

    while [ `expr $DATEGAP \> 1` = 1 ]
      do
        # if DATELAST was the last time script was run, it would have downloaded
        # the prior day's CT files, so the subsequent day's missed run would try
        # to get CT files for date DATELAST.  Just use DATELAST as the stamp for
        # the missed CT files and increment afterwards

        # but first check whether intended CT date is the same as current run's
        if [ $DATELAST -ne $ctdate ]
          then
            echo "No prior attempt of $DATELAST, set up to download files with this datestamp."\
              | tee -a $LOG_FILE
            # add this date to the temp file, for each satellite

            #  Get the subdirectory on the ftp site under which our day's data are located,
            #  in the format YYYY/MM/DD
            daydir=`echo $DATELAST | awk '{print substr($1,1,4)"/"substr($1,5,2)"/"substr($1,7,2)}'`
            # make the new date-specific directory as required
            mkdir -p -v ${CT_DATA}/${daydir} | tee -a $LOG_FILE
            #  Get the Julian representation of ctdate: YYYYMMDD -> YYYYjjj
            juldatelast=`ymd2yd $DATELAST`
            jjjLast=`echo $juldatelast | cut -c 5-7`  # extracting just the jjj part
            for sat in TRMM GPM GCOMW1 F15 F16 F17 F18 METOPA NOAA18 NOAA19
              do
                echo "Checking whether we have any $sat files with old CT date $DATELAST."\
                  | tee -a $LOG_FILE
                echo "" | tee -a $LOG_FILE
                TARGET_CT=${daydir}/CT.${sat}.${DATELAST}.${jjjLast}.txt
                ctfile=`ls ${CT_DATA}/${TARGET_CT}`
                if [ $? = 0 ]
                  then
                    echo "NOTE: Already have file ${ctfile}, not downloading again."\
                	      | tee -a $LOG_FILE
                  else
                    #echo "Adding ${TARGET_CT} to download list for old dates."
                    grep ${TARGET_CT} ${DBTEMPFILE} > /dev/null
                    if  [ $? = 0 ]
                      then
                        echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                      else
                        # check if date is a 5-time loser, ignore if so
                        if [ -s ${CTFAILURE} ]
                          then
                            grep ${TARGET_CT} ${CTFAILURE} > /dev/null
                            if  [ $? = 1 ]
                              then
                                echo "Adding ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                                echo ${TARGET_CT}"|0" >> ${DBTEMPFILE}
                                status=$MISSING
                              else
                                echo "${TARGET_CT} is 5-time loser, don't try to download." | tee -a $LOG_FILE
                            fi
                          else
                            # no 5-time loser file exists yet, just add to DBTEMPFILE.
                            echo "Adding ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            echo ${TARGET_CT}"|0" >> ${DBTEMPFILE}
                            status=$MISSING
                        fi
                    fi
                  fi
            done
        else
          echo "Intended missing day $DATELAST is same as current day $ctdate."
        fi
        # NOW increment run date and check against current day
        DATELAST=`offset_date $DATELAST 1`
        DATEGAP=`grgdif $today $DATELAST`
        echo "" | tee -a $LOG_FILE
    done
  else
    echo "No prior run log files found, assuming first-time run."  | tee -a $LOG_FILE
fi

echo "Today's new download list:"
if [ -s $TODAYSFILES ]
  then
    cat $TODAYSFILES
fi

if [ -s ${DBTEMPFILE} ]
  then
     echo "" | tee -a $LOG_FILE
     echo "Need to retry downloads for missing CT file dates below:" \
       | tee -a $LOG_FILE
     cat ${DBTEMPFILE} | tee -a $LOG_FILE
     have_retries='t'
  else
     echo "" | tee -a $LOG_FILE
     echo "No missing prior CT dates found." | tee -a $LOG_FILE
     if [ $status = $SUCCESS ]
       then
	  echo "All CT acquisition seems up-to-date, exiting."\
	   | tee -a $LOG_FILE
	  exit 0
     fi
fi
# exit

# Get the missing old files first, if needed
if [ $have_retries = 't' ]
  then
    echo "Getting old missing CT files." | tee -a $LOG_FILE
    for entry in `cat ${DBTEMPFILE}`
      do
        file=`echo $entry | cut -f1 -d '|'`
        times=`echo $entry | cut -f2 -d '|'`
        daydir=`echo $file | cut -f1-3 -d'/'`
        # increment the number of tries, up to 5.  After that, remove from
        # DBTEMPFILE and write failed download info to CTFAILURE file
        newtimes=`expr $times \+ 1`
        if [ `expr $newtimes \> 5` = 1 ]
          then
            echo ""
            echo "Failed to get ${file} after $times tries." | tee -a $LOG_FILE
            echo "Adding this entry to FAILURES file: ${CTFAILURE}"
            #cp ${DBTEMPFILE} ${TEMPCOPY}
            #cat ${TEMPCOPY} | grep -v ${file} > ${DBTEMPFILE}
            echo ${file} >> ${CTFAILURE}
          else
            echo "Get ${file} from PPS ftp site." | tee -a $LOG_FILE
            wget -P ${CT_DATA}/${daydir}  --user=$USERPASS --password=$USERPASS \
                 $FIXEDPATH/${file}
            ctfile=`ls ${CT_DATA}/${TARGET_CT}` | tee -a $LOG_FILE
            if [ $? = 0 ]
              then
	        echo "${CT_DATA}/$file" >> $FILES2DO
                echo "Got prior missing file ${file}" | tee -a $LOG_FILE
                # remove this entry from DBTEMPFILE
                cp ${DBTEMPFILE} ${TEMPCOPY}
                cat ${TEMPCOPY} | grep -v ${file} > ${DBTEMPFILE}
                rm ${TEMPCOPY}
	      else
	        echo "Failed to retrieve ${file} from PPS ftp site!" \
	        	   | tee -a $LOG_FILE
                     # edit the file in place, incrementing # of attempts by 1
                     # note the use of double quotes to allow variable substitution
                     fileAndTimes=`echo ${entry} | cut -f4 -d '/'`
                     basefile=`echo ${fileAndTimes} | cut -f1 -d '|'`
                     sed -i "s/${fileAndTimes}/${basefile}|${newtimes}/" ${DBTEMPFILE}
            fi
	fi
    done
fi

# Next, get the current file if needed.  We will make multiple attempts at it as
# it might just be late, whereas we will only try once each to get other missing
# files.

if [ $status != $SUCCESS ]
  then
     for TARGET_CT in `cat $TODAYSFILES`
       do
         echo ""  | tee -a $LOG_FILE
         echo "Download current file ${TARGET_CT} from PPS"  | tee -a $LOG_FILE
         ctfile=`ls ${CT_DATA}/${TARGET_CT}`

         # If desired file was already downloaded and processed, report as such
         if [ $? = 0 ]
           then
              runagain='n'
              echo "WARNING:  File $ctfile already exists, not downloading again." \
	        | tee -a $LOG_FILE
           else
              runagain='y'
         fi

         # Use wget to download coincidence file from PPS ftp site. 
         # Repeat attempts at intervals of $ZZZ seconds if file is not retrieved in
         # first attempt.  If file is still not found, record the failure to try
         # to get it again in the next days' run(s) of the script.

         declare -i tries=0

         until [ "$runagain" = 'n' ]
           do
              tries=tries+1
              echo "Try = ${tries}, max = 5." | tee -a $LOG_FILE
              daydir=`echo $TARGET_CT | cut -f1-3 -d'/'`
              wget -P ${CT_DATA}/${daydir} --user=$USERPASS --password=$USERPASS \
                   $FIXEDPATH/${TARGET_CT}
              ctfile=`ls ${CT_DATA}/${TARGET_CT}`
              if [ $? = 0 ]
                then
                   runagain='n'
                   ls ${CT_DATA}/${TARGET_CT} | tee -a $LOG_FILE
                   echo "${CT_DATA}/${TARGET_CT}" >> $FILES2DO
                   echo "Got it!  Mark success in database:" | tee -a $LOG_FILE
                   echo "" | tee -a $LOG_FILE
                else
                   if [ $tries -eq 2 ]
                     then
                        runagain='n'
                        echo "Failed after 2 tries, giving up." | tee -a $LOG_FILE
                        #echo "Adding ${TARGET_CT} to download list for old dates."
                        entry=`grep ${TARGET_CT} ${DBTEMPFILE}`
                        if  [ $? = 0 ]
                          then
                            echo "Already have ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            file=`echo $entry | cut -f1 -d '|'`
                            times=`echo $entry | cut -f2 -d '|'`
                            # edit the file in place, incrementing # of attempts by 1
                            # note the use of double quotes to allow variable substitution
                            newtimes=`expr $times \+ 1`
                            fileAndTimes=`echo ${entry} | cut -f4 -d '/'`
                            basefile=`echo ${fileAndTimes} | cut -f1 -d '|'`
                            sed -i "s/${fileAndTimes}/${basefile}|${newtimes}/" ${DBTEMPFILE}
                          else
                            echo "Adding ${TARGET_CT} in ${DBTEMPFILE}." | tee -a $LOG_FILE
                            echo ${TARGET_CT}"|1" >> ${DBTEMPFILE}
                            status=$MISSING
                        fi
                     else
                        echo "Failed to get file, sleeping $ZZZ s before next try."\
	                  | tee -a $LOG_FILE
                        sleep $ZZZ
                   fi
              fi
         done    # until [ "$runagain" = 'n' ] loop
     done        # for TARGET_CT in `cat $TODAYSFILES`
fi

echo "" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

#  Check for presence of downloaded files, process if any

if [ -s $FILES2DO ]
  then
     echo "Calling get_Q2_time_matches_from_CTs() to process file(s):" | tee -a $LOG_FILE
     cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     for iofile in `cat $FILES2DO`
       do
          echo "Process this CT file for NMQ time matching:" \
	    | tee -a $LOG_FILE
          ls -al $iofile | tee -a $LOG_FILE
	  echo "" | tee -a $LOG_FILE
          get_Q2_time_matches_from_CTs -v $iofile | tee -a $LOG_FILE
     done
  else
    echo "File $FILES2DO not found, no new CT files or downloads failed." \
      | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
