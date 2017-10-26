#!/bin/sh
################################################################################
#
#  listKXXXdirs.sh     Morris/SAIC/GPM GV     September 2006
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the /data/gv_radar/finalQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradartemp'.
#
#  FILES
#   lsKXXX.new  (output; listing of current file pathnames under the directory
#                /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXX.old  (output; prior listing of file pathnames under the directory
#                /data/gv_radar/finalQC_in; XXX varies by radar site)
#   lsKXXX.diff  (output; difference between lsKXXX.new and lsKXXX.old
#                 files; XXX varies by radar site)
#   finalQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' table in 'gpmgv' database, run in
#    PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    listKXXXdirs.YYMMDD.log in /data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', and INSERT privileges on tables.  Utility
#    'psql' must be in user's $PATH.
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

DATADIR=/data/gv_radar/finalQC_in
loadfile=/data/tmp/finalQC_KxxxMeta.unl
umask 0002

# function formats file metadata into delimited text file, for loading into
# table 'gvradartemp' in 'gpmgv' database.  Takes 3 args: full file pathname,
# radar ID, and name of delimited text file to write output into
function dbfileprep() {
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
  2A54 | 2A55 | 1C51 )  dtime=`echo $pathless | cut -f3 -d'.'`
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
echo "${type}|$2|${dtimestr}|${sitepath}|${pathless}" | tee -a $3
return
}

rm -v $loadfile

#for Kxxx in `ls $DATADIR`
for Kxxx in KTLH # for testing, just do one site
  do
    echo ""
    echo "<<<< Processing received files for site $Kxxx >>>>"
    # holds list of files in tree at time of this run
    tmpfile=/data/tmp/ls${Kxxx}final.new

    # holds list of files in tree at time of prior run
    tmpfileold=/data/tmp/ls${Kxxx}final.old

    # holds output of diff between tmpfile and tmpfileold 
    tmpfilediff=/data/tmp/ls${Kxxx}final.diff

    if [ -f $tmpfile ]
      then
        echo ""
	mv -fv $tmpfile $tmpfileold
	echo ""
    fi

    if [ ! -f $tmpfileold ]
      then
        touch $tmpfileold
    fi

    cd $DATADIR/$Kxxx

# list the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

    for file in `ls -R *`
      do
        # a directory under which files or immediate subdirectories are about
        # to be listed has a ':' at the end of the name, replace w. '/' and
        # save for prepending to any regular files listed under it
        echo $file | grep ':' > /dev/null 2>&1
        if [ $? = 0 ]
          then
            subdir=`echo $file | sed 's|:|/|'`
          else
            if [ -f ${subdir}${file} ]
              then
                echo ${subdir}${file} >> $tmpfile
            fi
        fi
    done

# difference the old and new file listings to see what's been added to or
# removed from the local directory tree since last time

    diff $tmpfileold $tmpfile | sed 's/^[<>] //' > $tmpfilediff

    additions='f'

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
            echo "Skipping log file $entry"
	    continue
        fi
        echo $entry | grep "^[0-9][0-9]*a[0-9][0-9]*" > /dev/null 2>&1
        if [ $? = 0 ]
          then
            echo ""
	    echo begin block of additions: $entry
	    additions='t'
          else
            echo $entry | grep "^[0-9][0-9]*,*[0-9]*d[0-9][0-9]*"\
	       > /dev/null 2>&1
	    if [ $? = 0 ]
              then
                echo ""
		echo "ERROR? - begin block of deletions: $entry"
	        additions='f'
	      else
	      # what about the "N,McX" & other cases in diff?
                echo $entry | grep "^[0-9][0-9]*,*[0-9]*c[0-9][0-9]*"\
	           > /dev/null 2>&1
	        if [ $? = 0 ]
                  then
                    echo ""
		    echo "ERROR? - begin block of changes: $entry"
	            additions='f'
	          else
	            file=`echo $entry`
	            if [ "$additions" = 't' ]
	              then
                        echo "Catalog new file:"
			echo $file
		        dbfileprep $file $Kxxx $loadfile
	              else
                        echo "Ignoring deleted/changed file:"
			echo $file
	            fi
		fi
	    fi
        fi
    done
done

echo ""
if [ -s $loadfile ]
  then
    echo "Loading metadata for new files to database:"
    echo ""
    echo "\copy gvradartemp from '$loadfile' WITH DELIMITER '|'"  \
      | psql -a -d gpmgv | tee -a $logfile 2>&1
  else
    echo "No new file metadata to load to database for this run."
fi
echo ""
echo "Script complete, exiting."
echo ""
exit
