#!/bin/sh
################################################################################
#
#  catalogQCradar.sh     Morris/SAIC/GPM GV     October 2006
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the /data/gv_radar/finalQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradar'.
#
#  FILES
#   lsKXXXfinal.new  (output; listing of current file pathnames under directory
#                     /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXXfinal.old  (output; prior listing of file pathnames under directory
#                     /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXX.diff  (output; difference between lsKXXX.new and lsKXXX.old
#                 files; XXX varies by radar site)
#   finalQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' (temporarily) and 'gvradar' (permanently)
#    tables in 'gpmgv' database.  Logic is contained in SQL commands in file
#    catalogQCradar.sql, run in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalogQCradar.YYMMDD.log in /data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', SELECT/INSERT privileges on table 'gvradar', and
#    SELECT/INSERT/DELETE privileges on table 'gvradartemp'.  Utility
#    'psql' must be in user's $PATH.
#
################################################################################

GV_BASE_DIR=/home/morris/swdev   # MODIFY PATH FOR OPERATIONAL VERSION
DATA_DIR=/data
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=${DATA_DIR}/logs

SQL_BIN=${BIN_DIR}/catalogQCradar.sql
loadfile=${DATA_DIR}/tmp/finalQC_KxxxMeta.unl

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogQCradarFaster.${rundate}.log
DB_LOG_FILE=${LOG_DIR}/catalogQCradarSQL.log
runtime=`date -u`

umask 0002

echo "=====================================================" | tee $LOG_FILE
echo " Catalog any new TRMM GVS final QC radar files as of " | tee -a $LOG_FILE
echo "        $runtime" | tee -a $LOG_FILE
echo "-----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    echo "Message from catalogQCradar.sh cron job on ${runtime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ws1-gpmgv' pankaj.jaiswal@nasa.gov \
      -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 3." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

################################################################################
function dbfileprep() {

# function formats file metadata into delimited text file, for loading into
# table 'gvradartemp' in 'gpmgv' database.  Takes 3 args: full file pathname,
# radar ID, and name of delimited text file to write output into

type=`echo $1 | cut -f1 -d'/'`
#echo "orig_type = $type"
pathless=`echo $1 | cut -f4 -d'/'`
sitepath=`echo $1 | cut -f1-3 -d'/'`
if [ "$type" = "level_2" ]
  then
     if [ $pathless = "options" ]
       then
         echo "Skipping file $1"
	 return
     fi
     type=`echo $pathless | cut -c1-4`
     year=`echo $1 | cut -f2 -d'/'`
     mmdd=`echo $pathless | cut -f2 -d'.' | cut -c3-6 | awk '{print \
           substr($1,1,2)"-"substr($1,3,2)}'`
     datestr=${year}'-'${mmdd}
  else
     datestr=`echo $1 | cut -f2-3 -d'/' | awk '{print \
              substr($1,1,4)"-"substr($1,6,2)"-"substr($1,8,2)}'`
fi
#echo "datatype = $type"
#echo "datestr = $datestr"
# nominal hour value in filename for 1CUF,1C51,2A54,2A55 runs from 1-24,
# convert to 00:00 to 23:00 for loading in database
case $type in
                1CUF )  dtime=`echo $pathless | cut -f2 -d'.'`
		        dtime=`expr $dtime - 1`
			dtime=${dtime}":00" ;;
  2A53 | 2A54 | 2A55 | 1C51 )  dtime=`echo $pathless | cut -f3 -d'.'`
		        dtime=`expr $dtime - 1`
			dtime=${dtime}":00" ;;
              images )  dtime=`echo $pathless | cut -f2 -d'.' | awk '{print \
                               substr($1,1,2)":"substr($1,3,2)}'` ;;
                   * )  ;;
esac

# add preceding zero to hour if needed.  First cut hh out of hh or hh:mm string
dthr=`echo $dtime | cut -f1 -d':'`
# if ( hh < 12 ) AND ( length_of_hh_string = 1 ) THEN PREPEND '0' to timestring
if [ `expr $dthr \< 10` = 1  -a  ${#dthr} = 1  ]
  then
     dtime='0'$dtime
fi

dtimestr=${datestr}' '${dtime}"+00"
echo "${type}|$2|${dtimestr}|${sitepath}|${pathless}" >> $3
return
}
################################################################################

# Begin script

rm -v $loadfile

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -30`
ystart=`echo $ymdstart | cut -c1-4`

# after 30 days we will no longer try to catalog last year's files, 
# as $ystart will be the current year, the same as $yend
if [ "$ystart" != "$yend" ]
  then
    years="${ystart} ${yend}"
  else
    years=${yend}
fi

echo ""

for yr2do in $years
  do
    echo "Year to do = $yr2do"
done

for Kxxx in `ls $QCDATADIR`
#for Kxxx in KTLH              # for testing, just do one site
  do
    echo "" | tee -a $LOG_FILE
    echo "<<<< Processing received files for site $Kxxx >>>>"\
      | tee -a $LOG_FILE

    # This file will hold a listing of files in tree at time of this run:
    tmpfile=/data/tmp/ls${Kxxx}finalTest.new

    # This file holds the listing of files in tree at time of prior run:
    tmpfileold=/data/tmp/ls${Kxxx}finalTest.old

    # This file will hold the 'diff tmpfile tmpfileold' command output:
    tmpfilediff=/data/tmp/ls${Kxxx}finalTest.diff

    # Move last run's tmpfile (if any) to be the 'old' file
    if [ -f $tmpfile ]
      then
        echo ""
	mv -fv $tmpfile $tmpfileold | tee -a $LOG_FILE 2>&1
	echo "" | tee -a $LOG_FILE
    fi

    # Create empty 'old' file if no prior tmpfile:
    if [ ! -f $tmpfileold ]
      then
        touch $tmpfileold
    fi

    cd $QCDATADIR/$Kxxx

# List the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

    for yr2do in $years
      do
        for file in `ls -R */$yr2do`
          do
            # a directory under which files or immediate subdirs are about
            # to be listed has a ':' at the end of the name, replace with '/'
            # and save for prepending to any regular files listed under it
            echo $file | grep ':' > /dev/null 2>&1
            if [ $? = 0 ]
              then
                # is a directory with files under it, prepare the path
                subdir=`echo $file | sed 's|:|/|'`
              else
                # is this a regular file or just a subdirectory?
                if [ -f ${subdir}${file} ]
                  then
                    # is regular file, add path and write to $tmpfile
                    echo ${subdir}${file} >> $tmpfile
                fi
            fi
        done
    done
# difference the old and new file listings to see what's been added to (or
# unexpectedly removed from or changed in) the local directory tree since last
# time script was run

    diff $tmpfileold $tmpfile | sed 's/^[<>] //' > $tmpfilediff
    additions='f'

# walk thru the diff file and take action depending on filename or diff command
    for entry in `cat $tmpfilediff`
      do
        # skip divider lines in diff output
	if [ "$entry" = "---" ]
          then
            continue
        fi
	# skip log_Kxxx.txt files in site root directory
	echo $entry | grep "log_${Kxxx}.txt" > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo "Skipping log file $entry" | tee -a $LOG_FILE
	    continue
        fi
        echo $entry | grep "^[0-9][0-9]*a[0-9][0-9]*" > /dev/null 2>&1
        if [ $? = 0 ]
          then
            echo "" | tee -a $LOG_FILE
	    echo "begin block of additions: $entry" | tee -a $LOG_FILE
	    additions='t'
          else
            echo $entry | grep "^[0-9][0-9]*,*[0-9]*d[0-9][0-9]*"\
	       > /dev/null 2>&1
	    if [ $? = 0 ]
              then
                echo ""
		echo "UPLOAD ERROR? - begin block of deletions: $entry"\
		 | tee -a $LOG_FILE
	        additions='f'
	      else
	        # any more cases other than "c"hange in diff?  TBD
                echo $entry | grep "^[0-9][0-9]*,*[0-9]*c[0-9][0-9]*"\
	           > /dev/null 2>&1
	        if [ $? = 0 ]
                  then
                    echo ""
		    echo "UPLOAD ERROR? - begin block of changes: $entry"\
		     | tee -a $LOG_FILE
	            additions='f'
	          else
	            # Finally gets here if a file (i.e., not a 'diff' string)
		    file=`echo $entry`
	            if [ "$additions" = 't' ]
	              then
                        echo "Catalog new file:" | tee -a $LOG_FILE
			echo "$file" | tee -a $LOG_FILE
		        dbfileprep $file $Kxxx $loadfile | tee -a $LOG_FILE
	              else
                        echo "Ignoring deleted/changed file:"\
                         | tee -a $LOG_FILE
			echo "$file" | tee -a $LOG_FILE
	            fi
		fi
	    fi
        fi
    done
done

echo "" | tee -a $LOG_FILE

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database:" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN | psql -a -d gpmgv" | tee $DB_LOG_FILE 2>&1
	if [ ! -s $DB_LOG_FILE ]
	  then
            echo "FATAL: SQL log file $DB_LOG_FILE empty or not found!"\
              | tee -a $LOG_FILE
	    echo "Saving catalog file:"
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
            exit 1
	fi
	cat $DB_LOG_FILE >> $LOG_FILE
	grep -i ERROR $DB_LOG_FILE > /dev/null
	if  [ $? = 0 ]
	  then
	    echo "Error loading file to database.  Saving catalog file:"\
	     | tee -a $LOG_FILE
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
	fi
      else
        echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
          | tee -a $LOG_FILE
	echo "Saving catalog file:"
	mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
        exit 1
    fi
  else
    echo "No new file catalog info to load to database for this run."\
     | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Script complete, exiting." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
exit
