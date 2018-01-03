 \t \a \f '|' \o '/tmp/files1cuf.unl' \\select radar_id, filepath||'/'||filename, fileidnum from gvradar where product='1CUF' and nominal between '2007-01-01 00:00:00' and '2007-01-02 23:59:59.999';

\t \a \f '|' \o '/tmp/files1cuf2007.unl' \\select radar_id, filepath||'/'||filename, fileidnum from gvradar where product='1CUF' and nominal between '2007-01-01 00:00:00+00' and '2007-12-31 23:59:59.999';

-- Do all uncataloged volumes
\t \a \f '|' \o '/tmp/files1cufnew.unl' \\select radar_id, filepath||'/'||filename, fileidnum from gvradar where product='1CUF' and nominal > (select max(nominal) from gvradar_sweeps);
