-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 63441 and 65700;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_225 a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_225 b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7preNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
 ?column?  | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
-----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v7preNoBB |    1.5 | 42.24 | 41.74 | 3835 | 31.64 | 31.43 | 14669 | 33.84 | 33.57 | 18504
 v7preNoBB |      3 | 29.65 | 30.55 |  640 | 25.51 | 26.48 |  2835 | 26.27 | 27.23 |  3475
 v7preNoBB |    4.5 | 31.68 | 32.54 | 5546 | 24.71 | 26.04 | 18384 | 26.33 | 27.55 | 23930
 v7preNoBB |      6 | 29.55 | 30.66 | 5565 | 23.52 | 24.81 | 12155 | 25.41 | 26.65 | 17720
 v7preNoBB |    7.5 | 28.71 | 30.15 | 2509 | 22.47 | 23.65 |  2917 | 25.36 | 26.66 |  5426
 v7preNoBB |      9 | 29.43 |  30.9 |  777 | 22.08 | 23.69 |   157 |  28.2 | 29.69 |   934
(6 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6preNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
 ?column?  | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
-----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 v6preNoBB |    1.5 | 41.84 | 41.51 | 4758 | 31.65 | 31.47 | 17430 | 33.84 | 33.62 | 22188
 v6preNoBB |      3 | 30.83 | 31.39 |  534 |  25.5 | 26.51 |  3074 | 26.29 | 27.24 |  3608
 v6preNoBB |    4.5 | 31.61 | 32.38 | 5794 | 24.69 | 26.02 | 18298 | 26.36 | 27.55 | 24092
 v6preNoBB |      6 | 29.59 | 30.53 | 5719 | 23.54 | 24.82 | 11838 | 25.51 | 26.68 | 17557
 v6preNoBB |    7.5 |  28.8 |  30.1 | 2515 | 22.47 | 23.66 |  2818 | 25.46 | 26.69 |  5333
 v6preNoBB |      9 | 29.52 | 31.02 |  776 | 22.12 | 23.76 |   149 | 28.33 | 29.85 |   925
(6 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_225 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 63441 and 65700;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_225 a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_225 b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_225 c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v7preBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
 ?column? | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 v7preBB  |    1.5 | 41.13 |    41 |  9834 | 31.92 | 32.23 | 47618 | 33.49 | 33.73 | 57452
 v7preBB  |      3 | 38.26 | 39.32 | 15961 | 30.79 | 32.85 | 72345 | 32.14 | 34.02 | 88306
 v7preBB  |    4.5 | 32.96 | 33.92 |  8813 | 25.77 | 27.43 | 29964 |  27.4 |  28.9 | 38777
 v7preBB  |      6 |  29.6 | 30.73 |  5595 | 23.52 | 24.81 | 12168 | 25.43 | 26.67 | 17763
 v7preBB  |    7.5 | 28.71 | 30.15 |  2509 | 22.47 | 23.65 |  2917 | 25.36 | 26.66 |  5426
 v7preBB  |      9 | 29.43 |  30.9 |   777 | 22.08 | 23.69 |   157 |  28.2 | 29.69 |   934
(6 rows)

drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'v6preBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
 ?column? | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------+--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
 v6preBB  |    1.5 | 40.91 | 40.76 | 11100 | 31.89 | 32.18 | 54119 | 33.42 | 33.64 | 65219
 v6preBB  |      3 |  38.3 | 39.32 | 16331 | 30.74 |  32.8 | 72262 | 32.13 |    34 | 88593
 v6preBB  |    4.5 | 33.01 | 33.81 |  9158 | 25.76 | 27.41 | 29739 | 27.47 | 28.92 | 38897
 v6preBB  |      6 | 29.65 | 30.59 |  5750 | 23.53 | 24.82 | 11853 | 25.53 |  26.7 | 17603
 v6preBB  |    7.5 |  28.8 |  30.1 |  2515 | 22.47 | 23.66 |  2818 | 25.46 | 26.69 |  5333
 v6preBB  |      9 | 29.52 | 31.02 |   776 | 22.12 | 23.76 |   149 | 28.33 | 29.85 |   925
(6 rows)
