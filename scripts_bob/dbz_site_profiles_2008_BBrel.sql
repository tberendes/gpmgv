-- get a common set of samples between original and S2Ku
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

select 'V6BBrelOrigNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

   ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns  |  pr   |  gv   |  n   
---------------+----------+--------+-------+-------+------+-------+-------+------+-------+-------+------
 V6BBrelOrigNoBB | KAMX     |     -3 | 39.75 | 41.96 |  270 | 33.07 | 34.03 | 1080 | 34.41 | 35.61 | 1350
 V6BBrelOrigNoBB | KAMX     |   -1.5 | 40.02 | 41.59 |  603 | 32.15 | 32.87 | 1538 | 34.37 | 35.32 | 2141
 V6BBrelOrigNoBB | KAMX     |    1.5 | 32.53 | 33.99 |  190 | 24.19 | 25.62 |  301 | 27.42 | 28.86 |  491
 V6BBrelOrigNoBB | KAMX     |      3 | 30.34 | 31.69 |  178 |  23.2 | 25.04 |  195 | 26.61 | 28.22 |  373
 V6BBrelOrigNoBB | KAMX     |    4.5 | 28.24 | 30.16 |   66 | 21.77 | 23.39 |   15 | 27.04 | 28.91 |   81
 V6BBrelOrigNoBB | KBMX     |     -3 | 38.85 | 41.88 |   80 | 30.91 | 32.09 |  238 | 32.91 | 34.55 |  318
 V6BBrelOrigNoBB | KBMX     |   -1.5 | 41.88 | 42.57 |  458 | 30.81 | 31.61 | 1443 | 33.48 | 34.25 | 1901
 V6BBrelOrigNoBB | KBMX     |    1.5 | 34.47 | 36.47 |  811 | 24.91 |  27.1 | 2036 | 27.64 | 29.77 | 2847
 V6BBrelOrigNoBB | KBMX     |      3 |  33.7 | 36.05 |  862 | 24.29 | 26.55 | 1523 | 27.69 | 29.98 | 2385
 V6BBrelOrigNoBB | KBMX     |    4.5 |  33.3 | 35.99 |  460 | 23.27 | 25.51 |  499 | 28.08 | 30.54 |  959
 V6BBrelOrigNoBB | KBMX     |      6 | 33.16 | 36.14 |  249 | 22.75 | 25.66 |   65 | 31.01 | 33.97 |  314
 V6BBrelOrigNoBB | KBRO     |     -3 | 38.98 | 41.19 |   48 | 28.56 | 29.69 |  348 | 29.82 | 31.09 |  396
 V6BBrelOrigNoBB | KBRO     |   -1.5 | 39.74 | 42.51 |  119 | 28.52 | 29.94 |  899 | 29.83 | 31.41 | 1018
 V6BBrelOrigNoBB | KBRO     |    1.5 | 34.59 | 38.35 |   97 | 23.85 | 26.53 |  224 | 27.09 |  30.1 |  321
 V6BBrelOrigNoBB | KBRO     |      3 | 33.55 | 36.44 |  200 | 23.61 | 26.43 |  185 | 28.77 | 31.63 |  385
 V6BBrelOrigNoBB | KBRO     |    4.5 | 31.63 | 34.27 |  102 | 23.32 | 26.59 |   70 | 28.25 | 31.14 |  172
 V6BBrelOrigNoBB | KBYX     |     -3 | 40.16 | 41.46 |  239 | 30.66 | 30.97 | 1525 | 31.95 | 32.39 | 1764
 V6BBrelOrigNoBB | KBYX     |   -1.5 | 39.85 | 41.07 |  329 | 30.78 | 31.01 | 1763 |  32.2 | 32.59 | 2092
 V6BBrelOrigNoBB | KBYX     |    1.5 |  33.8 | 34.08 |   64 | 24.09 | 24.76 |  150 |    27 | 27.55 |  214
 V6BBrelOrigNoBB | KBYX     |      3 | 29.72 | 30.63 |   38 | 23.17 | 23.99 |   74 | 25.39 | 26.24 |  112
 V6BBrelOrigNoBB | KBYX     |    4.5 | 31.17 | 29.16 |    5 |  23.4 | 24.04 |    5 | 27.29 |  26.6 |   10
 V6BBrelOrigNoBB | KCLX     |     -3 | 41.49 | 42.59 |   35 | 29.59 | 29.99 |  235 | 31.14 | 31.63 |  270
 V6BBrelOrigNoBB | KCLX     |   -1.5 | 40.11 | 40.13 |  475 | 31.09 | 31.62 | 2845 | 32.38 | 32.83 | 3320
 V6BBrelOrigNoBB | KCLX     |    1.5 | 30.16 | 31.64 |  470 | 25.01 | 26.81 | 2057 | 25.97 | 27.71 | 2527
 V6BBrelOrigNoBB | KCLX     |      3 | 27.32 | 28.66 |  476 | 23.78 | 25.25 | 1393 | 24.68 | 26.12 | 1869
 V6BBrelOrigNoBB | KCLX     |    4.5 | 26.93 | 28.32 |  128 | 22.77 | 24.34 |  266 | 24.12 | 25.63 |  394
 V6BBrelOrigNoBB | KCLX     |      6 | 28.37 | 30.13 |   29 | 22.98 | 25.07 |   21 | 26.11 |    28 |   50
 V6BBrelOrigNoBB | KCRP     |     -3 | 39.37 | 42.21 |   83 | 29.93 | 30.54 |  358 |  31.7 | 32.74 |  441
 V6BBrelOrigNoBB | KCRP     |   -1.5 | 39.09 |  40.7 |  177 | 30.08 | 30.29 |  682 | 31.94 | 32.44 |  859
 V6BBrelOrigNoBB | KCRP     |    1.5 | 31.12 | 28.75 |   17 |    24 | 25.19 |  168 | 24.65 | 25.52 |  185
 V6BBrelOrigNoBB | KDGX     |     -3 | 38.57 | 40.13 |  183 | 29.23 | 30.56 | 1941 | 30.03 | 31.38 | 2124
 V6BBrelOrigNoBB | KDGX     |   -1.5 | 40.02 | 41.21 |  749 | 29.57 | 30.76 | 3142 | 31.58 | 32.77 | 3891
 V6BBrelOrigNoBB | KDGX     |    1.5 | 31.35 | 33.16 |  419 | 25.23 | 26.83 | 1778 |  26.4 | 28.04 | 2197
 V6BBrelOrigNoBB | KDGX     |      3 | 29.48 | 31.18 |  349 | 24.11 |  25.7 | 1059 | 25.44 | 27.06 | 1408
 V6BBrelOrigNoBB | KDGX     |    4.5 |  27.7 | 29.26 |  141 | 23.24 | 24.85 |  107 | 25.77 | 27.36 |  248
 V6BBrelOrigNoBB | KEVX     |     -3 | 41.84 | 42.55 |   37 |  32.8 | 31.04 |   86 | 35.52 |  34.5 |  123
 V6BBrelOrigNoBB | KEVX     |   -1.5 | 41.76 | 41.12 | 1014 | 33.08 | 32.06 | 2066 | 35.94 | 35.04 | 3080
 V6BBrelOrigNoBB | KEVX     |    1.5 | 32.41 | 32.89 |  618 | 25.42 | 26.07 | 1001 | 28.09 | 28.67 | 1619
 V6BBrelOrigNoBB | KEVX     |      3 | 29.57 | 30.34 |  481 | 23.81 | 24.64 |  513 |  26.6 |  27.4 |  994
 V6BBrelOrigNoBB | KEVX     |    4.5 |  29.3 | 31.02 |  110 | 23.05 | 23.61 |   67 | 26.93 | 28.21 |  177
 V6BBrelOrigNoBB | KFWS     |     -3 | 42.67 | 42.43 |   52 | 29.36 | 28.57 |  149 | 32.81 | 32.15 |  201
 V6BBrelOrigNoBB | KFWS     |   -1.5 | 41.04 | 40.45 |  355 | 29.33 | 28.51 |  892 | 32.67 | 31.91 | 1247
 V6BBrelOrigNoBB | KFWS     |    1.5 | 34.26 | 35.58 |  380 | 24.61 | 26.03 |  867 | 27.55 | 28.94 | 1247
 V6BBrelOrigNoBB | KFWS     |      3 | 31.24 | 32.53 |  406 | 23.79 | 25.28 |  978 | 25.98 | 27.41 | 1384
 V6BBrelOrigNoBB | KFWS     |    4.5 | 29.26 | 30.72 |  231 | 22.51 | 23.91 |  205 | 26.09 | 27.52 |  436
 V6BBrelOrigNoBB | KFWS     |      6 | 28.49 | 28.38 |   57 | 21.44 | 22.45 |    9 | 27.53 | 27.57 |   66
 V6BBrelOrigNoBB | KGRK     |     -3 | 37.91 | 40.96 |   14 | 30.24 | 29.26 |   10 | 34.71 | 36.08 |   24
 V6BBrelOrigNoBB | KGRK     |   -1.5 | 41.08 | 39.49 |  175 | 30.79 | 29.98 |  112 | 37.06 | 35.78 |  287
 V6BBrelOrigNoBB | KGRK     |    1.5 | 35.84 | 36.65 |  162 | 24.82 | 25.82 |  143 | 30.67 | 31.57 |  305
 V6BBrelOrigNoBB | KGRK     |      3 | 33.26 | 34.29 |  218 | 24.22 | 24.48 |  382 |  27.5 | 28.04 |  600
 V6BBrelOrigNoBB | KGRK     |    4.5 | 33.47 | 34.67 |  107 | 23.26 | 23.34 |  141 | 27.66 | 28.23 |  248
 V6BBrelOrigNoBB | KGRK     |      6 | 34.33 | 35.83 |   57 | 22.36 |  22.6 |   16 | 31.71 | 32.93 |   73
 V6BBrelOrigNoBB | KHGX     |     -3 | 39.08 | 38.23 |  124 | 35.03 | 34.04 |  959 | 35.49 | 34.52 | 1083
 V6BBrelOrigNoBB | KHGX     |   -1.5 | 41.09 | 40.74 |  392 | 33.57 | 32.61 | 1220 |  35.4 | 34.59 | 1612
 V6BBrelOrigNoBB | KHGX     |    1.5 | 33.47 | 33.77 |  251 | 25.17 | 26.65 |  990 | 26.85 | 28.09 | 1241
 V6BBrelOrigNoBB | KHGX     |      3 | 30.53 | 30.87 |  273 | 24.19 | 25.44 |  608 | 26.15 | 27.12 |  881
 V6BBrelOrigNoBB | KHGX     |    4.5 | 28.91 | 29.36 |   97 | 23.25 | 24.35 |   66 | 26.62 | 27.33 |  163
 V6BBrelOrigNoBB | KHGX     |      6 | 28.64 |  29.9 |   27 | 24.52 | 25.02 |    6 | 27.89 | 29.01 |   33
 V6BBrelOrigNoBB | KHTX     |     -3 | 41.27 | 43.43 |   11 | 31.45 | 30.76 |   90 | 32.52 | 32.14 |  101
 V6BBrelOrigNoBB | KHTX     |   -1.5 |    41 | 41.43 |  485 | 31.01 | 30.68 | 2706 | 32.53 | 32.31 | 3191
 V6BBrelOrigNoBB | KHTX     |    1.5 | 34.43 | 35.43 |  786 | 25.44 |    27 | 3211 | 27.21 | 28.66 | 3997
 V6BBrelOrigNoBB | KHTX     |      3 |  31.6 | 32.67 |  912 | 24.43 | 26.13 | 2508 | 26.34 | 27.87 | 3420
 V6BBrelOrigNoBB | KHTX     |    4.5 | 29.79 | 31.45 |  444 | 22.96 | 24.82 |  704 |  25.6 | 27.38 | 1148
 V6BBrelOrigNoBB | KHTX     |      6 | 30.27 | 32.72 |  105 | 22.87 | 24.76 |   39 | 28.27 | 30.57 |  144
 V6BBrelOrigNoBB | KJAX     |     -3 | 41.13 | 40.88 |  115 | 33.02 | 32.28 |  309 | 35.22 | 34.61 |  424
 V6BBrelOrigNoBB | KJAX     |   -1.5 | 40.69 | 40.72 |  737 | 32.38 | 32.21 | 2894 | 34.06 | 33.94 | 3631
 V6BBrelOrigNoBB | KJAX     |    1.5 |  31.5 |  34.4 |  528 |  24.7 | 28.06 | 1434 | 26.53 | 29.76 | 1962
 V6BBrelOrigNoBB | KJAX     |      3 | 28.49 |  30.7 |  485 | 23.75 | 25.59 |  678 | 25.72 | 27.72 | 1163
 V6BBrelOrigNoBB | KJAX     |    4.5 | 27.59 | 30.11 |  175 | 22.68 | 24.69 |  141 |  25.4 | 27.69 |  316
 V6BBrelOrigNoBB | KJAX     |      6 | 30.21 |  33.9 |   50 | 23.78 | 25.37 |    5 | 29.63 | 33.13 |   55
 V6BBrelOrigNoBB | KJGX     |     -3 | 43.54 | 45.08 |   54 | 31.35 | 30.99 |   38 |  38.5 | 39.26 |   92
 V6BBrelOrigNoBB | KJGX     |   -1.5 |  40.7 | 40.28 |  392 | 34.34 | 33.25 | 2725 | 35.14 | 34.13 | 3117
 V6BBrelOrigNoBB | KJGX     |    1.5 | 32.41 | 33.24 |  452 | 25.51 | 26.53 | 2378 | 26.62 |  27.6 | 2830
 V6BBrelOrigNoBB | KJGX     |      3 | 30.27 | 31.77 |  378 | 23.99 | 24.65 |  810 | 25.99 | 26.91 | 1188
 V6BBrelOrigNoBB | KJGX     |    4.5 | 30.47 | 32.49 |  129 |  23.7 | 25.06 |   50 | 28.58 | 30.42 |  179
 V6BBrelOrigNoBB | KLCH     |     -3 | 38.83 | 41.51 |  116 | 30.45 | 31.34 |  258 | 33.05 |  34.5 |  374
 V6BBrelOrigNoBB | KLCH     |   -1.5 | 41.44 | 42.33 |  294 | 29.73 | 30.72 |  632 | 33.45 | 34.41 |  926
 V6BBrelOrigNoBB | KLCH     |    1.5 | 31.62 | 33.08 |  354 |  24.7 | 26.71 |  927 | 26.61 | 28.47 | 1281
 V6BBrelOrigNoBB | KLCH     |      3 | 29.09 | 31.27 |  437 | 23.82 | 25.91 |  641 | 25.96 | 28.08 | 1078
 V6BBrelOrigNoBB | KLCH     |    4.5 | 28.59 | 31.27 |  178 | 22.43 | 24.58 |   94 | 26.46 | 28.96 |  272
 V6BBrelOrigNoBB | KLIX     |     -3 | 41.68 | 43.71 |  220 | 30.97 | 32.07 |  286 | 35.63 | 37.13 |  506
 V6BBrelOrigNoBB | KLIX     |   -1.5 | 42.82 | 43.95 |  613 | 31.18 | 32.63 | 1488 | 34.57 | 35.94 | 2101
 V6BBrelOrigNoBB | KLIX     |    1.5 | 34.36 | 36.36 |  423 | 24.88 | 26.99 | 1838 | 26.65 | 28.75 | 2261
 V6BBrelOrigNoBB | KLIX     |      3 | 30.11 |  31.7 |  409 | 23.36 | 25.82 | 1503 | 24.81 | 27.07 | 1912
 V6BBrelOrigNoBB | KLIX     |    4.5 | 28.78 | 30.48 |  170 | 22.37 |  25.3 |  337 | 24.52 | 27.04 |  507
 V6BBrelOrigNoBB | KLIX     |      6 | 32.01 | 32.81 |   30 | 20.88 |  23.7 |   25 | 26.96 | 28.67 |   55
 V6BBrelOrigNoBB | KMLB     |     -3 | 41.47 | 39.25 |  129 | 31.03 |  28.2 |  515 | 33.12 | 30.42 |  644
 V6BBrelOrigNoBB | KMLB     |   -1.5 | 41.32 | 39.68 |  481 | 32.08 |  29.9 |  811 | 35.52 | 33.54 | 1292
 V6BBrelOrigNoBB | KMLB     |    1.5 | 32.84 | 31.93 |  188 | 24.78 | 24.87 |  393 | 27.39 | 27.15 |  581
 V6BBrelOrigNoBB | KMLB     |      3 | 31.08 | 31.05 |  196 | 23.76 | 23.62 |  311 | 26.59 | 26.49 |  507
 V6BBrelOrigNoBB | KMLB     |    4.5 | 29.97 | 30.56 |   87 | 23.03 | 23.12 |   30 | 28.19 | 28.66 |  117
 V6BBrelOrigNoBB | KMOB     |     -3 | 39.43 | 41.89 |  179 |  31.6 | 32.63 |  207 | 35.23 | 36.93 |  386
 V6BBrelOrigNoBB | KMOB     |   -1.5 | 40.31 | 40.37 |  486 | 30.69 |  30.7 | 1285 | 33.33 | 33.35 | 1771
 V6BBrelOrigNoBB | KMOB     |    1.5 | 32.32 | 29.74 |  361 | 24.72 | 24.97 | 1230 | 26.44 | 26.05 | 1591
 V6BBrelOrigNoBB | KMOB     |      3 | 29.74 | 27.24 |  295 | 23.59 | 23.45 |  635 | 25.54 | 24.65 |  930
 V6BBrelOrigNoBB | KMOB     |    4.5 |  33.2 | 31.59 |   75 |  23.1 | 22.97 |   37 | 29.86 | 28.74 |  112
 V6BBrelOrigNoBB | KSHV     |     -3 | 44.67 | 47.52 |   16 | 29.22 | 31.04 |  285 | 30.04 | 31.91 |  301
 V6BBrelOrigNoBB | KSHV     |   -1.5 | 43.05 | 44.14 |  448 | 29.28 | 30.65 |  904 | 33.85 | 35.12 | 1352
 V6BBrelOrigNoBB | KSHV     |    1.5 | 34.02 | 35.88 |  579 | 24.72 | 27.08 |  993 | 28.15 | 30.32 | 1572
 V6BBrelOrigNoBB | KSHV     |      3 | 31.08 | 33.02 |  758 | 23.51 | 26.14 |  955 | 26.86 | 29.18 | 1713
 V6BBrelOrigNoBB | KSHV     |    4.5 | 29.34 | 31.28 |  468 | 22.38 |  24.9 |  396 | 26.15 | 28.36 |  864
 V6BBrelOrigNoBB | KSHV     |      6 | 30.66 | 32.97 |  170 | 20.56 | 23.57 |    6 | 30.31 | 32.65 |  176
 V6BBrelOrigNoBB | KTBW     |     -3 | 41.51 | 42.47 |  218 | 31.13 | 31.88 |  562 | 34.03 | 34.84 |  780
 V6BBrelOrigNoBB | KTBW     |   -1.5 | 41.19 | 42.07 |  445 | 30.37 | 31.07 | 1403 | 32.98 | 33.72 | 1848
 V6BBrelOrigNoBB | KTBW     |    1.5 | 32.32 |  33.3 |  231 | 24.41 | 26.57 |  624 | 26.55 | 28.39 |  855
 V6BBrelOrigNoBB | KTBW     |      3 | 30.62 | 31.35 |  228 | 22.89 | 24.53 |  372 | 25.83 | 27.12 |  600
 V6BBrelOrigNoBB | KTBW     |    4.5 | 29.51 | 30.62 |  108 | 21.84 | 22.97 |   20 | 28.31 | 29.43 |  128
 V6BBrelOrigNoBB | KTLH     |     -3 | 42.09 | 46.41 |    6 | 27.79 |  30.8 |   54 | 29.22 | 32.36 |   60
 V6BBrelOrigNoBB | KTLH     |   -1.5 | 39.53 | 40.95 |  389 | 31.33 | 33.63 | 1765 | 32.81 | 34.96 | 2154
 V6BBrelOrigNoBB | KTLH     |    1.5 | 29.31 | 31.46 |  182 | 24.82 | 27.87 |  989 | 25.52 | 28.43 | 1171
 V6BBrelOrigNoBB | KTLH     |      3 | 28.23 | 30.16 |  214 | 23.96 |  26.9 |  983 | 24.72 | 27.48 | 1197
 V6BBrelOrigNoBB | KTLH     |    4.5 | 28.49 | 30.37 |   61 | 22.76 | 25.47 |  267 | 23.82 | 26.38 |  328
(112 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b  where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

select 'V6_BBrel_Orig_BB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

    ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Orig_BB | KAMX     |     -3 | 39.75 | 41.96 |  270 | 33.07 | 34.03 |  1080 | 34.41 | 35.61 |  1350
 V6_BBrel_Orig_BB | KAMX     |   -1.5 | 39.89 |  41.5 | 1002 | 32.22 | 32.83 |  2552 | 34.38 | 35.28 |  3554
 V6_BBrel_Orig_BB | KAMX     |      0 | 38.21 | 40.25 |  860 | 31.81 |  34.1 |  2037 | 33.71 | 35.93 |  2897
 V6_BBrel_Orig_BB | KAMX     |    1.5 | 32.95 |  34.7 |  390 | 25.93 |  27.7 |   795 | 28.24 |    30 |  1185
 V6_BBrel_Orig_BB | KAMX     |      3 | 30.34 | 31.69 |  178 |  23.2 | 25.04 |   195 | 26.61 | 28.22 |   373
 V6_BBrel_Orig_BB | KAMX     |    4.5 | 28.24 | 30.16 |   66 | 21.77 | 23.39 |    15 | 27.04 | 28.91 |    81
 V6_BBrel_Orig_BB | KBMX     |     -3 | 38.85 | 41.88 |   80 | 30.91 | 32.09 |   238 | 32.91 | 34.55 |   318
 V6_BBrel_Orig_BB | KBMX     |   -1.5 | 41.22 | 42.14 | 1180 | 30.93 | 31.55 |  3660 | 33.44 | 34.13 |  4840
 V6_BBrel_Orig_BB | KBMX     |      0 | 39.87 | 42.19 | 2498 | 30.28 | 33.21 | 10703 |  32.1 | 34.91 | 13201
 V6_BBrel_Orig_BB | KBMX     |    1.5 | 35.28 | 37.18 | 1509 | 25.94 | 28.19 |  4382 | 28.33 |  30.5 |  5891
 V6_BBrel_Orig_BB | KBMX     |      3 |  33.7 | 36.05 |  862 | 24.29 | 26.55 |  1523 | 27.69 | 29.98 |  2385
 V6_BBrel_Orig_BB | KBMX     |    4.5 |  33.3 | 35.99 |  460 | 23.27 | 25.51 |   499 | 28.08 | 30.54 |   959
 V6_BBrel_Orig_BB | KBMX     |      6 | 33.16 | 36.14 |  249 | 22.75 | 25.66 |    65 | 31.01 | 33.97 |   314
 V6_BBrel_Orig_BB | KBRO     |     -3 | 38.98 | 41.19 |   48 | 28.56 | 29.69 |   348 | 29.82 | 31.09 |   396
 V6_BBrel_Orig_BB | KBRO     |   -1.5 | 39.56 | 42.55 |  235 | 28.83 | 30.11 |  1664 | 30.16 | 31.65 |  1899
 V6_BBrel_Orig_BB | KBRO     |      0 | 38.51 | 41.15 |  285 | 29.73 | 32.92 |  1590 | 31.07 | 34.17 |  1875
 V6_BBrel_Orig_BB | KBRO     |    1.5 | 35.89 | 39.16 |  212 | 25.43 | 28.05 |   513 | 28.49 |  31.3 |   725
 V6_BBrel_Orig_BB | KBRO     |      3 | 33.55 | 36.44 |  200 | 23.61 | 26.43 |   185 | 28.77 | 31.63 |   385
 V6_BBrel_Orig_BB | KBRO     |    4.5 | 31.63 | 34.27 |  102 | 23.32 | 26.59 |    70 | 28.25 | 31.14 |   172
 V6_BBrel_Orig_BB | KBYX     |     -3 | 40.16 | 41.46 |  239 | 30.66 | 30.97 |  1525 | 31.95 | 32.39 |  1764
 V6_BBrel_Orig_BB | KBYX     |   -1.5 | 39.56 | 40.85 |  517 | 31.01 | 31.26 |  3017 | 32.26 | 32.66 |  3534
 V6_BBrel_Orig_BB | KBYX     |      0 | 37.72 | 39.24 |  379 | 31.28 | 33.22 |  2330 | 32.18 | 34.06 |  2709
 V6_BBrel_Orig_BB | KBYX     |    1.5 | 33.44 | 33.82 |  150 | 26.21 | 26.66 |   569 | 27.72 | 28.16 |   719
 V6_BBrel_Orig_BB | KBYX     |      3 | 29.72 | 30.63 |   38 | 23.17 | 23.99 |    74 | 25.39 | 26.24 |   112
 V6_BBrel_Orig_BB | KBYX     |    4.5 | 31.17 | 29.16 |    5 |  23.4 | 24.04 |     5 | 27.29 |  26.6 |    10
 V6_BBrel_Orig_BB | KCLX     |     -3 | 41.49 | 42.59 |   35 | 29.59 | 29.99 |   235 | 31.14 | 31.63 |   270
 V6_BBrel_Orig_BB | KCLX     |   -1.5 | 39.87 | 40.06 |  917 | 31.08 | 31.62 |  5107 | 32.42 | 32.91 |  6024
 V6_BBrel_Orig_BB | KCLX     |      0 | 38.22 | 40.19 | 1488 | 31.61 | 34.34 |  7675 | 32.68 | 35.29 |  9163
 V6_BBrel_Orig_BB | KCLX     |    1.5 | 31.83 | 33.67 |  799 | 26.14 | 28.75 |  3933 |  27.1 | 29.58 |  4732
 V6_BBrel_Orig_BB | KCLX     |      3 | 27.32 | 28.66 |  476 | 23.78 | 25.25 |  1393 | 24.68 | 26.12 |  1869
 V6_BBrel_Orig_BB | KCLX     |    4.5 | 26.93 | 28.32 |  128 | 22.77 | 24.34 |   266 | 24.12 | 25.63 |   394
 V6_BBrel_Orig_BB | KCLX     |      6 | 28.37 | 30.13 |   29 | 22.98 | 25.07 |    21 | 26.11 |    28 |    50
 V6_BBrel_Orig_BB | KCRP     |     -3 | 39.37 | 42.21 |   83 | 29.93 | 30.54 |   358 |  31.7 | 32.74 |   441
 V6_BBrel_Orig_BB | KCRP     |   -1.5 | 38.92 | 40.11 |  249 |    30 | 30.03 |  1311 | 31.42 | 31.64 |  1560
 V6_BBrel_Orig_BB | KCRP     |      0 | 36.78 | 37.88 |  182 | 29.76 | 31.88 |  1308 | 30.62 | 32.61 |  1490
 V6_BBrel_Orig_BB | KCRP     |    1.5 |    31 | 30.67 |   50 | 25.26 | 26.71 |   410 | 25.88 | 27.14 |   460
 V6_BBrel_Orig_BB | KDGX     |     -3 | 38.57 | 40.13 |  183 | 29.23 | 30.56 |  1941 | 30.03 | 31.38 |  2124
 V6_BBrel_Orig_BB | KDGX     |   -1.5 | 39.93 | 40.97 | 1302 | 29.94 | 30.94 |  5318 |  31.9 | 32.91 |  6620
 V6_BBrel_Orig_BB | KDGX     |      0 | 38.29 | 40.38 | 1530 | 30.52 | 33.19 |  9461 |  31.6 | 34.19 | 10991
 V6_BBrel_Orig_BB | KDGX     |    1.5 |  32.8 | 34.35 |  784 | 26.25 | 27.89 |  3941 | 27.33 | 28.96 |  4725
 V6_BBrel_Orig_BB | KDGX     |      3 | 29.48 | 31.18 |  349 | 24.11 |  25.7 |  1059 | 25.44 | 27.06 |  1408
 V6_BBrel_Orig_BB | KDGX     |    4.5 |  27.7 | 29.26 |  141 | 23.24 | 24.85 |   107 | 25.77 | 27.36 |   248
 V6_BBrel_Orig_BB | KEVX     |     -3 | 41.84 | 42.55 |   37 |  32.8 | 31.04 |    86 | 35.52 |  34.5 |   123
 V6_BBrel_Orig_BB | KEVX     |   -1.5 | 41.54 | 41.04 | 1854 | 33.05 | 31.91 |  3973 | 35.75 | 34.81 |  5827
 V6_BBrel_Orig_BB | KEVX     |      0 | 39.39 | 39.68 | 2110 | 32.59 |  33.5 |  5104 | 34.58 | 35.31 |  7214
 V6_BBrel_Orig_BB | KEVX     |    1.5 | 33.46 | 34.06 | 1120 | 26.81 | 27.92 |  2020 | 29.18 | 30.11 |  3140
 V6_BBrel_Orig_BB | KEVX     |      3 | 29.57 | 30.34 |  481 | 23.81 | 24.64 |   513 |  26.6 |  27.4 |   994
 V6_BBrel_Orig_BB | KEVX     |    4.5 |  29.3 | 31.02 |  110 | 23.05 | 23.61 |    67 | 26.93 | 28.21 |   177
 V6_BBrel_Orig_BB | KFWS     |     -3 | 42.67 | 42.43 |   52 | 29.36 | 28.57 |   149 | 32.81 | 32.15 |   201
 V6_BBrel_Orig_BB | KFWS     |   -1.5 | 40.38 | 39.94 |  619 | 29.34 | 28.55 |  1658 | 32.34 | 31.65 |  2277
 V6_BBrel_Orig_BB | KFWS     |      0 | 38.56 | 39.25 | 1106 | 28.96 | 30.69 |  3889 | 31.08 | 32.58 |  4995
 V6_BBrel_Orig_BB | KFWS     |    1.5 | 35.24 | 36.27 |  684 | 25.42 | 27.07 |  1737 | 28.19 | 29.67 |  2421
 V6_BBrel_Orig_BB | KFWS     |      3 | 31.24 | 32.53 |  406 | 23.79 | 25.28 |   978 | 25.98 | 27.41 |  1384
 V6_BBrel_Orig_BB | KFWS     |    4.5 | 29.26 | 30.72 |  231 | 22.51 | 23.91 |   205 | 26.09 | 27.52 |   436
 V6_BBrel_Orig_BB | KFWS     |      6 | 28.49 | 28.38 |   57 | 21.44 | 22.45 |     9 | 27.53 | 27.57 |    66
 V6_BBrel_Orig_BB | KGRK     |     -3 | 37.91 | 40.96 |   14 | 30.24 | 29.26 |    10 | 34.71 | 36.08 |    24
 V6_BBrel_Orig_BB | KGRK     |   -1.5 | 41.46 | 40.06 |  257 | 30.94 | 29.93 |   167 | 37.31 | 36.07 |   424
 V6_BBrel_Orig_BB | KGRK     |      0 | 40.55 | 40.38 |  401 | 29.32 |  30.8 |   480 | 34.43 | 35.16 |   881
 V6_BBrel_Orig_BB | KGRK     |    1.5 | 36.42 | 37.49 |  285 |  25.9 | 27.44 |   319 | 30.87 | 32.18 |   604
 V6_BBrel_Orig_BB | KGRK     |      3 | 33.26 | 34.29 |  218 | 24.22 | 24.48 |   382 |  27.5 | 28.04 |   600
 V6_BBrel_Orig_BB | KGRK     |    4.5 | 33.47 | 34.67 |  107 | 23.26 | 23.34 |   141 | 27.66 | 28.23 |   248
 V6_BBrel_Orig_BB | KGRK     |      6 | 34.33 | 35.83 |   57 | 22.36 |  22.6 |    16 | 31.71 | 32.93 |    73
 V6_BBrel_Orig_BB | KHGX     |     -3 | 39.08 | 38.23 |  124 | 35.03 | 34.04 |   959 | 35.49 | 34.52 |  1083
 V6_BBrel_Orig_BB | KHGX     |   -1.5 | 40.93 | 40.72 |  740 |  33.3 | 32.28 |  2131 | 35.27 | 34.46 |  2871
 V6_BBrel_Orig_BB | KHGX     |      0 | 39.59 | 40.47 |  830 | 32.28 | 33.94 |  2813 | 33.94 | 35.43 |  3643
 V6_BBrel_Orig_BB | KHGX     |    1.5 | 34.87 | 35.27 |  473 | 26.23 | 27.76 |  1721 | 28.09 | 29.37 |  2194
 V6_BBrel_Orig_BB | KHGX     |      3 | 30.53 | 30.87 |  273 | 24.19 | 25.44 |   608 | 26.15 | 27.12 |   881
 V6_BBrel_Orig_BB | KHGX     |    4.5 | 28.91 | 29.36 |   97 | 23.25 | 24.35 |    66 | 26.62 | 27.33 |   163
 V6_BBrel_Orig_BB | KHGX     |      6 | 28.64 |  29.9 |   27 | 24.52 | 25.02 |     6 | 27.89 | 29.01 |    33
 V6_BBrel_Orig_BB | KHTX     |     -3 | 41.27 | 43.43 |   11 | 31.45 | 30.76 |    90 | 32.52 | 32.14 |   101
 V6_BBrel_Orig_BB | KHTX     |   -1.5 | 41.26 |  41.7 | 1062 |  31.2 | 30.83 |  5726 | 32.77 | 32.53 |  6788
 V6_BBrel_Orig_BB | KHTX     |      0 |  38.9 | 40.02 | 2568 |  31.4 | 33.74 | 17315 | 32.37 | 34.55 | 19883
 V6_BBrel_Orig_BB | KHTX     |    1.5 |  35.1 | 35.89 | 1453 | 26.34 | 28.12 |  6826 | 27.88 | 29.48 |  8279
 V6_BBrel_Orig_BB | KHTX     |      3 |  31.6 | 32.67 |  912 | 24.43 | 26.13 |  2508 | 26.34 | 27.87 |  3420
 V6_BBrel_Orig_BB | KHTX     |    4.5 | 29.79 | 31.45 |  444 | 22.96 | 24.82 |   704 |  25.6 | 27.38 |  1148
 V6_BBrel_Orig_BB | KHTX     |      6 | 30.27 | 32.72 |  105 | 22.87 | 24.76 |    39 | 28.27 | 30.57 |   144
 V6_BBrel_Orig_BB | KJAX     |     -3 | 41.13 | 40.88 |  115 | 33.02 | 32.28 |   309 | 35.22 | 34.61 |   424
 V6_BBrel_Orig_BB | KJAX     |   -1.5 | 40.87 | 41.31 | 1486 | 32.13 | 32.04 |  4993 | 34.14 | 34.17 |  6479
 V6_BBrel_Orig_BB | KJAX     |      0 | 38.88 | 40.78 | 1758 | 31.79 |  33.5 |  6004 |  33.4 | 35.15 |  7762
 V6_BBrel_Orig_BB | KJAX     |    1.5 | 32.69 | 36.31 |  986 | 25.74 | 30.56 |  2760 | 27.57 | 32.08 |  3746
 V6_BBrel_Orig_BB | KJAX     |      3 | 28.49 |  30.7 |  485 | 23.75 | 25.59 |   678 | 25.72 | 27.72 |  1163
 V6_BBrel_Orig_BB | KJAX     |    4.5 | 27.59 | 30.11 |  175 | 22.68 | 24.69 |   141 |  25.4 | 27.69 |   316
 V6_BBrel_Orig_BB | KJAX     |      6 | 30.21 |  33.9 |   50 | 23.78 | 25.37 |     5 | 29.63 | 33.13 |    55
 V6_BBrel_Orig_BB | KJGX     |     -3 | 43.54 | 45.08 |   54 | 31.35 | 30.99 |    38 |  38.5 | 39.26 |    92
 V6_BBrel_Orig_BB | KJGX     |   -1.5 | 40.92 | 40.66 |  910 | 33.98 | 33.02 |  5750 | 34.93 | 34.06 |  6660
 V6_BBrel_Orig_BB | KJGX     |      0 | 39.75 | 41.01 | 1581 | 33.07 | 34.91 | 10282 | 33.96 | 35.72 | 11863
 V6_BBrel_Orig_BB | KJGX     |    1.5 | 33.56 | 34.45 |  886 |  26.9 | 28.47 |  5108 | 27.88 | 29.35 |  5994
 V6_BBrel_Orig_BB | KJGX     |      3 | 30.27 | 31.77 |  378 | 23.99 | 24.65 |   810 | 25.99 | 26.91 |  1188
 V6_BBrel_Orig_BB | KJGX     |    4.5 | 30.47 | 32.49 |  129 |  23.7 | 25.06 |    50 | 28.58 | 30.42 |   179
 V6_BBrel_Orig_BB | KLCH     |     -3 | 38.83 | 41.51 |  116 | 30.45 | 31.34 |   258 | 33.05 |  34.5 |   374
 V6_BBrel_Orig_BB | KLCH     |   -1.5 | 41.43 | 42.38 |  465 | 30.53 |  31.2 |  1285 | 33.43 | 34.17 |  1750
 V6_BBrel_Orig_BB | KLCH     |      0 | 40.12 | 43.25 |  742 | 32.97 | 36.47 |  2838 | 34.45 | 37.87 |  3580
 V6_BBrel_Orig_BB | KLCH     |    1.5 | 33.35 | 35.07 |  618 | 26.29 | 28.67 |  1771 | 28.12 | 30.32 |  2389
 V6_BBrel_Orig_BB | KLCH     |      3 | 29.09 | 31.27 |  437 | 23.82 | 25.91 |   641 | 25.96 | 28.08 |  1078
 V6_BBrel_Orig_BB | KLCH     |    4.5 | 28.59 | 31.27 |  178 | 22.43 | 24.58 |    94 | 26.46 | 28.96 |   272
 V6_BBrel_Orig_BB | KLIX     |     -3 | 41.68 | 43.71 |  220 | 30.97 | 32.07 |   286 | 35.63 | 37.13 |   506
 V6_BBrel_Orig_BB | KLIX     |   -1.5 | 41.98 | 43.37 |  941 | 31.16 | 32.53 |  2494 | 34.12 |  35.5 |  3435
 V6_BBrel_Orig_BB | KLIX     |      0 | 40.15 | 42.51 | 1076 | 31.42 | 35.08 |  4175 | 33.21 |  36.6 |  5251
 V6_BBrel_Orig_BB | KLIX     |    1.5 | 34.94 | 36.89 |  621 | 26.01 | 28.11 |  3155 | 27.48 | 29.55 |  3776
 V6_BBrel_Orig_BB | KLIX     |      3 | 30.11 |  31.7 |  409 | 23.36 | 25.82 |  1503 | 24.81 | 27.07 |  1912
 V6_BBrel_Orig_BB | KLIX     |    4.5 | 28.78 | 30.48 |  170 | 22.37 |  25.3 |   337 | 24.52 | 27.04 |   507
 V6_BBrel_Orig_BB | KLIX     |      6 | 32.01 | 32.81 |   30 | 20.88 |  23.7 |    25 | 26.96 | 28.67 |    55
 V6_BBrel_Orig_BB | KMLB     |     -3 | 41.47 | 39.25 |  129 | 31.03 |  28.2 |   515 | 33.12 | 30.42 |   644
 V6_BBrel_Orig_BB | KMLB     |   -1.5 | 40.98 | 39.47 |  886 |  32.1 | 29.91 |  1477 | 35.43 |  33.5 |  2363
 V6_BBrel_Orig_BB | KMLB     |      0 | 39.17 | 38.64 |  940 | 31.61 | 31.77 |  1882 | 34.13 | 34.06 |  2822
 V6_BBrel_Orig_BB | KMLB     |    1.5 | 34.16 | 33.72 |  417 | 26.13 | 26.61 |   906 | 28.66 | 28.85 |  1323
 V6_BBrel_Orig_BB | KMLB     |      3 | 31.08 | 31.05 |  196 | 23.76 | 23.62 |   311 | 26.59 | 26.49 |   507
 V6_BBrel_Orig_BB | KMLB     |    4.5 | 29.97 | 30.56 |   87 | 23.03 | 23.12 |    30 | 28.19 | 28.66 |   117
 V6_BBrel_Orig_BB | KMOB     |     -3 | 39.43 | 41.89 |  179 |  31.6 | 32.63 |   207 | 35.23 | 36.93 |   386
 V6_BBrel_Orig_BB | KMOB     |   -1.5 | 40.34 | 40.08 |  769 | 30.62 | 30.59 |  2477 | 32.93 | 32.84 |  3246
 V6_BBrel_Orig_BB | KMOB     |      0 | 39.75 | 39.79 | 1025 | 31.26 | 33.55 |  4829 | 32.74 | 34.64 |  5854
 V6_BBrel_Orig_BB | KMOB     |    1.5 | 33.85 | 31.65 |  637 | 26.31 | 26.82 |  2654 | 27.77 | 27.76 |  3291
 V6_BBrel_Orig_BB | KMOB     |      3 | 29.74 | 27.24 |  295 | 23.59 | 23.45 |   635 | 25.54 | 24.65 |   930
 V6_BBrel_Orig_BB | KMOB     |    4.5 |  33.2 | 31.59 |   75 |  23.1 | 22.97 |    37 | 29.86 | 28.74 |   112
 V6_BBrel_Orig_BB | KSHV     |     -3 | 44.67 | 47.52 |   16 | 29.22 | 31.04 |   285 | 30.04 | 31.91 |   301
 V6_BBrel_Orig_BB | KSHV     |   -1.5 | 42.03 | 43.23 |  930 | 29.81 | 30.83 |  1949 | 33.75 | 34.84 |  2879
 V6_BBrel_Orig_BB | KSHV     |      0 | 39.01 |  40.9 | 1504 | 30.35 | 33.56 |  3740 | 32.83 | 35.67 |  5244
 V6_BBrel_Orig_BB | KSHV     |    1.5 | 34.68 | 36.56 |  971 | 25.62 | 28.03 |  1876 | 28.71 | 30.94 |  2847
 V6_BBrel_Orig_BB | KSHV     |      3 | 31.08 | 33.02 |  758 | 23.51 | 26.14 |   955 | 26.86 | 29.18 |  1713
 V6_BBrel_Orig_BB | KSHV     |    4.5 | 29.34 | 31.28 |  468 | 22.38 |  24.9 |   396 | 26.15 | 28.36 |   864
 V6_BBrel_Orig_BB | KSHV     |      6 | 30.66 | 32.97 |  170 | 20.56 | 23.57 |     6 | 30.31 | 32.65 |   176
 V6_BBrel_Orig_BB | KTBW     |     -3 | 41.51 | 42.47 |  218 | 31.13 | 31.88 |   562 | 34.03 | 34.84 |   780
 V6_BBrel_Orig_BB | KTBW     |   -1.5 |    41 | 42.05 |  874 | 30.34 | 30.95 |  2395 | 33.19 | 33.92 |  3269
 V6_BBrel_Orig_BB | KTBW     |      0 |  39.2 | 40.79 |  908 | 30.91 | 33.48 |  2858 | 32.91 | 35.24 |  3766
 V6_BBrel_Orig_BB | KTBW     |    1.5 | 34.15 | 35.25 |  466 | 25.66 | 28.01 |  1212 | 28.02 | 30.02 |  1678
 V6_BBrel_Orig_BB | KTBW     |      3 | 30.62 | 31.35 |  228 | 22.89 | 24.53 |   372 | 25.83 | 27.12 |   600
 V6_BBrel_Orig_BB | KTBW     |    4.5 | 29.51 | 30.62 |  108 | 21.84 | 22.97 |    20 | 28.31 | 29.43 |   128
 V6_BBrel_Orig_BB | KTLH     |     -3 | 42.09 | 46.41 |    6 | 27.79 |  30.8 |    54 | 29.22 | 32.36 |    60
 V6_BBrel_Orig_BB | KTLH     |   -1.5 | 39.54 | 41.46 |  643 | 31.05 | 33.18 |  3328 | 32.42 | 34.52 |  3971
 V6_BBrel_Orig_BB | KTLH     |      0 | 37.23 | 39.77 |  808 | 31.14 | 34.87 |  4569 | 32.06 | 35.61 |  5377
 V6_BBrel_Orig_BB | KTLH     |    1.5 |  31.5 | 33.82 |  395 | 25.95 | 29.29 |  2254 | 26.78 | 29.97 |  2649
 V6_BBrel_Orig_BB | KTLH     |      3 | 28.23 | 30.16 |  214 | 23.96 |  26.9 |   983 | 24.72 | 27.48 |  1197
 V6_BBrel_Orig_BB | KTLH     |    4.5 | 28.49 | 30.37 |   61 | 22.76 | 25.47 |   267 | 23.82 | 26.38 |   328
(133 rows)
