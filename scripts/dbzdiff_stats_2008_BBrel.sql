-- get a common set of samples between original and S2Ku
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_s2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 V6_BBrel_s2ku |     -3 | 39.92 | 43.02 |  2659 | 30.21 | 31.43 | 12015 | 31.97 | 33.53 | 14674
 V6_BBrel_s2ku |   -1.5 | 40.54 | 42.64 | 11176 | 30.41 | 31.51 | 42020 | 32.54 | 33.85 | 53196
 V6_BBrel_s2ku |    1.5 | 32.25 | 31.72 |  9650 | 24.53 |  25.2 | 32694 | 26.29 | 26.69 | 42344
 V6_BBrel_s2ku |      3 | 29.74 | 29.54 | 10365 | 23.51 | 24.17 | 23709 | 25.41 |  25.8 | 34074
 V6_BBrel_s2ku |    4.5 |  28.7 | 28.77 |  4956 | 22.53 |  23.4 |  5832 | 25.36 | 25.87 | 10788
 V6_BBrel_s2ku |      6 | 29.64 | 29.74 |  1686 | 21.96 | 22.85 |   494 |  27.9 | 28.18 |  2180
 V6_BBrel_s2ku |    7.5 |  31.3 | 32.72 |   389 | 21.98 | 24.46 |     5 | 31.18 | 32.61 |   394
(7 rows)


drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Orig |     -3 | 39.92 | 41.24 |  2659 | 30.21 | 30.55 | 12015 | 31.97 | 32.49 | 14674
 V6_BBrel_Orig |   -1.5 | 40.54 | 40.89 | 11176 | 30.41 | 30.62 | 42020 | 32.54 | 32.78 | 53196
 V6_BBrel_Orig |    1.5 | 32.25 | 33.28 |  9650 | 24.53 | 25.95 | 32694 | 26.29 | 27.62 | 42344
 V6_BBrel_Orig |      3 | 29.74 | 30.83 | 10365 | 23.51 | 24.82 | 23709 | 25.41 | 26.65 | 34074
 V6_BBrel_Orig |    4.5 |  28.7 | 29.96 |  4956 | 22.53 | 23.99 |  5832 | 25.36 | 26.73 | 10788
 V6_BBrel_Orig |      6 | 29.64 | 31.05 |  1686 | 21.96 |  23.4 |   494 |  27.9 | 29.32 |  2180
 V6_BBrel_Orig |    7.5 |  31.3 | 34.39 |   389 | 21.98 | 25.15 |     5 | 31.18 | 34.27 |   394
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b  where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_BBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

    ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
-----------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V6_BBrel_BBs2ku |     -3 | 39.92 | 43.02 |  2659 | 30.21 | 31.43 |  12015 | 31.97 | 33.53 |  14674
 V6_BBrel_BBs2ku |   -1.5 | 40.36 | 41.78 | 20545 |  30.5 | 31.11 |  77185 | 32.58 | 33.36 |  97730
 V6_BBrel_BBs2ku |      0 | 38.65 | 40.07 | 27628 | 30.74 | 32.97 | 121634 | 32.21 | 34.28 | 149262
 V6_BBrel_BBs2ku |    1.5 | 33.36 | 33.64 | 17052 | 25.63 | 26.98 |  62165 | 27.29 | 28.42 |  79217
 V6_BBrel_BBs2ku |      3 | 29.74 | 29.54 | 10365 | 23.51 | 24.17 |  23709 | 25.41 |  25.8 |  34074
 V6_BBrel_BBs2ku |    4.5 |  28.7 | 28.77 |  4956 | 22.53 |  23.4 |   5832 | 25.36 | 25.87 |  10788
 V6_BBrel_BBs2ku |      6 | 29.64 | 29.74 |  1686 | 21.96 | 22.85 |    494 |  27.9 | 28.18 |   2180
 V6_BBrel_BBs2ku |    7.5 |  31.3 | 32.72 |   389 | 21.98 | 24.46 |      5 | 31.18 | 32.61 |    394
(8 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_BB_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

     ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V6_BBrel_BB_Orig |     -3 | 39.92 | 41.24 |  2659 | 30.21 | 30.55 |  12015 | 31.97 | 32.49 |  14674
 V6_BBrel_BB_Orig |   -1.5 | 40.36 | 40.83 | 20545 |  30.5 | 30.63 |  77185 | 32.58 | 32.78 |  97730
 V6_BBrel_BB_Orig |      0 | 38.65 | 40.07 | 27628 | 30.74 | 32.97 | 121634 | 32.21 | 34.28 | 149262
 V6_BBrel_BB_Orig |    1.5 | 33.36 | 34.52 | 17052 | 25.63 | 27.38 |  62165 | 27.29 | 28.92 |  79217
 V6_BBrel_BB_Orig |      3 | 29.74 | 30.83 | 10365 | 23.51 | 24.82 |  23709 | 25.41 | 26.65 |  34074
 V6_BBrel_BB_Orig |    4.5 |  28.7 | 29.96 |  4956 | 22.53 | 23.99 |   5832 | 25.36 | 26.73 |  10788
 V6_BBrel_BB_Orig |      6 | 29.64 | 31.05 |  1686 | 21.96 |  23.4 |    494 |  27.9 | 29.32 |   2180
 V6_BBrel_BB_Orig |    7.5 |  31.3 | 34.39 |   389 | 21.98 | 25.15 |      5 | 31.18 | 34.27 |    394
(8 rows)
