select sat_id, radar_id, overpass_time, nearest_distance into tempovrpass from overpass_event where sat_id='GPM' limit 1;

delete from tempovrpass;

\copy tempovrpass from '/tmp/AU-72_Predict.txt' with delimiter '|'

select distinct a.*, b.orbit into temp tempovrpass2 from tempovrpass a, gpm_orbits b where a.overpass_time between b.starttime and b.endtime group by 1,2,3,4,5;

select a.*, b.event_num into temp event2load from tempovrpass2 a left join overpass_event b using (sat_id, radar_id, orbit);

insert into overpass_event(sat_id, radar_id, overpass_time, nearest_distance, orbit) select sat_id, radar_id, overpass_time, nearest_distance, orbit from event2load where event_num is null;

drop table tempovrpass;
drop table tempovrpass2;
drop table event2load;

