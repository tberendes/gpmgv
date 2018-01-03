#!/bin/sh

cd /data/mosaicimages/archivedmosaic

for file in `ls *:*.gif`
do
  newname=`echo $file | sed 's/://'`
  mv -v $file $newname
done
exit