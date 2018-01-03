-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 65701 and 69085;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postNoBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
    ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v7postNoBBs2ku |    1.5 | 40.43 | 43.16 | 8568 | 30.28 | 31.55 | 36884 |  32.2 | 33.74 | 45452
 v7postNoBBs2ku |      3 | 40.23 | 42.88 | 3264 | 29.01 | 30.32 | 11425 |  31.5 | 33.11 | 14689
 v7postNoBBs2ku |    4.5 | 30.91 | 30.14 | 1801 | 24.07 |  24.3 | 10827 | 25.04 | 25.14 | 12628
 v7postNoBBs2ku |      6 | 30.27 | 30.07 | 5459 | 23.42 | 23.92 | 16770 |  25.1 | 25.43 | 22229
 v7postNoBBs2ku |    7.5 | 29.04 | 29.18 | 3250 | 22.54 | 23.17 |  5955 | 24.84 | 25.29 |  9205
 v7postNoBBs2ku |      9 | 29.17 | 29.15 | 1341 | 22.03 | 22.45 |   740 | 26.63 | 26.77 |  2081
 v7postNoBBs2ku |   10.5 |  29.2 | 29.29 |  595 | 22.83 | 22.05 |    24 | 28.96 | 29.01 |   619
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postNoBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
    ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v6postNoBBs2ku |    1.5 | 39.89 | 42.83 | 9872 | 30.17 | 31.47 | 43240 | 31.98 | 33.58 | 53112
 v6postNoBBs2ku |      3 | 39.82 | 42.81 | 2932 | 28.91 | 30.26 | 11496 | 31.12 | 32.81 | 14428
 v6postNoBBs2ku |    4.5 | 30.82 | 29.96 | 1827 | 24.04 | 24.33 | 10747 | 25.02 | 25.14 | 12574
 v6postNoBBs2ku |      6 | 30.62 |  30.2 | 5773 | 23.42 | 23.95 | 16537 | 25.28 | 25.57 | 22310
 v6postNoBBs2ku |    7.5 |  29.1 | 29.07 | 3318 | 22.53 | 23.18 |  5772 | 24.93 | 25.33 |  9090
 v6postNoBBs2ku |      9 | 29.23 | 29.08 | 1361 | 21.96 |  22.4 |   720 | 26.71 | 26.77 |  2081
 v6postNoBBs2ku |   10.5 | 29.25 |  29.3 |  593 | 22.63 |    22 |    24 | 28.99 | 29.01 |   617
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 65701 and 69085;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n    
--------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+--------
 v7postBBs2ku |    1.5 | 40.19 | 42.57 | 10150 |  30.4 | 31.49 | 53425 | 31.96 | 33.26 |  63575
 v7postBBs2ku |      3 | 38.89 | 40.42 | 17403 | 30.14 | 31.54 | 97244 | 31.47 | 32.89 | 114647
 v7postBBs2ku |    4.5 | 35.45 | 36.64 | 10935 | 27.51 |  29.6 | 49755 | 28.94 | 30.87 |  60690
 v7postBBs2ku |      6 | 30.59 | 30.48 |  5864 | 23.49 | 24.08 | 17904 | 25.25 | 25.66 |  23768
 v7postBBs2ku |    7.5 | 29.04 | 29.18 |  3250 | 22.54 | 23.17 |  5955 | 24.84 | 25.29 |   9205
 v7postBBs2ku |      9 | 29.17 | 29.15 |  1341 | 22.03 | 22.45 |   740 | 26.63 | 26.77 |   2081
 v7postBBs2ku |   10.5 |  29.2 | 29.29 |   595 | 22.83 | 22.05 |    24 | 28.96 | 29.01 |    619
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n    
--------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+--------
 v6postBBs2ku |    1.5 | 39.74 | 42.28 | 11664 | 30.27 | 31.41 | 61668 | 31.78 | 33.14 |  73332
 v6postBBs2ku |      3 | 38.75 | 40.35 | 18107 | 30.09 | 31.52 | 97122 | 31.45 | 32.91 | 115229
 v6postBBs2ku |    4.5 | 35.34 | 36.41 | 10978 | 27.49 | 29.62 | 49364 | 28.92 | 30.86 |  60342
 v6postBBs2ku |      6 | 30.79 | 30.43 |  6085 | 23.49 | 24.11 | 17733 | 25.36 | 25.72 |  23818
 v6postBBs2ku |    7.5 |  29.1 | 29.07 |  3318 | 22.53 | 23.18 |  5772 | 24.93 | 25.33 |   9090
 v6postBBs2ku |      9 | 29.23 | 29.08 |  1361 | 21.96 |  22.4 |   720 | 26.71 | 26.77 |   2081
 v6postBBs2ku |   10.5 | 29.25 |  29.3 |   593 | 22.63 |    22 |    24 | 28.99 | 29.01 |    617
(7 rows)
