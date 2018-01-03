delete from zdiff_stats_by_dist_time_geo_kma;

\copy zdiff_stats_by_dist_time_geo_kma from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct90_KMA_BBW500m_DefaultS.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma;


delete from zdiff_stats_by_dist_time_geo_kma_bbrel;

\copy zdiff_stats_by_dist_time_geo_kma_bbrel from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct90_KMA_BBW500m_BBREL_DefaultS.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma_bbrel;


delete from zdiff_stats_by_dist_time_geo_kma_s2ku;

\copy zdiff_stats_by_dist_time_geo_kma_s2ku from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct90_KMA_BBW500m_S2Ku.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma_s2ku;


delete from zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel;

\copy zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct90_KMA_BBW500m_BBREL_S2Ku.unl' with delimiter '|'

select count(*) from zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel;



-- get a common set of samples between original and S2Ku, excluding BB layer
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b where a.rangecat<2 and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total');
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

select 'BBrelOrigNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

OLD RESULT USING 750M BB HALFWIDTH AND DEFAULT GV_C AND GV_S FILTERING:
======================================================================
   ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 BBrelOrigNoBB | RGSN     |     -3 | 39.05 | 36.15 | 3844 |  28.8 | 25.79 | 23143 | 30.26 | 27.27 | 26987
 BBrelOrigNoBB | RGSN     |   -1.5 | 38.14 | 35.11 | 3268 | 28.21 | 25.21 | 30437 | 29.18 | 26.17 | 33705
 BBrelOrigNoBB | RGSN     |    1.5 | 30.28 | 27.14 |  841 | 23.14 | 21.07 |  5125 | 24.15 | 21.93 |  5966
 BBrelOrigNoBB | RGSN     |      3 | 29.03 | 25.74 |  425 | 22.99 | 20.78 |  1396 |  24.4 | 21.94 |  1821
 BBrelOrigNoBB | RGSN     |    4.5 | 28.27 | 24.48 |  154 | 22.52 |  19.9 |   154 | 25.39 | 22.19 |   308
 BBrelOrigNoBB | RGSN     |      6 | 28.29 | 25.15 |   47 | 22.97 | 19.43 |     5 | 27.78 |  24.6 |    52
 BBrelOrigNoBB | RJNI     |     -3 | 38.33 | 37.68 | 1936 | 27.32 | 26.99 | 11428 | 28.91 | 28.54 | 13364
 BBrelOrigNoBB | RJNI     |   -1.5 | 37.88 | 37.46 | 3620 | 26.84 | 26.45 | 26785 | 28.15 | 27.76 | 30405
 BBrelOrigNoBB | RJNI     |    1.5 | 29.54 | 29.39 | 1749 | 22.44 | 23.21 |  9128 | 23.58 |  24.2 | 10877
 BBrelOrigNoBB | RJNI     |      3 |  26.9 | 27.25 | 1149 | 22.26 | 22.86 |  2607 | 23.68 |  24.2 |  3756
 BBrelOrigNoBB | RJNI     |    4.5 | 25.72 | 26.77 |  349 | 21.56 | 22.09 |   244 | 24.01 | 24.84 |   593
 BBrelOrigNoBB | RPSN     |     -3 | 38.78 | 36.73 | 1898 | 28.85 | 25.97 |  9591 | 30.49 | 27.75 | 11489
 BBrelOrigNoBB | RPSN     |   -1.5 | 38.66 | 36.88 | 4338 | 28.41 |  25.9 | 28042 | 29.78 | 27.37 | 32380
 BBrelOrigNoBB | RPSN     |    1.5 | 30.13 | 29.04 |  981 | 22.93 |  22.4 |  4692 | 24.18 | 23.55 |  5673
 BBrelOrigNoBB | RPSN     |      3 | 27.37 | 26.57 |  591 |  22.8 | 22.13 |  1115 | 24.39 | 23.67 |  1706
 BBrelOrigNoBB | RPSN     |    4.5 | 26.37 | 24.49 |  115 | 21.96 | 20.38 |    48 | 25.07 | 23.28 |   163
 BBrelOrigNoBB | RPSN     |      6 | 26.12 | 25.74 |   20 |  24.3 |  23.4 |     7 | 25.64 | 25.14 |    27
 BBrelOrigNoBB | RSSP     |     -3 | 38.56 | 35.96 | 3019 | 28.59 | 25.71 | 18949 | 29.96 | 27.12 | 21968
 BBrelOrigNoBB | RSSP     |   -1.5 | 37.85 | 35.02 | 3275 | 28.24 | 25.07 | 30785 | 29.16 | 26.03 | 34060
 BBrelOrigNoBB | RSSP     |    1.5 | 29.49 | 27.35 |  869 | 23.23 | 21.32 |  5314 | 24.11 | 22.17 |  6183
 BBrelOrigNoBB | RSSP     |      3 | 27.99 | 25.72 |  537 | 23.16 | 21.26 |  1294 | 24.58 | 22.57 |  1831
 BBrelOrigNoBB | RSSP     |    4.5 | 26.86 | 24.88 |  163 | 22.75 | 20.84 |   150 | 24.89 | 22.94 |   313
(22 rows)

NEW RESULT USING 500M BB HALFWIDTH AND GV_C AND GV_S FILTERING DISABLED:
=======================================================================
   ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
---------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 BBrelOrigNoBB | RGSN     |     -3 | 38.99 | 36.07 | 3855 | 30.15 | 27.26 | 29339 | 31.17 | 28.29 | 33194
 BBrelOrigNoBB | RGSN     |   -1.5 | 37.97 | 34.93 | 4076 | 29.18 | 26.18 | 47946 | 29.87 | 26.87 | 52022
 BBrelOrigNoBB | RGSN     |      0 | 38.11 | 36.26 |   13 | 30.04 | 28.01 |   378 | 30.31 | 28.28 |   391
 BBrelOrigNoBB | RGSN     |    1.5 | 30.56 |  27.5 | 1160 | 23.99 | 21.89 | 11066 | 24.61 | 22.43 | 12226
 BBrelOrigNoBB | RGSN     |      3 | 28.78 | 25.57 |  439 | 23.21 | 20.93 |  2032 |  24.2 | 21.75 |  2471
 BBrelOrigNoBB | RGSN     |    4.5 |  28.5 | 24.72 |  162 | 22.62 |  20.2 |   207 |  25.2 | 22.18 |   369
 BBrelOrigNoBB | RGSN     |      6 |  28.4 | 25.25 |   48 | 22.92 | 19.61 |     6 | 27.79 | 24.62 |    54
 BBrelOrigNoBB | RJNI     |     -3 | 38.32 | 37.65 | 1910 | 29.41 | 29.34 | 17315 |  30.3 | 30.17 | 19225
 BBrelOrigNoBB | RJNI     |   -1.5 |  37.8 | 37.32 | 4563 | 28.94 | 28.72 | 50891 | 29.66 | 29.42 | 55454
 BBrelOrigNoBB | RJNI     |      0 | 34.02 | 34.94 |   15 | 27.14 |  29.6 |  1098 | 27.23 | 29.68 |  1113
 BBrelOrigNoBB | RJNI     |    1.5 | 30.02 | 29.89 | 2416 |  23.4 |  24.4 | 22303 | 24.05 | 24.94 | 24719
 BBrelOrigNoBB | RJNI     |      3 | 26.84 | 27.16 | 1187 | 22.35 | 22.84 |  4739 | 23.25 | 23.71 |  5926
 BBrelOrigNoBB | RJNI     |    4.5 | 25.63 | 26.63 |  358 | 21.67 | 22.13 |   434 | 23.46 | 24.16 |   792
 BBrelOrigNoBB | RJNI     |      6 | 26.14 | 26.42 |   83 | 21.65 | 23.03 |     9 |  25.7 | 26.09 |    92
 BBrelOrigNoBB | RPSN     |     -3 | 38.82 | 36.75 | 1922 | 30.28 | 27.96 | 13167 | 31.37 | 29.08 | 15089
 BBrelOrigNoBB | RPSN     |   -1.5 | 38.55 | 36.71 | 5408 |  29.6 | 27.52 | 47607 | 30.51 | 28.46 | 53015
 BBrelOrigNoBB | RPSN     |      0 | 36.32 | 34.15 |   12 |  28.7 | 27.98 |   386 | 28.93 | 28.17 |   398
 BBrelOrigNoBB | RPSN     |    1.5 | 30.55 | 29.33 | 1423 | 23.75 | 23.58 | 11717 | 24.49 | 24.21 | 13140
 BBrelOrigNoBB | RPSN     |      3 | 27.29 | 26.52 |  603 | 22.98 | 22.62 |  1861 | 24.03 | 23.57 |  2464
 BBrelOrigNoBB | RPSN     |    4.5 | 26.25 | 24.46 |  110 | 22.59 | 22.24 |   121 | 24.33 |  23.3 |   231
 BBrelOrigNoBB | RPSN     |      6 | 26.12 | 25.74 |   20 | 24.62 | 23.87 |     8 | 25.69 | 25.21 |    28
 BBrelOrigNoBB | RSSP     |     -3 | 38.46 | 35.84 | 3053 | 29.67 | 26.87 | 22703 | 30.71 | 27.93 | 25756
 BBrelOrigNoBB | RSSP     |   -1.5 | 37.73 | 34.77 | 4183 | 29.12 | 25.94 | 46661 | 29.82 | 26.67 | 50844
 BBrelOrigNoBB | RSSP     |      0 | 42.57 | 37.27 |    7 | 29.76 | 27.81 |   493 | 29.94 | 27.94 |   500
 BBrelOrigNoBB | RSSP     |    1.5 | 29.79 | 27.64 | 1353 |  24.1 | 22.38 | 11679 | 24.69 | 22.92 | 13032
 BBrelOrigNoBB | RSSP     |      3 | 27.94 | 25.67 |  556 | 23.44 | 21.56 |  2025 | 24.41 | 22.44 |  2581
 BBrelOrigNoBB | RSSP     |    4.5 | 26.84 | 24.88 |  169 | 22.89 | 21.04 |   210 | 24.66 | 22.75 |   379
 BBrelOrigNoBB | RSSP     |      6 | 29.85 | 27.54 |   39 | 22.56 | 22.19 |     7 | 28.74 | 26.73 |    46
(28 rows)


-- get a common set of samples between orig and s2ku for BB-relative
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, zdiff_stats_by_dist_time_geo_kma_s2ku_BBrel b  where a.rangecat<2 and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total');
drop table convtemp;
drop table strattemp;
drop table alltemp;

-- get Conv, Strat, and All stats for Orig-GR BBrel samples into temp tables
select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_geo_kma_BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_geo_kma_BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_geo_kma_BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

-- collate and output the BBrel stats by rain type for Orig. GR
select 'V6_BBrel_Orig_BB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

OLD RESULT USING 750M BB HALFWIDTH AND DEFAULT GV_C AND GV_S FILTERING:
======================================================================
     ?column?     | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
------------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Orig_BB | RGSN     |     -3 | 39.05 | 36.15 | 3844 |  28.8 | 25.79 | 23143 | 30.26 | 27.27 | 26987
 V6_BBrel_Orig_BB | RGSN     |   -1.5 | 37.94 | 35.01 | 5008 | 28.17 |    25 | 54193 |    29 | 25.85 | 59201
 V6_BBrel_Orig_BB | RGSN     |      0 | 36.18 | 33.95 | 4064 | 28.34 | 26.71 | 59334 | 28.85 | 27.17 | 63398
 V6_BBrel_Orig_BB | RGSN     |    1.5 | 31.38 |  28.4 | 1544 | 24.25 | 22.19 | 12961 | 25.01 | 22.85 | 14505
 V6_BBrel_Orig_BB | RGSN     |      3 | 29.03 | 25.74 |  425 | 22.99 | 20.78 |  1396 |  24.4 | 21.94 |  1821
 V6_BBrel_Orig_BB | RGSN     |    4.5 | 28.27 | 24.48 |  154 | 22.52 |  19.9 |   154 | 25.39 | 22.19 |   308
 V6_BBrel_Orig_BB | RGSN     |      6 | 28.29 | 25.15 |   47 | 22.97 | 19.43 |     5 | 27.78 |  24.6 |    52
 V6_BBrel_Orig_BB | RJNI     |     -3 | 38.33 | 37.68 | 1936 | 27.32 | 26.99 | 11428 | 28.91 | 28.54 | 13364
 V6_BBrel_Orig_BB | RJNI     |   -1.5 | 37.78 |  37.3 | 5133 | 26.91 | 26.45 | 39705 | 28.16 |  27.7 | 44838
 V6_BBrel_Orig_BB | RJNI     |      0 | 36.06 | 36.34 | 5427 | 27.29 | 28.27 | 52793 | 28.11 | 29.02 | 58220
 V6_BBrel_Orig_BB | RJNI     |    1.5 |  30.7 | 30.55 | 2860 |  23.3 | 23.96 | 16635 | 24.39 | 24.92 | 19495
 V6_BBrel_Orig_BB | RJNI     |      3 |  26.9 | 27.25 | 1149 | 22.26 | 22.86 |  2607 | 23.68 |  24.2 |  3756
 V6_BBrel_Orig_BB | RJNI     |    4.5 | 25.72 | 26.77 |  349 | 21.56 | 22.09 |   244 | 24.01 | 24.84 |   593
 V6_BBrel_Orig_BB | RPSN     |     -3 | 38.78 | 36.73 | 1898 | 28.85 | 25.97 |  9591 | 30.49 | 27.75 | 11489
 V6_BBrel_Orig_BB | RPSN     |   -1.5 | 38.51 | 36.72 | 6834 | 28.37 | 26.04 | 47749 | 29.64 | 27.37 | 54583
 V6_BBrel_Orig_BB | RPSN     |      0 |  36.4 | 35.67 | 4602 | 27.93 | 27.06 | 47521 | 28.68 | 27.82 | 52123
 V6_BBrel_Orig_BB | RPSN     |    1.5 | 31.48 | 30.35 | 1848 | 23.84 | 23.26 | 11168 | 24.93 | 24.27 | 13016
 V6_BBrel_Orig_BB | RPSN     |      3 | 27.37 | 26.57 |  591 |  22.8 | 22.13 |  1115 | 24.39 | 23.67 |  1706
 V6_BBrel_Orig_BB | RPSN     |    4.5 | 26.37 | 24.49 |  115 | 21.96 | 20.38 |    48 | 25.07 | 23.28 |   163
 V6_BBrel_Orig_BB | RPSN     |      6 | 26.12 | 25.74 |   20 |  24.3 |  23.4 |     7 | 25.64 | 25.14 |    27
 V6_BBrel_Orig_BB | RSSP     |     -3 | 38.56 | 35.96 | 3019 | 28.59 | 25.71 | 18949 | 29.96 | 27.12 | 21968
 V6_BBrel_Orig_BB | RSSP     |   -1.5 | 37.78 | 34.78 | 5120 | 28.25 | 24.88 | 53080 | 29.09 | 25.75 | 58200
 V6_BBrel_Orig_BB | RSSP     |      0 | 36.09 | 34.14 | 4523 | 28.49 | 26.73 | 58671 | 29.03 | 27.26 | 63194
 V6_BBrel_Orig_BB | RSSP     |    1.5 | 30.74 | 28.69 | 1699 | 24.36 | 22.75 | 13162 | 25.09 | 23.43 | 14861
 V6_BBrel_Orig_BB | RSSP     |      3 | 27.99 | 25.72 |  537 | 23.16 | 21.26 |  1294 | 24.58 | 22.57 |  1831
 V6_BBrel_Orig_BB | RSSP     |    4.5 | 26.86 | 24.88 |  163 | 22.75 | 20.84 |   150 | 24.89 | 22.94 |   313
(26 rows)

NEW RESULT USING 500M BB HALFWIDTH AND GV_C AND GV_S FILTERING DISABLED:
=======================================================================
     ?column?     | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
------------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Orig_BB | RGSN     |     -3 | 38.99 | 36.07 | 3855 | 30.15 | 27.26 | 29339 | 31.17 | 28.29 | 33194
 V6_BBrel_Orig_BB | RGSN     |   -1.5 | 37.85 | 34.88 | 5029 | 29.15 | 26.03 | 64062 | 29.78 | 26.68 | 69091
 V6_BBrel_Orig_BB | RGSN     |      0 |  36.1 | 33.82 | 4094 | 29.23 | 27.85 | 69152 | 29.61 | 28.19 | 73246
 V6_BBrel_Orig_BB | RGSN     |    1.5 | 31.37 | 28.34 | 1572 | 24.78 |  22.8 | 17244 | 25.33 | 23.26 | 18816
 V6_BBrel_Orig_BB | RGSN     |      3 | 28.78 | 25.57 |  439 | 23.21 | 20.93 |  2032 |  24.2 | 21.75 |  2471
 V6_BBrel_Orig_BB | RGSN     |    4.5 |  28.5 | 24.72 |  162 | 22.62 |  20.2 |   207 |  25.2 | 22.18 |   369
 V6_BBrel_Orig_BB | RGSN     |      6 |  28.4 | 25.25 |   48 | 22.92 | 19.61 |     6 | 27.79 | 24.62 |    54
 V6_BBrel_Orig_BB | RJNI     |     -3 | 38.32 | 37.65 | 1910 | 29.41 | 29.34 | 17315 |  30.3 | 30.17 | 19225
 V6_BBrel_Orig_BB | RJNI     |   -1.5 | 37.77 | 37.25 | 5155 | 28.96 | 28.71 | 59194 | 29.67 | 29.39 | 64349
 V6_BBrel_Orig_BB | RJNI     |      0 | 36.05 |  36.3 | 5405 | 28.99 | 30.52 | 74790 | 29.46 | 30.91 | 80195
 V6_BBrel_Orig_BB | RJNI     |    1.5 | 30.64 | 30.48 | 2923 | 23.97 | 24.95 | 28136 |  24.6 | 25.47 | 31059
 V6_BBrel_Orig_BB | RJNI     |      3 | 26.84 | 27.16 | 1187 | 22.35 | 22.84 |  4739 | 23.25 | 23.71 |  5926
 V6_BBrel_Orig_BB | RJNI     |    4.5 | 25.63 | 26.63 |  358 | 21.67 | 22.13 |   434 | 23.46 | 24.16 |   792
 V6_BBrel_Orig_BB | RJNI     |      6 | 26.14 | 26.42 |   83 | 21.65 | 23.03 |     9 |  25.7 | 26.09 |    92
 V6_BBrel_Orig_BB | RPSN     |     -3 | 38.82 | 36.75 | 1922 | 30.28 | 27.96 | 13167 | 31.37 | 29.08 | 15089
 V6_BBrel_Orig_BB | RPSN     |   -1.5 | 38.47 | 36.63 | 6833 | 29.57 | 27.61 | 61983 | 30.45 | 28.51 | 68816
 V6_BBrel_Orig_BB | RPSN     |      0 | 36.38 | 35.61 | 4600 |    29 | 28.66 | 60777 | 29.52 | 29.15 | 65377
 V6_BBrel_Orig_BB | RPSN     |    1.5 | 31.35 | 30.28 | 1915 | 24.51 |  24.4 | 17319 | 25.19 | 24.98 | 19234
 V6_BBrel_Orig_BB | RPSN     |      3 | 27.29 | 26.52 |  603 | 22.98 | 22.62 |  1861 | 24.03 | 23.57 |  2464
 V6_BBrel_Orig_BB | RPSN     |    4.5 | 26.25 | 24.46 |  110 | 22.59 | 22.24 |   121 | 24.33 |  23.3 |   231
 V6_BBrel_Orig_BB | RPSN     |      6 | 26.12 | 25.74 |   20 | 24.62 | 23.87 |     8 | 25.69 | 25.21 |    28
 V6_BBrel_Orig_BB | RSSP     |     -3 | 38.46 | 35.84 | 3053 | 29.67 | 26.87 | 22703 | 30.71 | 27.93 | 25756
 V6_BBrel_Orig_BB | RSSP     |   -1.5 | 37.65 | 34.61 | 5172 | 29.18 | 25.87 | 61733 | 29.84 | 26.54 | 66905
 V6_BBrel_Orig_BB | RSSP     |      0 | 36.04 | 34.02 | 4555 | 29.44 | 27.96 | 69344 | 29.85 | 28.33 | 73899
 V6_BBrel_Orig_BB | RSSP     |    1.5 | 30.49 | 28.46 | 1741 | 24.94 |  23.5 | 17896 | 25.43 | 23.94 | 19637
 V6_BBrel_Orig_BB | RSSP     |      3 | 27.94 | 25.67 |  556 | 23.44 | 21.56 |  2025 | 24.41 | 22.44 |  2581
 V6_BBrel_Orig_BB | RSSP     |    4.5 | 26.84 | 24.88 |  169 | 22.89 | 21.04 |   210 | 24.66 | 22.75 |   379
 V6_BBrel_Orig_BB | RSSP     |      6 | 29.85 | 27.54 |   39 | 22.56 | 22.19 |     7 | 28.74 | 26.73 |    46
(28 rows)

