#!/bin/sh

# Uses a listing of all files in 'gvradar' table and finds those
# filenames not present on disk. Queries view 'gvradar_fullpath' to
# create the file listing.

# Run SQL call to make current in-DB listing of files:
echo "\pset format u \t \o '/data/tmp/AllFinalQC.lis' \\\ select * \
  from gvradar_fullpath order by 2,1,3;"  | psql -a -d gpmgv

count=`wc -l /data/tmp/AllFinalQC.lis | cut -f1 -d' '`
echo ""
echo "Checking $count files..."
echo ""

# take the whitespace out of the input file before parsing
for file in `cat /data/tmp/AllFinalQC.lis | sed 's/ //g'`
  do
    filepath=`echo $file | cut -f4 -d'|'`
#    echo $filepath
    if [ ! -f $filepath ]
      then
        echo "$filepath NOT FOUND"
    fi
done

rm -fv /data/tmp/AllFinalQC.lis

exit