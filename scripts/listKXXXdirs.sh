#!/bin/sh
################################################################################
#
#  listKXXXdirs.sh     Morris/SAIC/GPM GV     September 2006
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the /data/gv_radar/defaultQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradartemp'.
#
#  FILES
#   lsKXXX.new  (output; listing of current file pathnames under the directory
#                /data/gv_radar/defaultQC_in; XXX varies by radar site)
#   lsKXXX.old  (output; prior listing of file pathnames under the directory
#                /data/gv_radar/defaultQC_in; XXX varies by radar site)
#   lsKXXX.diff  (output; difference between lsKXXX.new and lsKXXX.old
#                 files; XXX varies by radar site)
#   defaultQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
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

DATADIR=/data/gv_radar/defaultQC_in
loadfile=/data/tmp/defaultQC_KxxxMeta.unl

# function formats file metadata into delimited text file, for loading into
# table 'gvradartemp' in 'gpmgv' database.  Takes 3 args: full file pathname,
# radar ID, and name of delimited text file to write output into
function dbfileprep() {
type=`echo $1 | cut -f1 -d'/'`
#echo "type = $type"
datestr=`echo $1 | cut -f2-3 -d'/' | awk '{print \
         substr($1,1,4)"-"substr($1,6,2)"-"substr($1,8,2)}'`
#echo "datestr = $datestr"
echo "${type}|$2|${datestr}|$1" | tee -a $3
return
}

rm -v $loadfile

for Kxxx in `ls $DATADIR`
  do
    echo ""
    echo "<<<< Processing received files for site $Kxxx >>>>"
    # holds list of files in tree at time of this run
    tmpfile=/data/tmp/ls${Kxxx}.new

    # holds list of files in tree at time of prior run
    tmpfileold=/data/tmp/ls${Kxxx}.old

    # holds output of diff between tmpfile and tmpfileold 
    tmpfilediff=/data/tmp/ls${Kxxx}.diff

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
        if [ "$entry" = "---" ]
          then
            continue
        fi
        echo $entry | grep "^[0-9][0-9]*a[0-9][0-9]*" > /dev/null 2>&1
        if [ $? = 0 ]
          then
            echo ""
	    echo begin block of additions: $entry
	    additions='t'
          else
            echo $entry | grep "^[0-9][0-9]*,[0-9][0-9]*d[0-9][0-9]*"\
	       > /dev/null 2>&1
	    if [ $? = 0 ]
              then
                echo ""
		echo begin block of deletions: $entry
	        additions='f'
	      else
	      # what about the "N,McX" & other cases in diff?
	         file=`echo $entry`
	         if [ "$additions" = 't' ]
	           then
                     #echo doing file $file
		     dbfileprep $file $Kxxx $loadfile
	           else
                     echo ignoring deleted file $file
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
    echo "\copy gvradartemp from '$loadfile' WITH DELIMITER '|'" \
      | psql -a -d gpmgv | tee -a $logfile 2>&1
  else
    echo "No new file metadata to load to database for this run."
fi
echo ""
echo "Script complete, exiting."
echo ""
exit
