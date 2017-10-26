-- find all unprocessed overpasses within 250 km of radar sites
-- use radar_id column as a temporary holder for sat_id 'PR'
select radar_id as sat_id, orbit, radar_id, overpass_time, proximity
   into temp events250 from ct_temp where proximity < 250.001;

-- set sat_id values to 'PR'
update events250 set sat_id = 'PR';

-- outer join to see if any of these are in existing overpass_event table
select o.event_num, e.* into temp addevents
   from overpass_event o RIGHT OUTER JOIN events250 e
   USING (orbit, radar_id);

-- if existing event, event_num will not be null.  Delete these rows.
delete from addevents where event_num IS NOT NULL;

-- add new events to overpass_event table, and then look for matching mosaics
insert into overpass_event(
      sat_id, orbit, radar_id, overpass_time, nearest_distance)
   select sat_id, orbit, radar_id, overpass_time, proximity from addevents
   order by overpass_time;

-- define a time window for each orbit's site coincidences, per orbit.  This
-- could be an instant (only one site overpassed in orbit) or a period
-- (multiple radars overpassed) of time.  Limit ourselves to NEXRAD IDs (Kxxx)
-- now that we are adding international sites outside the NWS mosiac bounds
select orbit, min(overpass_time) as starttime, max(overpass_time) as endtime
   into temp ctwindow from addevents 
  where radar_id like 'K%' group by orbit order by orbit;

-- expand the window by 7'30" before to 3'30" after and find all mosaics
-- within these bounds.  Mosaics are 10 min apart, so should get at least one.
-- Ignore the files more recent than the latest coincident time window.
select distinct orbit, filename
   into temp mosmatchestemp
   from heldmosaic h, ctwindow c
   where 
     h.nominal < (select max(endtime) + interval '00:03:30' from ctwindow)
     and 
     h.nominal between c.starttime - interval '00:07:30' 
                   and c.endtime + interval '00:03:30';

-- build the lists of held mosaic files to: (1) delete and (2) move to archive
select distinct(filename) into temp tosave from mosmatchestemp;

select distinct filename
   into temp todelete
   from heldmosaic h
   where h.nominal < (select max(endtime) from ctwindow)
     and h.filename not in (select filename from tosave); 

\copy todelete (filename) to mosaic2del.lis
\copy tosave (filename) to mosaic2sav.lis

-- store the metadata on coincident mosaics for the orbit, preventing duplicates
insert into coincident_mosaic select * from mosmatchestemp
   where filename not in (select filename from coincident_mosaic);

-- delete the table entries for moved and deleted mosaic files
delete from heldmosaic 
where nominal < (select max(endtime) + interval '00:03:30' from ctwindow);

-- clean out the ct_temp table
delete from ct_temp;

drop table addevents;
drop table ctwindow;
drop table mosmatchestemp;
drop table tosave;
drop table todelete;
