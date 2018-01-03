-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 65701 and 69085;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_225 a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_225 b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
  ?column?  | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v7postNoBB |    1.5 | 40.43 | 41.37 | 8568 | 30.28 | 30.67 | 36884 |  32.2 | 32.68 | 45452
 v7postNoBB |      3 | 40.23 | 41.13 | 3264 | 29.01 | 29.64 | 11425 |  31.5 | 32.19 | 14689
 v7postNoBB |    4.5 | 30.91 |  31.5 | 1801 | 24.07 | 24.97 | 10827 | 25.04 |  25.9 | 12628
 v7postNoBB |      6 | 30.27 | 31.41 | 5459 | 23.42 | 24.55 | 16770 |  25.1 | 26.24 | 22229
 v7postNoBB |    7.5 | 29.04 |  30.4 | 3250 | 22.54 | 23.73 |  5955 | 24.84 | 26.08 |  9205
 v7postNoBB |      9 | 29.17 | 30.35 | 1341 | 22.03 | 22.95 |   740 | 26.63 | 27.72 |  2081
 v7postNoBB |   10.5 |  29.2 |  30.5 |  595 | 22.83 | 22.53 |    24 | 28.96 | 30.19 |   619
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
  ?column?  | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v6postNoBB |    1.5 | 39.89 | 41.06 | 9872 | 30.17 | 30.59 | 43240 | 31.98 | 32.54 | 53112
 v6postNoBB |      3 | 39.82 | 41.07 | 2932 | 28.91 | 29.59 | 11496 | 31.12 | 31.92 | 14428
 v6postNoBB |    4.5 | 30.82 | 31.28 | 1827 | 24.04 | 24.99 | 10747 | 25.02 | 25.91 | 12574
 v6postNoBB |      6 | 30.62 | 31.56 | 5773 | 23.42 | 24.58 | 16537 | 25.28 | 26.39 | 22310
 v6postNoBB |    7.5 |  29.1 | 30.28 | 3318 | 22.53 | 23.74 |  5772 | 24.93 | 26.13 |  9090
 v6postNoBB |      9 | 29.23 | 30.28 | 1361 | 21.96 |  22.9 |   720 | 26.71 | 27.73 |  2081
 v6postNoBB |   10.5 | 29.25 |  30.5 |  593 | 22.63 | 22.48 |    24 | 28.99 | 30.19 |   617
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 65701 and 69085;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_225 a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_225 b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7postBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
 ?column? | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n    
----------+--------+-------+-------+-------+-------+-------+-------+-------+-------+--------
 v7postBB |    1.5 | 40.19 | 41.05 | 10150 |  30.4 | 30.88 | 53425 | 31.96 |  32.5 |  63575
 v7postBB |      3 | 38.89 | 40.09 | 17403 | 30.14 | 31.46 | 97244 | 31.47 | 32.77 | 114647
 v7postBB |    4.5 | 35.45 | 36.86 | 10935 | 27.51 | 29.75 | 49755 | 28.94 | 31.03 |  60690
 v7postBB |      6 | 30.59 | 31.73 |  5864 | 23.49 | 24.66 | 17904 | 25.25 | 26.41 |  23768
 v7postBB |    7.5 | 29.04 |  30.4 |  3250 | 22.54 | 23.73 |  5955 | 24.84 | 26.08 |   9205
 v7postBB |      9 | 29.17 | 30.35 |  1341 | 22.03 | 22.95 |   740 | 26.63 | 27.72 |   2081
 v7postBB |   10.5 |  29.2 |  30.5 |   595 | 22.83 | 22.53 |    24 | 28.96 | 30.19 |    619
(7 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6postBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

 ?column? | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n    
----------+--------+-------+-------+-------+-------+-------+-------+-------+-------+--------
 v6postBB |    1.5 | 39.74 | 40.78 | 11664 | 30.27 | 30.79 | 61668 | 31.78 | 32.38 |  73332
 v6postBB |      3 | 38.75 | 40.07 | 18107 | 30.09 | 31.44 | 97122 | 31.45 |  32.8 | 115229
 v6postBB |    4.5 | 35.34 | 36.63 | 10978 | 27.49 | 29.77 | 49364 | 28.92 | 31.01 |  60342
 v6postBB |      6 | 30.79 | 31.72 |  6085 | 23.49 | 24.69 | 17733 | 25.36 | 26.49 |  23818
 v6postBB |    7.5 |  29.1 | 30.28 |  3318 | 22.53 | 23.74 |  5772 | 24.93 | 26.13 |   9090
 v6postBB |      9 | 29.23 | 30.28 |  1361 | 21.96 |  22.9 |   720 | 26.71 | 27.73 |   2081
 v6postBB |   10.5 | 29.25 |  30.5 |   593 | 22.63 | 22.48 |    24 | 28.99 | 30.19 |    617
(7 rows)
