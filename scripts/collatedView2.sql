CREATE  VIEW collatecols (orbit, radar_id, nominal) as
select orbit, radar_id, date_trunc('hour', overpass_time)
  from overpass_event;
