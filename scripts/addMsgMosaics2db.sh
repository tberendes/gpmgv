#!/bin/sh

# Add file catalog metadata to the heldmosaic table for files currently 
# present in the holding directory.  Used in the case where postgres was down
# and the files got ingested by not cataloged.  Needed to add a unique
# constraint to the heldmosaic table for this to work without duplicating data
# in the database.

cd /data/mosaicimages/holding

for file in `ls *.gif`
do
 datetime=`echo $file | cut -f1 -d '.' | sed 's/_/ /g'`
 echo "insert into heldmosaic values('$datetime', '$file');" |  psql -a -d gpmgv
done

exit