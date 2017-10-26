select a.orbit, a.radar_id, a.overpass_time, b.radar_id, b.overpass_time from overpass_event a, overpass_event b where a.orbit = b.orbit and extract(doy from a.overpass_time) != extract(doy from b.overpass_time);
 orbit | radar_id | overpass_time | radar_id | overpass_time
-------+----------+---------------+----------+---------------
(0 rows)

select max(cast(overpass_time as time)), radar_id from overpass_event group by radar_id;

select orbit, min(overpass_time), max(overpass_time) into temp opassmaxmin from overpass_event group by orbit;

select * from opassmaxmin where  extract(doy from min) !=  extract(doy from max);
 orbit | min | max
-------+-----+-----
(0 rows)

select * from opassmaxmin where  extract(hour from min) >  extract(hour from max);
 orbit | min | max
-------+-----+-----
(0 rows)

select a.event_num, cast(a.value as integer), b.radar_id, c.* from metadata_temp a natural join overpass_event b natural join metadata_parameter c where c.data_type = 'INTEGER';
