-- get a common set of samples between original and S2Ku
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V7BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V7BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V7_BBrel_s2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 V7_BBrel_s2ku |     -3 | 40.84 | 43.52 |  2614 | 30.37 | 31.51 |  9581 | 32.61 | 34.09 | 12195
 V7_BBrel_s2ku |   -1.5 |  40.9 | 43.12 | 10487 | 30.43 | 31.52 | 37737 | 32.71 | 34.04 | 48224
 V7_BBrel_s2ku |    1.5 | 31.64 | 31.36 |  9795 | 24.45 | 25.19 | 32785 |  26.1 | 26.61 | 42580
 V7_BBrel_s2ku |      3 | 29.27 | 29.26 | 10270 | 23.45 | 24.13 | 23672 | 25.21 | 25.68 | 33942
 V7_BBrel_s2ku |    4.5 | 28.52 | 28.77 |  4474 |  22.5 | 23.32 |  5514 |  25.2 | 25.76 |  9988
 V7_BBrel_s2ku |      6 | 29.75 |  30.1 |  1469 |    22 | 22.88 |   436 | 27.98 | 28.45 |  1905
(6 rows)


drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V7BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V7BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V7BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V7_BBrel_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 V7_BBrel_Orig |     -3 | 40.84 |  41.7 |  2614 | 30.37 | 30.63 |  9581 | 32.61 |    33 | 12195
 V7_BBrel_Orig |   -1.5 |  40.9 | 41.33 | 10487 | 30.43 | 30.63 | 37737 | 32.71 | 32.96 | 48224
 V7_BBrel_Orig |    1.5 | 31.64 | 32.86 |  9795 | 24.45 | 25.94 | 32785 |  26.1 | 27.53 | 42580
 V7_BBrel_Orig |      3 | 29.27 | 30.52 | 10270 | 23.45 | 24.77 | 23672 | 25.21 | 26.51 | 33942
 V7_BBrel_Orig |    4.5 | 28.52 | 29.97 |  4474 |  22.5 | 23.89 |  5514 |  25.2 | 26.62 |  9988
 V7_BBrel_Orig |      6 | 29.75 | 31.47 |  1469 |    22 | 23.43 |   436 | 27.98 | 29.63 |  1905
(6 rows)


-- get a common set of samples between V7 and v7
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V7BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V7BBrel b  where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V7BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V7_BBrel_BBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

    ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
-----------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V7_BBrel_BBs2ku |     -3 | 40.84 | 43.52 |  2614 | 30.37 | 31.51 |   9581 | 32.61 | 34.09 |  12195
 V7_BBrel_BBs2ku |   -1.5 |  40.6 | 42.12 | 19407 | 30.54 | 31.13 |  71096 |  32.7 | 33.49 |  90503
 V7_BBrel_BBs2ku |      0 | 38.53 | 40.13 | 27160 | 30.71 | 32.96 | 117948 | 32.18 |  34.3 | 145108
 V7_BBrel_BBs2ku |    1.5 | 32.82 |  33.3 | 17223 | 25.53 | 26.96 |  62187 | 27.11 | 28.34 |  79410
 V7_BBrel_BBs2ku |      3 | 29.27 | 29.26 | 10270 | 23.45 | 24.13 |  23672 | 25.21 | 25.68 |  33942
 V7_BBrel_BBs2ku |    4.5 | 28.52 | 28.77 |  4474 |  22.5 | 23.32 |   5514 |  25.2 | 25.76 |   9988
 V7_BBrel_BBs2ku |      6 | 29.75 |  30.1 |  1469 |    22 | 22.88 |    436 | 27.98 | 28.45 |   1905
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V7BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V7BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V7BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V7_BBrel_BB_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

     ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V7_BBrel_BB_Orig |     -3 | 40.84 |  41.7 |  2614 | 30.37 | 30.63 |   9581 | 32.61 |    33 |  12195
 V7_BBrel_BB_Orig |   -1.5 |  40.6 | 41.15 | 19407 | 30.54 | 30.66 |  71096 |  32.7 | 32.91 |  90503
 V7_BBrel_BB_Orig |      0 | 38.53 | 40.13 | 27160 | 30.71 | 32.96 | 117948 | 32.18 |  34.3 | 145108
 V7_BBrel_BB_Orig |    1.5 | 32.82 | 34.16 | 17223 | 25.53 | 27.36 |  62187 | 27.11 | 28.83 |  79410
 V7_BBrel_BB_Orig |      3 | 29.27 | 30.52 | 10270 | 23.45 | 24.77 |  23672 | 25.21 | 26.51 |  33942
 V7_BBrel_BB_Orig |    4.5 | 28.52 | 29.97 |  4474 |  22.5 | 23.89 |   5514 |  25.2 | 26.62 |   9988
 V7_BBrel_BB_Orig |      6 | 29.75 | 31.47 |  1469 |    22 | 23.43 |    436 | 27.98 | 29.63 |   1905
(7 rows)
