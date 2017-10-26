-- get a common set of samples between original and S2Ku, leaving out in-BB layers
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_s2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_s2ku |     -3 | 40.32 |  43.5 | 2229 | 31.05 | 32.42 |  9533 | 32.81 | 34.52 | 11762
 V6_BBrel_s2ku |   -1.5 | 40.98 | 43.14 | 9616 | 31.34 | 32.54 | 33215 |  33.5 | 34.92 | 42831
 V6_BBrel_s2ku |    1.5 | 32.94 | 32.52 | 7563 | 25.01 | 25.91 | 23732 | 26.92 | 27.51 | 31295
 V6_BBrel_s2ku |      3 | 30.62 |  30.6 | 7793 |  23.9 | 24.89 | 16414 | 26.07 | 26.73 | 24207
 V6_BBrel_s2ku |    4.5 | 29.92 | 30.34 | 3342 | 22.84 | 24.16 |  3539 | 26.28 | 27.16 |  6881
 V6_BBrel_s2ku |      6 |  31.4 | 31.99 | 1056 | 22.48 |    24 |   192 | 30.03 | 30.76 |  1248
(6 rows)


drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Orig |     -3 | 40.32 | 41.68 | 2229 | 31.05 | 31.47 |  9533 | 32.81 |  33.4 | 11762
 V6_BBrel_Orig |   -1.5 | 40.98 | 41.35 | 9616 | 31.34 | 31.58 | 33215 |  33.5 | 33.78 | 42831
 V6_BBrel_Orig |    1.5 | 32.94 | 34.18 | 7563 | 25.01 | 26.73 | 23732 | 26.92 | 28.53 | 31295
 V6_BBrel_Orig |      3 | 30.62 | 32.01 | 7793 |  23.9 |  25.6 | 16414 | 26.07 | 27.67 | 24207
 V6_BBrel_Orig |    4.5 | 29.92 | 31.72 | 3342 | 22.84 | 24.81 |  3539 | 26.28 | 28.17 |  6881
 V6_BBrel_Orig |      6 |  31.4 | 33.57 | 1056 | 22.48 | 24.66 |   192 | 30.03 |  32.2 |  1248
(6 rows)


-- get a common set of samples between original and S2Ku, including in-BB layers

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
 V6_BBrel_BBs2ku |     -3 | 40.32 |  43.5 |  2229 | 31.05 | 32.42 |   9533 | 32.81 | 34.52 |  11762
 V6_BBrel_BBs2ku |   -1.5 |  40.8 | 42.24 | 17838 | 31.38 | 32.05 |  62432 | 33.47 | 34.32 |  80270
 V6_BBrel_BBs2ku |      0 | 39.09 | 40.56 | 24579 | 31.33 | 33.73 | 105882 | 32.79 | 35.01 | 130461
 V6_BBrel_BBs2ku |    1.5 | 34.01 | 34.42 | 13906 | 26.17 | 27.81 |  48862 |  27.9 | 29.27 |  62768
 V6_BBrel_BBs2ku |      3 | 30.62 |  30.6 |  7793 |  23.9 | 24.89 |  16414 | 26.07 | 26.73 |  24207
 V6_BBrel_BBs2ku |    4.5 | 29.92 | 30.34 |  3342 | 22.84 | 24.16 |   3539 | 26.28 | 27.16 |   6881
 V6_BBrel_BBs2ku |      6 |  31.4 | 31.99 |  1056 | 22.48 |    24 |    192 | 30.03 | 30.76 |   1248
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'V6_BBrel_BB_Orig', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

     ?column?     | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 V6_BBrel_BB_Orig |     -3 | 40.32 | 41.68 |  2229 | 31.05 | 31.47 |   9533 | 32.81 |  33.4 |  11762
 V6_BBrel_BB_Orig |   -1.5 |  40.8 | 41.28 | 17838 | 31.38 | 31.54 |  62432 | 33.47 | 33.71 |  80270
 V6_BBrel_BB_Orig |      0 | 39.09 | 40.56 | 24579 | 31.33 | 33.73 | 105882 | 32.79 | 35.01 | 130461
 V6_BBrel_BB_Orig |    1.5 | 34.01 | 35.33 | 13906 | 26.17 |  28.2 |  48862 |  27.9 | 29.78 |  62768
 V6_BBrel_BB_Orig |      3 | 30.62 | 32.01 |  7793 |  23.9 |  25.6 |  16414 | 26.07 | 27.67 |  24207
 V6_BBrel_BB_Orig |    4.5 | 29.92 | 31.72 |  3342 | 22.84 | 24.81 |   3539 | 26.28 | 28.17 |   6881
 V6_BBrel_BB_Orig |      6 |  31.4 | 33.57 |  1056 | 22.48 | 24.66 |    192 | 30.03 |  32.2 |   1248
(7 rows)
