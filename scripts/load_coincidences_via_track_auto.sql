-- load site-specific output files from IDL get_coincidence_via_track.pro, which works
-- over output files from wget_GT7_GPM.sh and extract_daily_predicts.sh

select sat_id, radar_id, overpass_time, nearest_distance into temp tempovrpass from overpass_event where sat_id='GPM' limit 1;
delete from tempovrpass;
\copy tempovrpass from '/tmp/KLTX_Predict.txt' with delimiter '|'


-- load file of CONUS subset orbit start and end times as output from extract_GPM_PPS_CONUS_orbit_startend.sh

select orbit, overpass_time as orbit_start, overpass_time as orbit_end into temp temporbit from overpass_event where sat_id='GPM' limit 1;
delete from temporbit;
\copy temporbit from '/tmp/GPMorbitNumsSepOct2015.unl' with delimiter '|'


-- match up the orbit numbers/startTimes/endTimes with the site overpass times and load new site overpass data

select distinct a.*, b.orbit into temp tempovrpass2 from tempovrpass a, temporbit b where a.overpass_time between b.orbit_start and b.orbit_end group by 1,2,3,4,5 order by 3;

select a.*, b.event_num into temp event2load from tempovrpass2 a left join overpass_event b using (sat_id, radar_id, orbit);

insert into overpass_event(sat_id, radar_id, overpass_time, nearest_distance, orbit) 
select sat_id, radar_id, overpass_time, nearest_distance, orbit from event2load where event_num is null;
