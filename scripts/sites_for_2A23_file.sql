select count(*), a.orbit, filename
  from overpass_event a, orbit_subset_product b
 where a.orbit=b.orbit and b.product_type='2A23'
group by filename, a.orbit;

-- given a PR subset data file name, get the number
-- of radar sites overpassed in its orbit #, and a
-- list of these sites.  The first line lists the
-- filename, corresponding orbit #, and the number
-- of sites overpassed in the orbit, each field
-- separated by a comma.  The remaining lines list
-- the coincident radar sites, one site per line.

echo "\t \a \f ',' \o queryout.txt \\\ select filename, b.orbit, count(*) from overpass_event a, orbit_subset_product b where a.orbit=b.orbit and filename='2A23.061010.50726.6.sub-GPMGV1.hdf.gz' group by filename, b.orbit; select radar_id from overpass_event where orbit = (select orbit from orbit_subset_product where filename='2A23.061010.50726.6.sub-GPMGV1.hdf.gz');" | psql gpmgv

file2a23=2A23.061010.50726.6.sub-GPMGV1.hdf.gz
echo "\t \a \f ',' \o queryout.txt \\\ select filename, b.orbit, count(*) from overpass_event a, orbit_subset_product b where a.orbit=b.orbit and filename='${file2a23}' group by filename, b.orbit; select radar_id from overpass_event where orbit = (select orbit from orbit_subset_product where filename='${file2a23}');" | psql gpmgv

echo "\t \a \f '|' \o queryout.txt \\\ select filename, product_type, b.orbit, count(*) from overpass_event a, orbit_subset_product b where a.orbit=b.orbit and filename='${file2a23}' group by filename, product_type, b.orbit; select a.radar_id, a.event_num,  b.latitude, b.longitude from overpass_event a, fixed_instrument_location b where a.radar_id = b.instrument_id and a.orbit = (select orbit from orbit_subset_product where filename='${file2a23}');" | psql gpmgv

