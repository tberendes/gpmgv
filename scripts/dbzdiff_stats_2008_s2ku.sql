-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as diffc, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as diffs, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postNoBBs2ku', a.*, diffs, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
    ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v7postNoBBs2ku |    1.5 |  41.3 | 43.35 | 8607 |  30.6 | 31.66 | 32915 | 32.82 | 34.08 | 41522
 v7postNoBBs2ku |      3 |  37.9 | 39.83 | 3885 | 28.46 | 29.42 | 19744 | 30.01 | 31.13 | 23629
 v7postNoBBs2ku |    4.5 | 31.24 | 30.96 | 7276 | 24.46 | 25.17 | 23949 | 26.04 | 26.52 | 31225
 v7postNoBBs2ku |      6 | 29.93 |    30 | 9941 | 23.52 |  24.3 | 23550 | 25.43 | 25.99 | 33491
 v7postNoBBs2ku |    7.5 |    29 |  29.2 | 5273 | 22.59 |  23.3 |  7749 | 25.19 | 25.69 | 13022
 v7postNoBBs2ku |      9 | 29.36 | 29.56 | 1957 | 22.07 | 22.71 |   806 | 27.23 | 27.56 |  2763
 v7postNoBBs2ku |   10.5 | 30.84 | 31.73 |  509 | 23.51 | 25.11 |    16 | 30.62 | 31.53 |   525
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as diffc, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as diffs, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postNoBBs2ku', a.*, diffs, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
    ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 v6postNoBBs2ku |    1.5 | 40.72 | 42.86 | 10285 | 30.51 | 31.61 | 39270 | 32.63 | 33.95 | 49555
 v6postNoBBs2ku |      3 |  38.2 | 40.24 |  3664 | 28.44 | 29.36 | 20147 | 29.94 | 31.04 | 23811
 v6postNoBBs2ku |    4.5 |  31.6 | 31.09 |  7213 | 24.48 | 25.15 | 24462 |  26.1 |  26.5 | 31675
 v6postNoBBs2ku |      6 | 30.13 | 29.95 | 10224 | 23.54 |  24.3 | 23180 | 25.56 | 26.03 | 33404
 v6postNoBBs2ku |    7.5 | 29.07 | 29.08 |  5371 |  22.6 |  23.3 |  7517 | 25.29 | 25.71 | 12888
 v6postNoBBs2ku |      9 | 29.44 |  29.5 |  1965 | 22.02 | 22.73 |   785 | 27.32 | 27.57 |  2750
 v6postNoBBs2ku |   10.5 | 30.81 | 31.59 |   518 | 23.31 | 25.13 |    16 | 30.58 | 31.39 |   534
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
--------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 v7postBBs2ku |    1.5 | 41.02 | 42.53 | 15452 | 30.99 | 32.12 |  69446 | 32.81 | 34.01 |  84898
 v7postBBs2ku |      3 | 38.49 | 39.93 | 28704 | 29.97 | 31.57 | 121010 | 31.61 | 33.17 | 149714
 v7postBBs2ku |    4.5 | 34.08 | 35.04 | 17703 | 27.07 | 29.02 |  64032 | 28.59 | 30.32 |  81735
 v7postBBs2ku |      6 | 30.08 | 30.18 | 10422 | 23.78 |  24.6 |  25864 | 25.59 | 26.21 |  36286
 v7postBBs2ku |    7.5 |    29 |  29.2 |  5273 | 22.59 |  23.3 |   7749 | 25.19 | 25.69 |  13022
 v7postBBs2ku |      9 | 29.36 | 29.56 |  1957 | 22.07 | 22.71 |    806 | 27.23 | 27.56 |   2763
 v7postBBs2ku |   10.5 | 30.84 | 31.73 |   509 | 23.51 | 25.11 |     16 | 30.62 | 31.53 |    525
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
--------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 v6postBBs2ku |    1.5 | 40.65 | 42.12 | 17390 | 30.92 | 32.06 |  80717 | 32.65 | 33.84 |  98107
 v6postBBs2ku |      3 | 38.63 | 39.98 | 28814 | 29.97 | 31.55 | 121944 | 31.63 | 33.16 | 150758
 v6postBBs2ku |    4.5 |  34.2 | 34.97 | 17627 | 27.07 | 28.98 |  64301 |  28.6 | 30.27 |  81928
 v6postBBs2ku |      6 | 30.26 | 30.11 | 10712 | 23.81 | 24.61 |  25526 | 25.72 | 26.24 |  36238
 v6postBBs2ku |    7.5 | 29.07 | 29.08 |  5371 |  22.6 |  23.3 |   7517 | 25.29 | 25.71 |  12888
 v6postBBs2ku |      9 | 29.44 |  29.5 |  1965 | 22.02 | 22.73 |    785 | 27.32 | 27.57 |   2750
 v6postBBs2ku |   10.5 | 30.81 | 31.59 |   518 | 23.31 | 25.13 |     16 | 30.58 | 31.39 |    534
(7 rows)
