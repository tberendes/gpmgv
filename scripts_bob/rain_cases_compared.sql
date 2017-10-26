select radar_id, orbit, a.value as rainy, c.value as overlap from event_meta_numeric a, overpass_event b, event_meta_numeric c where a.event_num = b.event_num and b.event_num=c.event_num and a.metadata_id = 251105 and c.metadata_id = 250199 and a.value > 200 and radar_id = 'RGSN';

-- show which events with default 25/25 criteria are missing from above result

select b.radar_id, b.orbit, a.value as rainy, c.value as overlap, d.pct_overlap, d.pct_overlap_rain_certain from event_meta_numeric a, event_meta_numeric c, overpass_event b left outer join ovlp25_w_rain25 d using (radar_id, orbit) where a.event_num = b.event_num and b.event_num=c.event_num and a.metadata_id = 251105 and c.metadata_id = 250199 and a.value > 200 and radar_id = 'RGSN';

-- or

select b.radar_id, b.orbit, a.value as rainy, c.value as overlap, d.pct_overlap, d.pct_overlap_rain_certain from event_meta_numeric a, event_meta_numeric c, overpass_event b left outer join ovlp25_w_rain25 d using (radar_id, orbit) where a.event_num = b.event_num and b.event_num=c.event_num and a.metadata_id = 251105 and c.metadata_id = 250199 and a.value > 200 and radar_id = 'RGSN' and d.pct_overlap_rain_certain is null;

-- or all sites, just a count of 200in100 cases missed:

select count(*) from event_meta_numeric a, event_meta_numeric c, overpass_event b left outer join ovlp25_w_rain25 d using (radar_id, orbit) where a.event_num = b.event_num and b.event_num=c.event_num and a.metadata_id = 251105 and c.metadata_id = 250199 and a.value > 200 and d.pct_overlap_rain_certain is null;

-- show which events with default 25/25 criteria have <200 rainy points inside 100km

select radar_id, orbit, a.value as rainy, c.value as overlap into temp rain200 from event_meta_numeric a, overpass_event b, event_meta_numeric c where a.event_num = b.event_num and b.event_num=c.event_num and a.metadata_id = 251105 and c.metadata_id = 250199 and a.value > 200 and radar_id = 'RGSN';

select b.radar_id, b.orbit, a.rainy, a.overlap, b.pct_overlap, b.pct_overlap_rain_certain from ovlp25_w_rain25 b left outer join rain200 a using (radar_id,orbit) where b.radar_id = 'RGSN';

-- ditto, but in one query

select radar_id, orbit, pct_overlap, pct_overlap_rain_certain from ovlp25_w_rain25 where not exists (select * from event_meta_numeric a, overpass_event b where a.event_num = b.event_num and a.metadata_id = 251105 and a.value > 200 and radar_id = 'RGSN' and ovlp25_w_rain25.radar_id=b.radar_id  and ovlp25_w_rain25.orbit=b.orbit) and radar_id = 'RGSN';

-- ditto, but for all sites

select radar_id, orbit, pct_overlap, pct_overlap_rain_certain from ovlp25_w_rain25 where not exists (select * from event_meta_numeric a, overpass_event b where a.event_num = b.event_num and a.metadata_id = 251105 and a.value > 200 and ovlp25_w_rain25.radar_id=b.radar_id  and ovlp25_w_rain25.orbit=b.orbit);
