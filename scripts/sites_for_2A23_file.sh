#!/bin/sh

outfile=/data/tmp/file2a23sites_temp.txt
outfileall=/data/tmp/file2a23sites.txt

#file2a23=2A23.061010.50726.6.sub-GPMGV1.hdf.gz

cd /data/prsubsets/2A23
for file2a23 in `ls 2A23.0610*`
  do
    echo "\t \a \f ',' \o $outfile \
     \\\ select filename, b.orbit, count(*) \
      from overpass_event a, orbit_subset_product b\
      where a.orbit=b.orbit and filename='${file2a23}'\
      group by filename, b.orbit;\
    select radar_id from overpass_event\
      where orbit = (select orbit from orbit_subset_product\
      where filename='${file2a23}');" | psql gpmgv

    echo ""
    echo "Output file contents:"
    echo ""
    cat $outfile | tee -a $outfileall
done

exit
