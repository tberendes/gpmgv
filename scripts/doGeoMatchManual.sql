select file1c21, 
       COALESCE(file2a23, 'no_2A23_file') as file2a23, file2a25, 
       COALESCE(file2b31, 'no_2B31_file') as file2b31,
       c.orbit, count(*), '130817', subset, version 
     from collatedPRproductswsub c left outer join geo_match_product b on 
       (c.radar_id=b.radar_id and c.orbit=b.orbit and c.version=b.pps_version 
        and b.instrument_id = 'PR') 
     where cast(nominal at time zone 'UTC' as date) = '2013-08-17' 
       and file1c21 is not null and pathname is null and version = 7 
       and c.radar_id = 'KMLB' 
     group by file1c21, file2a23, file2a25, file2b31, c.orbit, subset, version 
     order by c.orbit;

select a.event_num, a.orbit, 
            a.radar_id, date_trunc('second', a.overpass_time at time zone 'UTC'), 
            extract(EPOCH from date_trunc('second', a.overpass_time)), 
            b.latitude, b.longitude, 
            trunc(b.elevation/1000.,3), COALESCE(c.file1cuf, 'no_1CUF_file') 
          from overpass_event a, fixed_instrument_location b, 
	    collatedGVproducts c, collatedprproductswsub p 
            left outer join geo_match_product e on 
              (p.radar_id=e.radar_id and p.orbit=e.orbit and 
               p.version=e.pps_version and e.instrument_id = 'PR')
          where a.radar_id = b.instrument_id and a.radar_id = c.radar_id 
	    and a.radar_id = p.radar_id 
	    and a.orbit = c.orbit and a.orbit = p.orbit 
            and a.orbit = 89740 and c.subset = 'sub-GPMGV1' and c.subset=p.subset
            and a.radar_id  = 'KMLB'
            and pathname is null and version = 7 order by 3;
