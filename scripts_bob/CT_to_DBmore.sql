-- find all unprocessed overpasses within 250 km of radar sites
-- use radar_id column as a temporary holder for sat_id 'PR'
select radar_id as sat_id, orbit, radar_id, overpass_time, proximity
   into temp events250 from ct_temp where proximity < 250.001;

-- set sat_id values to 'PR'
update events250 set sat_id = 'PR';
--select count(*) from events250;

-- outer join to see if any of these are in existing overpass_event table
select o.event_num, e.* into temp addevents
   from overpass_event o RIGHT OUTER JOIN events250 e
   USING (orbit, radar_id);

-- if existing event, event_num will not be null.  Delete these rows.
delete from addevents where event_num IS NOT NULL;
--select count(*) from addevents;

-- add new events to overpass_event table
insert into overpass_event(
      sat_id, orbit, radar_id, overpass_time, nearest_distance)
   select sat_id, orbit, radar_id, overpass_time, proximity from addevents
   order by overpass_time;

-- clean out the ct_temp table
delete from ct_temp;

drop table addevents;
