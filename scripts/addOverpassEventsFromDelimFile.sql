-- Use TSDIS Overflight Finder to get overpasses for site lat/lon.
-- Save web page as HTML file, edit in OpenOffice or Word, delete everything but the table, delete header row of table, and convert table to delimited text.  Edit the text file to get rid of unneeded text in fields, and to replace direction field with radar_name, Asc/Desc with radar_id.
-- Use sed 's/|/+00|/5' on text file to add time zone to datetime field.
-- Use vi to get rid of hidden control characters, if any, and remove the last line's CR/LF if it's there.
-- Then run the following SQL in psql, editing filenames etc. as needed.


select orbit,proximity,radar_name,radar_id,overpass_time,radar_name as discard into temp ct_darw from ct_temp limit 1;

\d ct_darw

select * from ct_darw;

\copy ct_darw from '/home/morris/Desktop/DARWoverpasses.unl' with delimiter '|'

select * from ct_darw limit 10;

select count(*) from ct_darw;

select count(*) from ct_temp;

insert into ct_temp select orbit, radar_name, radar_id, overpass_time, proximity from ct_darw;

select radar_id as sat_id, orbit, radar_id, overpass_time, proximity into temp events250 from ct_temp where proximity < 250.001;

update events250 set sat_id = 'PR';

select o.event_num, e.* into temp addevents  from overpass_event o RIGHT OUTER JOIN events250 e USING (orbit, radar_id);

delete from addevents where event_num IS NOT NULL; 

insert into overpass_event(sat_id, orbit, radar_id, overpass_time, nearest_distance) select sat_id, orbit, radar_id, overpass_time, proximity from addevents order by overpass_time;

delete from ct_temp;
drop table addevents;
drop table ct_darw;

select count(*) from overpass_event where radar_id = 'DARW';
