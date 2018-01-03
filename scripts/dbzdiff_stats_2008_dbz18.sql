-- get a common set of samples between original and S2Ku
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR a, dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_dbz18_s2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_dbz18_s2ku |    1.5 | 41.09 | 43.29 | 9138 |  31.4 | 32.62 | 31741 | 33.56 | 35.01 | 40879
 V6_dbz18_s2ku |      3 | 38.48 | 40.42 | 3408 | 29.29 | 30.36 | 15785 | 30.92 | 32.15 | 19193
 V6_dbz18_s2ku |    4.5 | 32.43 | 32.07 | 6456 | 24.89 |  25.8 | 18485 | 26.84 | 27.43 | 24941
 V6_dbz18_s2ku |      6 | 31.03 | 31.05 | 7722 | 23.91 | 25.01 | 15833 | 26.25 | 26.99 | 23555
 V6_dbz18_s2ku |    7.5 | 30.34 | 30.69 | 3556 | 22.94 | 24.11 |  4360 | 26.26 | 27.06 |  7916
 V6_dbz18_s2ku |      9 |  31.1 | 31.67 | 1200 | 22.41 | 24.01 |   287 | 29.42 | 30.19 |  1487
 V6_dbz18_s2ku |   10.5 |  32.4 | 33.65 |  335 |  23.7 | 25.71 |    13 | 32.07 | 33.35 |   348
(7 rows)


drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_dbz18_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_dbz18_Orig |    1.5 | 41.09 | 41.49 | 9138 |  31.4 | 31.66 | 31741 | 33.56 | 33.85 | 40879
 V6_dbz18_Orig |      3 | 38.48 | 39.36 | 3408 | 29.29 | 29.98 | 15785 | 30.92 | 31.64 | 19193
 V6_dbz18_Orig |    4.5 | 32.43 | 33.68 | 6456 | 24.89 |  26.6 | 18485 | 26.84 | 28.43 | 24941
 V6_dbz18_Orig |      6 | 31.03 | 32.52 | 7722 | 23.91 | 25.73 | 15833 | 26.25 | 27.96 | 23555
 V6_dbz18_Orig |    7.5 | 30.34 | 32.11 | 3556 | 22.94 | 24.75 |  4360 | 26.26 | 28.06 |  7916
 V6_dbz18_Orig |      9 |  31.1 |  33.2 | 1200 | 22.41 | 24.65 |   287 | 29.42 | 31.55 |  1487
 V6_dbz18_Orig |   10.5 |  32.4 | 35.44 |  335 |  23.7 | 26.52 |    13 | 32.07 | 35.11 |   348
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR a, dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR b  where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6_18dBZGR c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_dbz18_BBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

    ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
-----------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V6_dbz18_BBs2ku |    1.5 | 41.01 | 42.53 | 16301 |  31.7 | 32.97 |  68196 | 33.49 | 34.81 |  84497
 V6_dbz18_BBs2ku |      3 | 39.01 |  40.4 | 26231 | 30.62 | 32.39 | 103809 | 32.31 | 34.01 | 130040
 V6_dbz18_BBs2ku |    4.5 | 34.78 | 35.65 | 15487 | 27.66 | 29.85 |  52523 | 29.28 | 31.17 |  68010
 V6_dbz18_BBs2ku |      6 | 31.18 | 31.24 |  8140 | 24.24 | 25.36 |  17733 | 26.43 | 27.21 |  25873
 V6_dbz18_BBs2ku |    7.5 | 30.34 | 30.69 |  3556 | 22.94 | 24.11 |   4360 | 26.26 | 27.06 |   7916
 V6_dbz18_BBs2ku |      9 |  31.1 | 31.67 |  1200 | 22.41 | 24.01 |    287 | 29.42 | 30.19 |   1487
 V6_dbz18_BBs2ku |   10.5 |  32.4 | 33.65 |   335 |  23.7 | 25.71 |     13 | 32.07 | 33.35 |    348
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6_18dBZGR c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_dbz18_BB_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

     ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V6_dbz18_BB_Orig |    1.5 | 41.01 | 41.52 | 16301 |  31.7 | 32.52 |  68196 | 33.49 | 34.26 |  84497
 V6_dbz18_BB_Orig |      3 | 39.01 | 40.27 | 26231 | 30.62 | 32.33 | 103809 | 32.31 | 33.93 | 130040
 V6_dbz18_BB_Orig |    4.5 | 34.78 | 36.32 | 15487 | 27.66 | 30.13 |  52523 | 29.28 | 31.54 |  68010
 V6_dbz18_BB_Orig |      6 | 31.18 | 32.63 |  8140 | 24.24 | 26.01 |  17733 | 26.43 | 28.09 |  25873
 V6_dbz18_BB_Orig |    7.5 | 30.34 | 32.11 |  3556 | 22.94 | 24.75 |   4360 | 26.26 | 28.06 |   7916
 V6_dbz18_BB_Orig |      9 |  31.1 |  33.2 |  1200 | 22.41 | 24.65 |    287 | 29.42 | 31.55 |   1487
 V6_dbz18_BB_Orig |   10.5 |  32.4 | 35.44 |   335 |  23.7 | 26.52 |     13 | 32.07 | 35.11 |    348
(7 rows)
