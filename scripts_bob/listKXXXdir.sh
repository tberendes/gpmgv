#!/bin/sh
DATADIR=/data/gv_radar/defaultQC_in

# holds list of files in tree at time of this run
tmpfile=/data/tmp/lsKAMX.new

# holds list of files in tree at time of prior run
tmpfileold=/data/tmp/lsKAMX.old

# holds output of diff between tmpfile and tmpfileold 
tmpfilediff=/data/tmp/lsKAMX.diff

if [ -f $tmpfile ]
  then
    #mv -fv $tmpfile $tmpfileold
    rm $tmpfile
fi

cd $DATADIR/KAMX

# list the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

for file in `ls -R *`
do
  strip=`echo $file | sed 's/://'`
  if [ -d $strip ]
    then
      subdir=$strip
    else
      if [ -f ${subdir}/${strip} ]
        then
          echo ${subdir}/${strip} >> $tmpfile
      fi
  fi
done

# difference the old and new file listings to see what's been added to or
# removed from the local directory tree since last time

diff $tmpfileold $tmpfile > $tmpfilediff

exit
