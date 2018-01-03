select overpass_time, gvtype, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_w_sfc a, overpass_event b where regime='S_above' and numpts>5 and a.radar_id='KJAX' and a.radar_id = b.radar_id and a.orbit=b.orbit group by 1,2 order by 2,1;
-- for all 3 ranges (2 eq >100km)
select overpass_time, gvtype, rangecat, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist a, overpass_event b where regime='S_above' and numpts>5 and a.radar_id='KJAX' and a.radar_id = b.radar_id and a.orbit=b.orbit group by 1,2,3 order by 2,1,3;

-- within 100km
select overpass_time, gvtype, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist a, overpass_event b where regime='S_above' and numpts>5 and a.radar_id='KJAX' and a.radar_id = b.radar_id and a.orbit=b.orbit and a.rangecat in (0,1) and gvtype ='2A55' group by 1,2 order by 2,1;