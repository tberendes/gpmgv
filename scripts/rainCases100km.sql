-- to clear out the table when a specific set of cases will need to be run,
-- run this query first.  Make sure the current contents of the rainy100inside100
-- table are not needed (ie, we want to overwrite, not append).
delete from rainy100inside100;

-- the default query, to do grids for all cases:
insert into rainy100inside100 select a.radar_id, a.orbit, a.overpass_time, b.value/19.61 as pct_overlap, (c.value/b.value)*100 as pct_overlap_conv, (d.value/b.value)*100 as pct_overlap_strat, e.value as num_overlap_Rain_certain 
from overpass_event a
    JOIN event_meta_numeric b ON a.event_num = b.event_num AND b.metadata_id = 250199
    JOIN event_meta_numeric c ON a.event_num = c.event_num AND c.metadata_id = 230102
    JOIN event_meta_numeric d ON a.event_num = d.event_num AND d.metadata_id = 230101
    JOIN event_meta_numeric e ON a.event_num = e.event_num AND e.metadata_id = 251105 and e.value >= 100 order by 7 desc;

-- what is the latest event case currently defined in the table?
select * from rainy100inside100 order by overpass_time desc limit 1;

-- specific cases after a given date/time (specify a new value for the
-- clause "and a.overpass_time > '2007-03-31 16:22:50.476-04'"):

-- SEE THE NEW SQL IN rainCases100kmAddNewEvents.sql !!  Make sure to run the 
-- missingMeta script before updating the rain events table.

insert into rainy100inside100 select a.radar_id, a.orbit, a.overpass_time, b.value/19.61 as pct_overlap, (c.value/b.value)*100 as pct_overlap_conv, (d.value/b.value)*100 as pct_overlap_strat, e.value as num_overlap_Rain_certain 
from overpass_event a
    JOIN event_meta_numeric b ON a.event_num = b.event_num AND b.metadata_id = 250199
    JOIN event_meta_numeric c ON a.event_num = c.event_num AND c.metadata_id = 230102
    JOIN event_meta_numeric d ON a.event_num = d.event_num AND d.metadata_id = 230101
    JOIN event_meta_numeric e ON a.event_num = e.event_num AND e.metadata_id = 251105 and e.value >= 100 and a.overpass_time >
    (select max(overpass_time) from rainy100inside100 where radar_id='RGSN') and a.radar_id in('RGSN') order by 3;

-- find overpasses meeting default criteria for DARW site, for dates where we have obtained PR subset files:

\pset format html

\o DARWovlp25wrain25_older.html \\select date_trunc('second', a.overpass_time) at time zone 'UTC' as overpass_time_UTC, round(a.pct_overlap*100)/100 as pct_overlap, round(a.pct_overlap_conv*100)/100 as pct_conv, round(a.pct_overlap_strat*100)/100 as pct_strat, round(b.pct_overlap_rain_certain*100)/100 as pct_rain_certain from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap>= 25 and b.pct_overlap_Rain_certain >= 25 and a.radar_id='DARW' and a.overpass_time < '2007-02-24 14:23:10+00' order by 1;

-- find 100in100 overpasses having matching 2A55/2A54 radar data (from TRMM GV)

select count(*) from collatedproductsWsub a, rainy100inside100 b where a.radar_id=b.radar_id and a.orbit=b.orbit and a.file2a55 is not null and a.file2a54 is not null and a.radar_id not in ('RMOR','DARW', 'RGSN','KWAJ');
