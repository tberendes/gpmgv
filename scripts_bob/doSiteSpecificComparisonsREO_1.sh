#!/bin/sh
################################################################################
#
# doSiteSpecificComparisonsREO_1.sh
#
# Prepare a site-by-site control file listing the PR and GV netcdf grid files
# available in /data/netcdf[PR|NEXRAD_REO/allYMD], and invoke IDL to generate
# reflectivity comparison products for each site.
#
# Takes one optional argument:  the 4-letter ID of the site for which to run the
# comparison, if running only for a single site.  Otherwise all sites for which
# data are available are used.
#
################################################################################

GV_BASE_DIR=/home/morris/swdev
IDL_PRO_DIR=${GV_BASE_DIR}/idl/dev/comparez
export IDL_PRO_DIR                 # IDL .bat file needs this
IDL=/usr/local/bin/idl
DATA_DIR=/data
TMP_DIR=${DATA_DIR}/tmp
ZZZ=1800                   # sleep 30 minutes at a time waiting for IDL license
declare -i naps=8          # sleep up to 4 hours

umask 0002

if [ $# -gt 1 ]
  then
     echo "FATAL:  Zero or one argument required, $# given." | tee -a $LOG_FILE
     echo "USAGE:  doSiteSpecificComparisonsREO.sh"
     echo "   OR:  doSiteSpecificComparisonsREO.sh  SITE_ID"
     exit 1
fi


if [ $# = 1 ]
  then
    THISSITE='*'${1}'*'
  else
    THISSITE='*'
fi

# Remove the existing control file, if any.

outfile=${TMP_DIR}/doSiteSpecificComparisonsREO.txt
if [ -f $outfile ]
  then
    rm -v $outfile
fi

touch $outfile

# Prepare the control file for current files/sites available.

cd ${DATA_DIR}/netcdf/PR
for site in `ls PRgrids.${THISSITE} | cut -f2 -d '.' | sort -u`
  do
    count=`ls ${DATA_DIR}/netcdf/PR/PRgrids.${site}.* | wc -l`
    echo "$site|$count" | tee -a $outfile
    for prfile in `ls ${DATA_DIR}/netcdf/PR/PRgrids.${site}.*`
      do
        gvfile=`echo $prfile | sed 's=PR/PRgrids=NEXRAD_REO/allYMD/GVgridsREO='`
        if [ -s $gvfile ]
          then
            echo "$prfile|$gvfile" | tee -a $outfile
          else
            echo ""
            echo "MISSING: no matching NEXRAD_REO file for $prfile !"
            echo "${prfile}|no_GV_file" | tee -a $outfile
        fi
    done
done

if [ ! -s $outfile ]
  then
    echo ""
    echo "No data in control file $outfile, aborting run!"
    exit 0
fi

SSCFILES=$outfile
export SSCFILES

# check whether the IDL license manager is running. If not, we are done for,
# and will have to exit and leave the input run date flagged as one to be
# re-run next time
ps -ef | grep "rsi/idl" | grep lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    echo "FATAL: IDL license manager not running!" | tee -a $LOG_FILE
    exit 1
fi

# check whether the IDL license is tied up by another user.  Sleep a few times
# until it comes free.  If we time out, then leave the input run date flagged
# as one to be re-run next time, and exit.

ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
if [ $? = 1 ]
  then
    idl_free='t'
  else
    idl_free='f'
fi

declare -i napnum=1
until [ "$idl_free" = 't' ]
  do
    echo "" | tee -a $LOG_FILE
    echo "Attempt $napnum, waiting $ZZZ seconds for IDL license to free up."\
     | tee -a $LOG_FILE
    #sleep $ZZZ
    sleep 3         # sleep value for testing
    napnum=napnum+1
    if [ $napnum -gt $naps ]
      then
	echo "" | tee -a $LOG_FILE
	echo "Exiting after $naps attempts to get IDL license."\
	 | tee -a $LOG_FILE
	exit 1
    fi
    ps -ef | grep "rsi/idl" | grep -v lmgrd | grep -v grep > /dev/null 2>&1
    if [ $? = 1 ]
      then
        idl_free='t'
    fi
done

echo "" | tee -a $LOG_FILE
echo "=============================================" | tee -a $LOG_FILE
echo "Calling IDL for file = $SSCFILES" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
        
 $IDL < ${IDL_PRO_DIR}/doSiteSpecificComparisons.bat | tee -a $LOG_FILE 2>&1

echo "=============================================" | tee -a $LOG_FILE
