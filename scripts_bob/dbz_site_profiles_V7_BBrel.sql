-- we are overwriting the KMA statistics with VN v7 matchup results as of 10/31/13

delete from zdiff_stats_by_dist_time_geo_kma_bbrel;

\copy zdiff_stats_by_dist_time_geo_kma_bbrel from '/data/gpmgv/tmp/StatsByDistTimeToDBGeo_Pct100_v7_BBrel_DefaultS.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma_bbrel;


delete from zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel;

\copy zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel from '/data/gpmgv/tmp/StatsByDistTimeToDBGeo_Pct100_v7_BBrel_S2Ku.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel;



-- get a common set of samples between original and S2Ku, excluding BB layer
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b where a.rangecat<2 and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total');
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'BBrelOrigNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

OLD RESULT USING 750M BB HALFWIDTH AND NO GV_C AND GV_S FILTERING:
   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
---------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 BBrelOrigNoBB |     -4 | 42.06 | 42.27 |   501 | 32.76 | 33.91 |    518 | 37.33 | 38.02 |   1019
 BBrelOrigNoBB |     -3 | 41.57 | 42.15 | 16557 |  31.4 | 31.29 |  46761 | 34.06 | 34.13 |  63318
 BBrelOrigNoBB |     -2 |  41.2 | 41.56 | 75909 | 31.04 | 30.89 | 260940 | 33.33 |  33.3 | 336849
 BBrelOrigNoBB |     -1 | 41.44 | 41.02 | 23860 | 31.48 | 31.22 | 116212 | 33.18 | 32.88 | 140072
 BBrelOrigNoBB |      1 | 33.35 | 33.82 | 10696 | 25.04 | 26.43 |  50902 | 26.49 | 27.71 |  61598
 BBrelOrigNoBB |      2 | 31.18 | 31.93 | 62664 | 24.18 | 25.27 | 201393 | 25.84 | 26.85 | 264057
 BBrelOrigNoBB |      3 | 29.45 | 30.41 | 41852 | 23.38 |  24.4 |  97322 |  25.2 | 26.21 | 139174
 BBrelOrigNoBB |      4 | 28.75 |  29.8 | 24490 | 22.64 | 23.64 |  36496 | 25.09 | 26.11 |  60986
 BBrelOrigNoBB |      5 | 29.06 | 30.23 | 12166 | 22.08 | 23.14 |   8413 |  26.2 | 27.33 |  20579
 BBrelOrigNoBB |      6 | 30.03 | 31.46 |  5538 |  22.2 | 23.53 |    700 | 29.15 | 30.57 |   6238
(10 rows)

-- as above, but for S2Ku adjusted GR:
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select 'BBrelS2KuNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
   ?column?    | height |  prc  |  gvc  |  nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
---------------+--------+-------+-------+-------+-------+-------+--------+-------+-------+--------
 BBrelS2KuNoBB |     -4 | 42.06 | 44.14 |   501 | 32.76 | 35.06 |    518 | 37.33 | 39.53 |   1019
 BBrelS2KuNoBB |     -3 | 41.57 | 44.01 | 16557 |  31.4 | 32.22 |  46761 | 34.06 | 35.31 |  63318
 BBrelS2KuNoBB |     -2 |  41.2 | 43.37 | 75909 | 31.04 |  31.8 | 260940 | 33.33 | 34.41 | 336849
 BBrelS2KuNoBB |     -1 | 41.44 | 42.78 | 23860 | 31.48 | 32.15 | 116212 | 33.18 | 33.96 | 140072
 BBrelS2KuNoBB |      1 | 33.35 | 32.21 | 10696 | 25.04 | 25.64 |  50902 | 26.49 | 26.78 |  61598
 BBrelS2KuNoBB |      2 | 31.18 | 30.53 | 62664 | 24.18 | 24.58 | 201393 | 25.84 | 25.99 | 264057
 BBrelS2KuNoBB |      3 | 29.45 | 29.17 | 41852 | 23.38 | 23.79 |  97322 |  25.2 | 25.41 | 139174
 BBrelS2KuNoBB |      4 | 28.75 | 28.63 | 24490 | 22.64 | 23.08 |  36496 | 25.09 | 25.31 |  60986
 BBrelS2KuNoBB |      5 | 29.06 | 29.01 | 12166 | 22.08 | 22.62 |   8413 |  26.2 |  26.4 |  20579
 BBrelS2KuNoBB |      6 | 30.03 | 30.12 |  5538 |  22.2 | 22.97 |    700 | 29.15 | 29.32 |   6238
(10 rows)



-- get a common set of samples between orig and s2ku for BB-relative, including BB layer
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b  where a.rangecat<2 and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total');
drop table convtemp;
drop table strattemp;
drop table alltemp;

-- get Conv, Strat, and All stats for Orig-GR BBrel samples into temp tables
select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

-- collate and output the BBrel stats by rain type for Orig. GR
select 'V7_BBrel_Orig_BB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

OLD RESULT USING 750M BB HALFWIDTH AND NO GV_C AND GV_S FILTERING:
     ?column?     | height |  prc  |  gvc  |   nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+--------+-------+-------+--------+-------+-------+--------
 V7_BBrel_Orig_BB |     -4 | 42.06 | 42.27 |    501 | 32.76 | 33.91 |    518 | 37.33 | 38.02 |   1019
 V7_BBrel_Orig_BB |     -3 | 41.57 | 42.15 |  16557 |  31.4 | 31.29 |  46761 | 34.06 | 34.13 |  63318
 V7_BBrel_Orig_BB |     -2 |  41.2 | 41.56 |  76128 | 31.03 | 30.89 | 263314 | 33.31 | 33.28 | 339442
 V7_BBrel_Orig_BB |     -1 | 40.59 | 40.74 | 124458 | 31.31 | 31.09 | 546570 | 33.03 | 32.88 | 671028
 V7_BBrel_Orig_BB |      0 | 38.81 | 39.96 | 123742 | 31.23 | 33.48 | 613530 | 32.51 | 34.57 | 737272
 V7_BBrel_Orig_BB |      1 | 35.01 | 35.96 |  88100 | 27.44 | 29.44 | 374605 | 28.88 | 30.68 | 462705
 V7_BBrel_Orig_BB |      2 | 31.19 | 31.94 |  62910 | 24.19 | 25.28 | 203339 | 25.85 | 26.86 | 266249
 V7_BBrel_Orig_BB |      3 | 29.45 | 30.41 |  41852 | 23.38 |  24.4 |  97322 |  25.2 | 26.21 | 139174
 V7_BBrel_Orig_BB |      4 | 28.75 |  29.8 |  24490 | 22.64 | 23.64 |  36496 | 25.09 | 26.11 |  60986
 V7_BBrel_Orig_BB |      5 | 29.06 | 30.23 |  12166 | 22.08 | 23.14 |   8413 |  26.2 | 27.33 |  20579
 V7_BBrel_Orig_BB |      6 | 30.03 | 31.46 |   5538 |  22.2 | 23.53 |    700 | 29.15 | 30.57 |   6238
(11 rows)

-- as above, but for S2Ku adjusted GR:
drop table convtemp;
drop table strattemp;
drop table alltemp;

-- get Conv, Strat, and All stats for Orig-GR BBrel samples into temp tables
select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

-- collate and output the BBrel stats by rain type for Ku-Adjusted GR
select 'V7_BBrel_S2Ku_BB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;
     ?column?     | height |  prc  |  gvc  |   nc   |  prs  |  gvs  |   ns   |  pr   |  gv   |   n    
------------------+--------+-------+-------+--------+-------+-------+--------+-------+-------+--------
 V7_BBrel_S2Ku_BB |     -4 | 42.06 | 44.14 |    501 | 32.76 | 35.06 |    518 | 37.33 | 39.53 |   1019
 V7_BBrel_S2Ku_BB |     -3 | 41.57 | 44.01 |  16557 |  31.4 | 32.22 |  46761 | 34.06 | 35.31 |  63318
 V7_BBrel_S2Ku_BB |     -2 |  41.2 | 43.37 |  76128 | 31.03 | 31.79 | 263314 | 33.31 | 34.38 | 339442
 V7_BBrel_S2Ku_BB |     -1 | 40.59 | 41.07 | 124458 | 31.31 | 31.29 | 546570 | 33.03 |  33.1 | 671028
 V7_BBrel_S2Ku_BB |      0 | 38.81 | 39.96 | 123742 | 31.23 | 33.48 | 613530 | 32.51 | 34.57 | 737272
 V7_BBrel_S2Ku_BB |      1 | 35.01 | 35.76 |  88100 | 27.44 | 29.33 | 374605 | 28.88 | 30.56 | 462705
 V7_BBrel_S2Ku_BB |      2 | 31.19 | 30.55 |  62910 | 24.19 |  24.6 | 203339 | 25.85 | 26.01 | 266249
 V7_BBrel_S2Ku_BB |      3 | 29.45 | 29.17 |  41852 | 23.38 | 23.79 |  97322 |  25.2 | 25.41 | 139174
 V7_BBrel_S2Ku_BB |      4 | 28.75 | 28.63 |  24490 | 22.64 | 23.08 |  36496 | 25.09 | 25.31 |  60986
 V7_BBrel_S2Ku_BB |      5 | 29.06 | 29.01 |  12166 | 22.08 | 22.62 |   8413 |  26.2 |  26.4 |  20579
 V7_BBrel_S2Ku_BB |      6 | 30.03 | 30.12 |   5538 |  22.2 | 22.97 |    700 | 29.15 | 29.32 |   6238
(11 rows)
