#!/bin/sh

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

if [ ! -s $predictfile ]
  then
    echo "Input filename does not exist or is empty: $predictfile"
    exit 2
fi

# cut the file base name out of the supplied pathname, and replace the extension
# with '.UFtimes'
predictbase1=${predictfile##*/}
predictbasepre=`echo $predictbase1 | cut -f1 -d '.'`
predictbase=${predictbasepre}.UFtimes

# NEW WAY - put output Q2 times file in same date-specific directory as the
# CT files are downloaded to

# cut the path to predictfile out, then prepend it to predictbase
predictdir=${predictfile%/*}
OUTFILE=${predictdir}/${predictbase}

TMPFILE1=/tmp/raw_overpass.$predictbase1
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
TMPFILE2=/tmp/CP2_overpass.$predictbase1
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


if [ -s $OUTFILE ]
  then
    if [ $verbose -eq 1 ]
      then
        # give user the option to overwrite file or leave it and exit early
        echo ""
        echo "Output file ${OUTFILE} already exists:"
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

# sed command 1: remove trailing space(s) at end of lines
# sed command 2: remove '+00' at end of time fields

sed '
s/  *$//
s/+00//g
' <$predictfile >$TMPFILE1

if [ ! -s $TMPFILE1 ]
  then
    echo ""
    echo "No qualifying overpass events found in $predictfile"
    echo ""
    exit 1
fi
head $TMPFILE1
#exit

# read the filtered/formatted results and convert the overpass time to the nearest CP2 time

while read line
  do
    # grab the datetime string
    textdate=`echo $line | cut -f3 -d '|'`
    # round datetime to nearest 6 minutes (CP2 time stamps)
    ticks=`env TZ=UTC date -d "$textdate" "+%s"`  # date option to convert to ticks
    a=$(($ticks+180))   # bash arithmetic syntax: $(( some operation ))
    b=$(($a/360))
    ticksQ2=$(($b*360))
    dtimeQ2=`env TZ=UTC date -d @$ticksQ2 "+%Y-%m-%d %T"`  # convert back FROM ticks
    filetimes=`echo $dtimeQ2 | sed 's/ /_/' | sed 's/:00$//'`
    # output the satellite, Q2 times, etc. to delimited file
    echo "CP2_ppi_gpm_${filetimes}*.PPI.UF.gz" >> $OUTFILE
done < $TMPFILE1

cat $OUTFILE

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
echo "get_CP2_UF_Time_from_Overpasses(): Output written to $OUTFILE:"
ls -al $OUTFILE
echo ""

exit 0
