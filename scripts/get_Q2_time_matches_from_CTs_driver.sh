#!/bin/sh
#
################################################################################
#
#  get_Q2_time_matches_from_CTs_driver.sh     Morris/SAIC/GPM GV     Aug 2016
#
#  DESCRIPTION
#    Converts core/constellation satellite coincidence files for a specified
#    satellite to a list of starting and ending Q2 times.  Builds a list of all
#    CT files in the GPM Validation Network file system for the satellite and
#    for each CT file, get_Q2_time_matches_from_CTs.sh is invoked to identify
#    those Q2 times coincident with the satellite overpasses.
#
#    CT file pattern is "CT.SSSS.yyyymmdd.jjj.txt" and they are located in the
#    subdirectory CT_DATA.
#
#    The CT file naming convntion is CT.SSSS.yyyymmdd.jjj.txt, where:
#
#          CT - literal characters 'CT'
#        SSSS - ID of the satellite, variable length character field
#    yyyymmdd - year (4-digit), month, and day of the overpass data
#         jjj - day of year (Julian day), zero-padded to 3 digits
#         txt - literal characters 'txt'
#
#
#  INTERNAL ROUTINES CALLED
#    get_Q2_time_matches_from_CTs()  - Matches up Q2 product times
#                                      to satellite coincidence times.
#
#  FILES
#    CT.SSSS.yyyymmdd.jjj.txt
#      - CT files in the VN file system.
#    Q2_for_SSSS.yyyymmdd.jjj.txt
#      - Output file listing rounded NMQ start/end times for CONUS site orbit
#        overpasses contained in CT.SSSS.yyyymmdd.jjj.txt.
#    CTs_To_Process
#      - File holding a listing of file pathnames of CT files
#        for the specified satellite which are to be
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
#    Aug 2016 - Morris - Created.
#
################################################################################


##################### local configuration items ############################
DATA_DIR=/data/gpmgv
CT_DATA=${DATA_DIR}/coincidence_tables      # original and transformed CTs
export CT_DATA
LOG_DIR=/data/logs

today=`date -u +%Y%m%d`
LOG_FILE=${LOG_DIR}/get_Q2_time_matches_from_CTs_driver.log  # fixed name
PATH=${PATH}:${BIN_DIR}
ZZZ=2

umask 0002

# file listing full pathnames of all CT files to be post-processed to
# compute matching NMQ start/end times
FILES2DO=${CT_DATA}/CTs_To_Process
rm -fv $FILES2DO | tee -a $LOG_FILE


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
    # round datetime to nearest 2 minutes (Q2 time stamps)
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
echo " Processing coincidence files for NMQ on $today." | tee -a $LOG_FILE
echo "----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


for sat in  NPP
  do
    echo "" | tee -a $LOG_FILE
    echo "Checking whether we have necessary $sat files for this CT date."\
      | tee -a $LOG_FILE
    TARGET_CT='CT.'${sat}'.*.txt'
    ls ${CT_DATA}/*/*/*/${TARGET_CT} >> $FILES2DO
done
echo "" | tee -a $LOG_FILE

#  Check for presence of downloaded files, process if any

if [ -s $FILES2DO ]
  then
     echo "Calling get_Q2_time_matches_from_CTs() to process file(s):" | tee -a $LOG_FILE
#     cat $FILES2DO | tee -a $LOG_FILE
     echo "" | tee -a $LOG_FILE

     for iofile in `cat $FILES2DO`
       do
#          echo "Process this CT file for NMQ time matching:" \
#	    | tee -a $LOG_FILE
          ls -al $iofile | tee -a $LOG_FILE
#	  echo "" | tee -a $LOG_FILE
          get_Q2_time_matches_from_CTs -v $iofile | tee -a $LOG_FILE
     done
  else
    echo "File $FILES2DO not found, no CT files found." \
      | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "================== END OF RUN =====================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

exit
