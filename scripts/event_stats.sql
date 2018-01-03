select count(*), date_trunc('month',overpass_time) into temp fulldatabymonth from collatedZproducts where file2a55 is not null group by 2;
select avg(count) from fulldatabymonth where date_trunc not in ('2006-07-01 00:00:00-04', '2007-02-01 00:00:00-05');


select a.radar_id, a.orbit, a.overpass_time, a.pct_overlap, a.pct_overlap_conv, a.pct_overlap_strat, b.pct_overlap_Rain_certain into temp ovlp25_w_rain25 from event_meta_2A23_vw a, event_meta_2A25_vw b where a.event_num = b.event_num and a.pct_overlap >= 25 and b.pct_overlap_Rain_certain >= 25 order by 7 desc;   

select count(*), date_trunc('month',overpass_time) from ovlp25_w_rain25 group by 2;
select count(*), date_trunc('month',overpass_time) into temp rainbymonth from ovlp25_w_rain25 group by 2;

select a.radar_id, a.orbit, a.overpass_time, b.file1c21, b.file2a25, COALESCE(b.file2a55, 'no_2A55_file') into temp prod25_w_rain25 from ovlp25_w_rain25 a, collatedZproducts b where a.radar_id=b.radar_id and a.orbit=b.orbit;  

select count(*), date_trunc('month',overpass_time) into temp prodbymonth from prod25_w_rain25 where coalesce!='no_2A55_file' group by 2;  

select avg(count) from prodbymonth where date_trunc not in ('2006-07-01 00:00:00-04', '2007-02-01 00:00:00-05');
