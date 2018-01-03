#!/bin/sh

# This logic needs to be plugged into getPRdata.sh in the loop over the database
# inserts of the filenames, etc., (or in another 2A23 filename loop after the
# inserts are finished) to create the file needed for the call to IDL
# to process the files and generate the 2A23 metadata.

outfile=/data/tmp/file2a23sites_temp.txt
outfileall=/data/tmp/file2a23sites.txt
rm -v $outfileall
#file2a23=2A23.061010.50726.6.sub-GPMGV1.hdf.gz

cd /data/prsubsets/2A23
for file2a23 in `ls 2A23.0610*`
  do
    echo "\t \a \f '|' \o $outfile \
     \\\ select filename, b.orbit, count(*) \
      from overpass_event a, orbit_subset_product b\
      where a.orbit=b.orbit and filename='${file2a23}'\
      group by filename, b.orbit;\
    select a.radar_id, b.latitude, b.longitude\
      from overpass_event a, fixed_instrument_location b\
      where a.radar_id = b.instrument_id and\
      a.orbit = (select orbit from orbit_subset_product\
      where filename='${file2a23}');" | psql gpmgv

    echo ""
    echo "Output file contents:"
    echo ""
    cat $outfile | tee -a $outfileall
done

exit
