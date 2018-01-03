-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 63441 and 65700;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7preNoBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v7preNoBBs2ku |    1.5 | 42.24 | 43.55 | 3835 | 31.64 | 32.37 | 14669 | 33.84 | 34.69 | 18504
 v7preNoBBs2ku |      3 | 29.65 | 29.74 |  640 | 25.51 | 25.92 |  2835 | 26.27 | 26.62 |  3475
 v7preNoBBs2ku |    4.5 | 31.68 | 31.07 | 5546 | 24.71 | 25.28 | 18384 | 26.33 | 26.63 | 23930
 v7preNoBBs2ku |      6 | 29.55 |  29.4 | 5565 | 23.52 | 24.16 | 12155 | 25.41 | 25.81 | 17720
 v7preNoBBs2ku |    7.5 | 28.71 | 28.94 | 2509 | 22.47 |  23.1 |  2917 | 25.36 |  25.8 |  5426
 v7preNoBBs2ku |      9 | 29.43 | 29.61 |  777 | 22.08 | 23.11 |   157 |  28.2 | 28.52 |   934
(6 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6preNoBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?    | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v6preNoBBs2ku |    1.5 | 41.84 | 43.31 | 4758 | 31.65 | 32.41 | 17430 | 33.84 | 34.74 | 22188
 v6preNoBBs2ku |      3 | 30.83 | 30.55 |  534 |  25.5 | 25.93 |  3074 | 26.29 | 26.61 |  3608
 v6preNoBBs2ku |    4.5 | 31.61 | 30.93 | 5794 | 24.69 | 25.27 | 18298 | 26.36 | 26.63 | 24092
 v6preNoBBs2ku |      6 | 29.59 | 29.28 | 5719 | 23.54 | 24.17 | 11838 | 25.51 | 25.83 | 17557
 v6preNoBBs2ku |    7.5 |  28.8 | 28.89 | 2515 | 22.47 |  23.1 |  2818 | 25.46 | 25.83 |  5333
 v6preNoBBs2ku |      9 | 29.52 | 29.72 |  776 | 22.12 | 23.18 |   149 | 28.33 | 28.66 |   925
(6 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_s2ku a, dbzdiff_stats_by_dist_geo_s2ku_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 63441 and 65700;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_225 a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_225 b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7preBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
  ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
-------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 v7preBBs2ku |    1.5 | 41.13 | 41.71 |  9834 | 31.92 | 32.52 | 47618 | 33.49 | 34.09 | 57452
 v7preBBs2ku |      3 | 38.26 | 39.28 | 15961 | 30.79 | 32.82 | 72345 | 32.14 | 33.99 | 88306
 v7preBBs2ku |    4.5 | 32.96 | 32.99 |  8813 | 25.77 | 26.96 | 29964 |  27.4 | 28.33 | 38777
 v7preBBs2ku |      6 |  29.6 | 29.47 |  5595 | 23.52 | 24.16 | 12168 | 25.43 | 25.83 | 17763
 v7preBBs2ku |    7.5 | 28.71 | 28.94 |  2509 | 22.47 |  23.1 |  2917 | 25.36 |  25.8 |  5426
 v7preBBs2ku |      9 | 29.43 | 29.61 |   777 | 22.08 | 23.11 |   157 |  28.2 | 28.52 |   934
(6 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6preBBs2ku', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
  ?column?   | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
-------------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 v6preBBs2ku |    1.5 | 40.91 | 41.54 | 11100 | 31.89 | 32.48 | 54119 | 33.42 | 34.02 | 65219
 v6preBBs2ku |      3 |  38.3 | 39.29 | 16331 | 30.74 | 32.77 | 72262 | 32.13 | 33.97 | 88593
 v6preBBs2ku |    4.5 | 33.01 | 32.89 |  9158 | 25.76 | 26.95 | 29739 | 27.47 | 28.35 | 38897
 v6preBBs2ku |      6 | 29.65 | 29.35 |  5750 | 23.53 | 24.17 | 11853 | 25.53 | 25.86 | 17603
 v6preBBs2ku |    7.5 |  28.8 | 28.89 |  2515 | 22.47 |  23.1 |  2818 | 25.46 | 25.83 |  5333
 v6preBBs2ku |      9 | 29.52 | 29.72 |   776 | 22.12 | 23.18 |   149 | 28.33 | 28.66 |   925
(6 rows)
