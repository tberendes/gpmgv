#!/bin/sh
DATADIR=/data/gv_radar/defaultQC_in

# holds list of files in tree at time of this run
tmpfile=/data/tmp/lsKAMX.new

# holds list of files in tree at time of prior run
tmpfileold=/data/tmp/lsKAMX.old

# holds output of diff between tmpfile and tmpfileold 
tmpfilediff=/data/tmp/lsKAMX.diff

function dbstore() {
type=`echo $1 | cut -f1 -d'/'`
echo "type = $type"
datestr=`echo $1 | cut -f2-3 -d'/' | awk '{print substr($1,1,4)"-"substr($1,6,2)"-"substr($1,8,2)}'`
echo "datestr = $datestr"
return
}

if [ -f $tmpfile ]
  then
    #mv -fv $tmpfile $tmpfileold
    rm $tmpfile
fi

if [ ! -f $tmpfileold ]
  then
    touch $tmpfileold
fi

cd $DATADIR/KAMX

# list the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

for file in `ls -R *`
do
  # a directory under which files or immediate subdirectories are about
  # to be listed has a ':' at the end of the name, replace w. '/' and save
  # for prepending to any regular files listed under it
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
    echo $entry | grep "^[1-9][0-9]*a[1-9][0-9]*" > /dev/null 2>&1
    if [ $? = 0 ]
      then
        echo begin block of additions: $entry
	additions='t'
      else
        echo $entry | grep "^[1-9][0-9]*,[1-9][0-9]*d[1-9][0-9]*"\
	   > /dev/null 2>&1
	if [ $? = 0 ]
          then
            echo begin block of deletions: $entry
	    additions='f'
	  else
	  # what about the "N,McX" & other cases in diff?
	     file=`echo $entry`
	     if [ "$additions" = 't' ]
	       then
                 echo doing file $file
		 dbstore $file
	       else
                 echo ignoring deleted file $file
	     fi
	fi
    fi
done

exit
