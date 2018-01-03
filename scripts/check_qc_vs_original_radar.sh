#!/bin/sh

# check_qc_vs_original_radar.sh
#
# Lists corresponding QC'ed UF files and original WSR-88D Level II Archive
# files in the VN data archive.  Takes a daily log file from catalogQCradar.sh
# to generate the list of files to compare.

# Takes one mandatory argument: the yymmdd value of the daily log file to be
# read; and one optional argument: the root 'data' directory on the local host.


if [ $# \< 1 ]
  then
     echo "USAGE: check_qc_vs_original_radar.sh yymmdd"
     echo "FATAL: Exactly one argument required (yymmdd), $# given."
     exit 1
fi

yymmdd=$1

if [ $# = 2 ]
  then
    DATA_DIR=$2
  else
    DATA_DIR=/data/gpmgv
fi

RADAR_DIR=$DATA_DIR/gv_radar
LOG_DIR=$DATA_DIR/logs

if [ ! -s $LOG_DIR/catalogQCradar.${yymmdd}.log ]
  then
    echo ""
    echo "ERROR!  Log file $LOG_DIR/catalogQCradar.${yymmdd}.log not found or empty."
    exit 1
fi

last_ufdir="/"

#cat $LOG_DIR/catalogQCradar.${yymmdd}.log | grep "1CUF"

while read line
  do
    entry=`echo -e "$line"`
    echo "$entry" | grep "<<<<" > /dev/null 2>&1
    if [ $? = 0 ]
      then
         site=`echo "$entry" | cut -f7 -d ' '`
         echo ""
         echo "======== $site ========="
         echo ""
         last_ufdir="/"
    fi
    echo "$entry" | grep "1CUF" > /dev/null 2>&1
    if [ $? = 0 ]
      then
         ufdir=`echo "$entry" | cut -f1-3 -d '/'`
         if [ "$last_ufdir" != "$ufdir" ]
           then
             l2rawdir=`echo $ufdir | sed 's/1CUF/raw/'`
             ls -al $RADAR_DIR/finalQC_in/${site}/${ufdir}/*.gz
             ls -al $RADAR_DIR/defaultQC_in/${site}/${ufdir}/*.gz
             ls -al $RADAR_DIR/defaultQC_in/${site}/${l2rawdir}/*.gz
             echo ""
             last_ufdir=$ufdir
         fi
    fi
done  < $LOG_DIR/catalogQCradar.${yymmdd}.log

exit
