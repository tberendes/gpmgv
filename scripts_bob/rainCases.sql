-- to clear out the table when a specific set of cases will need to be run,
-- run this query first.  Make sure the current contents of the ovlp25_w_rain25
-- table are not needed (ie, we want to overwrite, not append).
delete from ovlp25_w_rain25;

-- the default query, to do grids for all cases:
insert into ovlp25_w_rain25 select a.radar_id, a.orbit, a.overpass_time, a.pct_overlap, a.pct_overlap_conv, a.pct_overlap_strat, b.pct_overlap_Rain_certain from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap >= 25 and b.pct_overlap_Rain_certain >= 25 order by 7 desc;

-- what is the latest event case currently defined in the table?
select * from ovlp25_w_rain25 order by overpass_time desc limit 1;

-- specific cases after a given date/time (specify a new value for the
-- clause "and a.overpass_time > '2007-03-31 16:22:50.476-04'"):
insert into ovlp25_w_rain25 select a.radar_id, a.orbit, a.overpass_time, a.pct_overlap, a.pct_overlap_conv, a.pct_overlap_strat, b.pct_overlap_Rain_certain from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap >= 25 and b.pct_overlap_Rain_certain >= 25 and a.overpass_time > '2008-05-03 05:47:49.533-04' and a.radar_id not in('DARW') order by 7 desc;

-- for when REO grids got wiped out for KA* and KB* sites:
insert into ovlp25_w_rain25 select a.radar_id, a.orbit, a.overpass_time, a.pct_overlap, a.pct_overlap_conv, a.pct_overlap_strat, b.pct_overlap_Rain_certain from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap >= 25 and b.pct_overlap_Rain_certain >= 25 and a.radar_id < 'KCAA' order by 7 desc;

-- find overpasses meeting default criteria for DARW site, for dates where we have obtained PR subset files:

\pset format html

\o DARWovlp25wrain25_older.html \\select date_trunc('second', a.overpass_time) at time zone 'UTC' as overpass_time_UTC, round(a.pct_overlap*100)/100 as pct_overlap, round(a.pct_overlap_conv*100)/100 as pct_conv, round(a.pct_overlap_strat*100)/100 as pct_strat, round(b.pct_overlap_rain_certain*100)/100 as pct_rain_certain from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap>= 25 and b.pct_overlap_Rain_certain >= 25 and a.radar_id='DARW' and a.overpass_time < '2007-02-24 14:23:10+00' order by 1;

-- find 25/25 overpasses having matching 2A55/2A54 radar data (from TRMM GV)

select count(*) from collatedproducts a, ovlp25_w_rain25 b where a.radar_id=b.radar_id and a.orbit=b.orbit and a.file2a55 is not null and a.file2a54 is not null and a.radar_id not in ('RMOR','DARW');
