select a.event_num, sum(a.value),b.value from event_meta_numeric a, event_meta_numeric b where a.metadata_id between 230001 and 230009 and b.metadata_id = 250999 and a.event_num=b.event_num group by 1,3 limit 10;

--nogood! select a.event_num, b.value/sum(a.value) from event_meta_numeric a, event_meta_numeric b where a.metadata_id = 230001 and b.metadata_id between 230001 and 230009 group by 1 limit 10;

create view event_meta_2A23_vw as
 (select a.event_num, a.radar_id, a.orbit, a.overpass_time, a.nearest_distance, b.value/56.25 as pct_overlap, (c.value/b.value)*100 as pct_overlap_strat, (d.value/b.value)*100 as pct_overlap_conv
  from overpass_event a 
  LEFT JOIN event_meta_numeric b on a.event_num = b.event_num and b.metadata_id = 250999
  LEFT JOIN event_meta_numeric c on a.event_num = c.event_num and c.metadata_id = 230001
  LEFT JOIN event_meta_numeric d on c.event_num = d.event_num and d.metadata_id = 230002);

create view event_meta_2A25_vw as 
 (select a.event_num, a.radar_id, a.orbit, a.overpass_time, a.nearest_distance, b.value/56.25 as pct_overlap, (c.value/b.value)*100 as pct_overlap_BB_exists, (d.value/b.value)*100 as pct_overlap_Rain_certain, e.value as avg_bb_height
 from overpass_event a
 LEFT JOIN event_meta_numeric b on a.event_num = b.event_num and b.metadata_id = 250999
 LEFT JOIN event_meta_numeric c on a.event_num = c.event_num and c.metadata_id = 251004
 LEFT JOIN event_meta_numeric d on a.event_num = d.event_num and d.metadata_id = 251005
 LEFT JOIN event_meta_numeric e on a.event_num = e.event_num and e.metadata_id = 251003);
