-- get a common set of samples between original and S2Ku
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

select 'V6BBrelKuNoBB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

   ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns  |  pr   |  gv   |  n   
---------------+----------+--------+-------+-------+------+-------+-------+------+-------+-------+------
 V6BBrelKuNoBB | KAMX     |     -3 | 39.75 |  43.8 |  270 | 33.07 | 35.19 | 1080 | 34.41 | 36.91 | 1350
 V6BBrelKuNoBB | KAMX     |   -1.5 | 40.02 |  43.4 |  603 | 32.15 | 33.94 | 1538 | 34.37 |  36.6 | 2141
 V6BBrelKuNoBB | KAMX     |    1.5 | 32.53 | 32.38 |  190 | 24.19 | 24.91 |  301 | 27.42 |  27.8 |  491
 V6BBrelKuNoBB | KAMX     |      3 | 30.34 | 30.36 |  178 |  23.2 | 24.38 |  195 | 26.61 | 27.23 |  373
 V6BBrelKuNoBB | KAMX     |    4.5 | 28.24 |    29 |   66 | 21.77 | 22.86 |   15 | 27.04 | 27.86 |   81
 V6BBrelKuNoBB | KBMX     |     -3 | 38.85 | 43.72 |   80 | 30.91 | 33.09 |  238 | 32.91 | 35.77 |  318
 V6BBrelKuNoBB | KBMX     |   -1.5 | 41.88 | 44.46 |  458 | 30.81 | 32.57 | 1443 | 33.48 | 35.43 | 1901
 V6BBrelKuNoBB | KBMX     |    1.5 | 34.47 | 34.49 |  811 | 24.91 | 26.25 | 2036 | 27.64 |  28.6 | 2847
 V6BBrelKuNoBB | KBMX     |      3 |  33.7 | 34.13 |  862 | 24.29 | 25.75 | 1523 | 27.69 | 28.78 | 2385
 V6BBrelKuNoBB | KBMX     |    4.5 |  33.3 | 34.09 |  460 | 23.27 | 24.79 |  499 | 28.08 | 29.25 |  959
 V6BBrelKuNoBB | KBMX     |      6 | 33.16 | 34.23 |  249 | 22.75 | 24.91 |   65 | 31.01 |  32.3 |  314
 V6BBrelKuNoBB | KBRO     |     -3 | 38.98 | 42.97 |   48 | 28.56 |  30.5 |  348 | 29.82 | 32.01 |  396
 V6BBrelKuNoBB | KBRO     |   -1.5 | 39.74 |  44.4 |  119 | 28.52 | 30.77 |  899 | 29.83 | 32.36 | 1018
 V6BBrelKuNoBB | KBRO     |    1.5 | 34.59 | 36.05 |   97 | 23.85 | 25.74 |  224 | 27.09 | 28.85 |  321
 V6BBrelKuNoBB | KBRO     |      3 | 33.55 | 34.46 |  200 | 23.61 | 25.65 |  185 | 28.77 | 30.22 |  385
 V6BBrelKuNoBB | KBRO     |    4.5 | 31.63 | 32.57 |  102 | 23.32 | 25.77 |   70 | 28.25 |  29.8 |  172
 V6BBrelKuNoBB | KBYX     |     -3 | 40.16 | 43.26 |  239 | 30.66 | 31.88 | 1525 | 31.95 | 33.43 | 1764
 V6BBrelKuNoBB | KBYX     |   -1.5 | 39.85 | 42.84 |  329 | 30.78 | 31.92 | 1763 |  32.2 | 33.64 | 2092
 V6BBrelKuNoBB | KBYX     |    1.5 |  33.8 | 32.47 |   64 | 24.09 | 24.11 |  150 |    27 | 26.61 |  214
 V6BBrelKuNoBB | KBYX     |      3 | 29.72 | 29.43 |   38 | 23.17 | 23.42 |   74 | 25.39 | 25.46 |  112
 V6BBrelKuNoBB | KBYX     |    4.5 | 31.17 |  28.1 |    5 |  23.4 | 23.47 |    5 | 27.29 | 25.78 |   10
 V6BBrelKuNoBB | KCLX     |     -3 | 41.49 | 44.49 |   35 | 29.59 | 30.82 |  235 | 31.14 | 32.59 |  270
 V6BBrelKuNoBB | KCLX     |   -1.5 | 40.11 | 41.81 |  475 | 31.09 | 32.58 | 2845 | 32.38 |  33.9 | 3320
 V6BBrelKuNoBB | KCLX     |    1.5 | 30.16 | 30.32 |  470 | 25.01 | 25.99 | 2057 | 25.97 |  26.8 | 2527
 V6BBrelKuNoBB | KCLX     |      3 | 27.32 | 27.63 |  476 | 23.78 | 24.57 | 1393 | 24.68 | 25.35 | 1869
 V6BBrelKuNoBB | KCLX     |    4.5 | 26.93 | 27.32 |  128 | 22.77 | 23.73 |  266 | 24.12 |  24.9 |  394
 V6BBrelKuNoBB | KCLX     |      6 | 28.37 | 28.97 |   29 | 22.98 | 24.39 |   21 | 26.11 | 27.05 |   50
 V6BBrelKuNoBB | KCRP     |     -3 | 39.37 | 44.08 |   83 | 29.93 | 31.42 |  358 |  31.7 |  33.8 |  441
 V6BBrelKuNoBB | KCRP     |   -1.5 | 39.09 | 42.43 |  177 | 30.08 | 31.15 |  682 | 31.94 | 33.47 |  859
 V6BBrelKuNoBB | KCRP     |    1.5 | 31.12 | 27.74 |   17 |    24 | 24.52 |  168 | 24.65 | 24.82 |  185
 V6BBrelKuNoBB | KDGX     |     -3 | 38.57 | 41.82 |  183 | 29.23 | 31.43 | 1941 | 30.03 | 32.33 | 2124
 V6BBrelKuNoBB | KDGX     |   -1.5 | 40.02 | 42.99 |  749 | 29.57 | 31.66 | 3142 | 31.58 | 33.84 | 3891
 V6BBrelKuNoBB | KDGX     |    1.5 | 31.35 | 31.65 |  419 | 25.23 | 26.01 | 1778 |  26.4 | 27.08 | 2197
 V6BBrelKuNoBB | KDGX     |      3 | 29.48 | 29.88 |  349 | 24.11 | 24.98 | 1059 | 25.44 |  26.2 | 1408
 V6BBrelKuNoBB | KDGX     |    4.5 |  27.7 | 28.17 |  141 | 23.24 |  24.2 |  107 | 25.77 | 26.46 |  248
 V6BBrelKuNoBB | KEVX     |     -3 | 41.84 | 44.44 |   37 |  32.8 | 31.95 |   86 | 35.52 | 35.71 |  123
 V6BBrelKuNoBB | KEVX     |   -1.5 | 41.76 | 42.89 | 1014 | 33.08 | 33.06 | 2066 | 35.94 |  36.3 | 3080
 V6BBrelKuNoBB | KEVX     |    1.5 | 32.41 | 31.41 |  618 | 25.42 | 25.31 | 1001 | 28.09 | 27.64 | 1619
 V6BBrelKuNoBB | KEVX     |      3 | 29.57 | 29.14 |  481 | 23.81 | 24.01 |  513 |  26.6 | 26.49 |  994
 V6BBrelKuNoBB | KEVX     |    4.5 |  29.3 | 29.75 |  110 | 23.05 | 23.06 |   67 | 26.93 | 27.22 |  177
 V6BBrelKuNoBB | KFWS     |     -3 | 42.67 | 44.31 |   52 | 29.36 | 29.28 |  149 | 32.81 | 33.17 |  201
 V6BBrelKuNoBB | KFWS     |   -1.5 | 41.04 | 42.16 |  355 | 29.33 | 29.22 |  892 | 32.67 |  32.9 | 1247
 V6BBrelKuNoBB | KFWS     |    1.5 | 34.26 | 33.76 |  380 | 24.61 | 25.28 |  867 | 27.55 | 27.86 | 1247
 V6BBrelKuNoBB | KFWS     |      3 | 31.24 | 31.08 |  406 | 23.79 |  24.6 |  978 | 25.98 |  26.5 | 1384
 V6BBrelKuNoBB | KFWS     |    4.5 | 29.26 | 29.48 |  231 | 22.51 | 23.34 |  205 | 26.09 | 26.59 |  436
 V6BBrelKuNoBB | KFWS     |      6 | 28.49 | 27.39 |   57 | 21.44 | 21.99 |    9 | 27.53 | 26.66 |   66
 V6BBrelKuNoBB | KGRK     |     -3 | 37.91 | 42.71 |   14 | 30.24 | 30.03 |   10 | 34.71 | 37.43 |   24
 V6BBrelKuNoBB | KGRK     |   -1.5 | 41.08 | 41.13 |  175 | 30.79 | 30.81 |  112 | 37.06 |  37.1 |  287
 V6BBrelKuNoBB | KGRK     |    1.5 | 35.84 | 34.68 |  162 | 24.82 | 25.09 |  143 | 30.67 | 30.18 |  305
 V6BBrelKuNoBB | KGRK     |      3 | 33.26 | 32.59 |  218 | 24.22 | 23.86 |  382 |  27.5 | 27.03 |  600
 V6BBrelKuNoBB | KGRK     |    4.5 | 33.47 | 32.87 |  107 | 23.26 | 22.82 |  141 | 27.66 | 27.15 |  248
 V6BBrelKuNoBB | KGRK     |      6 | 34.33 | 33.95 |   57 | 22.36 | 22.12 |   16 | 31.71 | 31.36 |   73
 V6BBrelKuNoBB | KHGX     |     -3 | 39.08 | 39.75 |  124 | 35.03 | 35.21 |  959 | 35.49 | 35.73 | 1083
 V6BBrelKuNoBB | KHGX     |   -1.5 | 41.09 | 42.48 |  392 | 33.57 | 33.66 | 1220 |  35.4 |  35.8 | 1612
 V6BBrelKuNoBB | KHGX     |    1.5 | 33.47 | 32.18 |  251 | 25.17 | 25.85 |  990 | 26.85 | 27.13 | 1241
 V6BBrelKuNoBB | KHGX     |      3 | 30.53 | 29.62 |  273 | 24.19 | 24.75 |  608 | 26.15 | 26.26 |  881
 V6BBrelKuNoBB | KHGX     |    4.5 | 28.91 | 28.28 |   97 | 23.25 | 23.74 |   66 | 26.62 | 26.44 |  163
 V6BBrelKuNoBB | KHGX     |      6 | 28.64 | 28.79 |   27 | 24.52 | 24.35 |    6 | 27.89 | 27.99 |   33
 V6BBrelKuNoBB | KHTX     |     -3 | 41.27 |  45.4 |   11 | 31.45 | 31.66 |   90 | 32.52 | 33.15 |  101
 V6BBrelKuNoBB | KHTX     |   -1.5 |    41 | 43.23 |  485 | 31.01 | 31.56 | 2706 | 32.53 | 33.34 | 3191
 V6BBrelKuNoBB | KHTX     |    1.5 | 34.43 |  33.6 |  786 | 25.44 | 26.16 | 3211 | 27.21 | 27.62 | 3997
 V6BBrelKuNoBB | KHTX     |      3 |  31.6 | 31.18 |  912 | 24.43 | 25.37 | 2508 | 26.34 | 26.92 | 3420
 V6BBrelKuNoBB | KHTX     |    4.5 | 29.79 | 30.09 |  444 | 22.96 | 24.17 |  704 |  25.6 | 26.46 | 1148
 V6BBrelKuNoBB | KHTX     |      6 | 30.27 | 31.23 |  105 | 22.87 | 24.09 |   39 | 28.27 |  29.3 |  144
 V6BBrelKuNoBB | KJAX     |     -3 | 41.13 | 42.63 |  115 | 33.02 |  33.3 |  309 | 35.22 | 35.83 |  424
 V6BBrelKuNoBB | KJAX     |   -1.5 | 40.69 | 42.45 |  737 | 32.38 | 33.23 | 2894 | 34.06 |  35.1 | 3631
 V6BBrelKuNoBB | KJAX     |    1.5 |  31.5 | 32.73 |  528 |  24.7 | 27.12 | 1434 | 26.53 | 28.63 | 1962
 V6BBrelKuNoBB | KJAX     |      3 | 28.49 | 29.46 |  485 | 23.75 | 24.88 |  678 | 25.72 | 26.79 | 1163
 V6BBrelKuNoBB | KJAX     |    4.5 | 27.59 | 28.91 |  175 | 22.68 | 24.05 |  141 |  25.4 | 26.74 |  316
 V6BBrelKuNoBB | KJAX     |      6 | 30.21 | 32.32 |   50 | 23.78 | 24.66 |    5 | 29.63 | 31.63 |   55
 V6BBrelKuNoBB | KJGX     |     -3 | 43.54 |  47.2 |   54 | 31.35 |  31.9 |   38 |  38.5 | 40.88 |   92
 V6BBrelKuNoBB | KJGX     |   -1.5 |  40.7 | 41.98 |  392 | 34.34 | 34.35 | 2725 | 35.14 | 35.31 | 3117
 V6BBrelKuNoBB | KJGX     |    1.5 | 32.41 | 31.66 |  452 | 25.51 | 25.73 | 2378 | 26.62 | 26.68 | 2830
 V6BBrelKuNoBB | KJGX     |      3 | 30.27 | 30.35 |  378 | 23.99 | 24.01 |  810 | 25.99 | 26.03 | 1188
 V6BBrelKuNoBB | KJGX     |    4.5 | 30.47 | 30.97 |  129 |  23.7 |  24.4 |   50 | 28.58 | 29.14 |  179
 V6BBrelKuNoBB | KLCH     |     -3 | 38.83 | 43.32 |  116 | 30.45 | 32.28 |  258 | 33.05 | 35.71 |  374
 V6BBrelKuNoBB | KLCH     |   -1.5 | 41.44 | 44.21 |  294 | 29.73 | 31.61 |  632 | 33.45 | 35.61 |  926
 V6BBrelKuNoBB | KLCH     |    1.5 | 31.62 | 31.57 |  354 |  24.7 |  25.9 |  927 | 26.61 | 27.46 | 1281
 V6BBrelKuNoBB | KLCH     |      3 | 29.09 | 29.96 |  437 | 23.82 | 25.17 |  641 | 25.96 | 27.11 | 1078
 V6BBrelKuNoBB | KLCH     |    4.5 | 28.59 | 29.96 |  178 | 22.43 | 23.96 |   94 | 26.46 | 27.89 |  272
 V6BBrelKuNoBB | KLIX     |     -3 | 41.68 | 45.71 |  220 | 30.97 | 33.08 |  286 | 35.63 | 38.57 |  506
 V6BBrelKuNoBB | KLIX     |   -1.5 | 42.82 | 45.97 |  613 | 31.18 | 33.68 | 1488 | 34.57 | 37.27 | 2101
 V6BBrelKuNoBB | KLIX     |    1.5 | 34.36 | 34.41 |  423 | 24.88 | 26.16 | 1838 | 26.65 |  27.7 | 2261
 V6BBrelKuNoBB | KLIX     |      3 | 30.11 | 30.33 |  409 | 23.36 | 25.09 | 1503 | 24.81 | 26.21 | 1912
 V6BBrelKuNoBB | KLIX     |    4.5 | 28.78 | 29.26 |  170 | 22.37 | 24.61 |  337 | 24.52 | 26.17 |  507
 V6BBrelKuNoBB | KLIX     |      6 | 32.01 | 31.38 |   30 | 20.88 | 23.14 |   25 | 26.96 | 27.63 |   55
 V6BBrelKuNoBB | KMLB     |     -3 | 41.47 | 40.86 |  129 | 31.03 | 28.88 |  515 | 33.12 | 31.28 |  644
 V6BBrelKuNoBB | KMLB     |   -1.5 | 41.32 | 41.32 |  481 | 32.08 | 30.72 |  811 | 35.52 | 34.67 | 1292
 V6BBrelKuNoBB | KMLB     |    1.5 | 32.84 | 30.55 |  188 | 24.78 | 24.22 |  393 | 27.39 | 26.26 |  581
 V6BBrelKuNoBB | KMLB     |      3 | 31.08 | 29.78 |  196 | 23.76 | 23.07 |  311 | 26.59 | 25.66 |  507
 V6BBrelKuNoBB | KMLB     |    4.5 | 29.97 | 29.35 |   87 | 23.03 | 22.61 |   30 | 28.19 | 27.62 |  117
 V6BBrelKuNoBB | KMOB     |     -3 | 39.43 | 43.73 |  179 |  31.6 | 33.68 |  207 | 35.23 | 38.34 |  386
 V6BBrelKuNoBB | KMOB     |   -1.5 | 40.31 | 42.07 |  486 | 30.69 | 31.59 | 1285 | 33.33 | 34.47 | 1771
 V6BBrelKuNoBB | KMOB     |    1.5 | 32.32 | 28.57 |  361 | 24.72 | 24.31 | 1230 | 26.44 | 25.27 | 1591
 V6BBrelKuNoBB | KMOB     |      3 | 29.74 | 26.32 |  295 | 23.59 | 22.91 |  635 | 25.54 | 23.99 |  930
 V6BBrelKuNoBB | KMOB     |    4.5 |  33.2 | 30.26 |   75 |  23.1 | 22.47 |   37 | 29.86 | 27.69 |  112
 V6BBrelKuNoBB | KSHV     |     -3 | 44.67 | 49.85 |   16 | 29.22 | 31.95 |  285 | 30.04 |  32.9 |  301
 V6BBrelKuNoBB | KSHV     |   -1.5 | 43.05 | 46.18 |  448 | 29.28 | 31.53 |  904 | 33.85 | 36.39 | 1352
 V6BBrelKuNoBB | KSHV     |    1.5 | 34.02 | 34.03 |  579 | 24.72 | 26.24 |  993 | 28.15 | 29.11 | 1572
 V6BBrelKuNoBB | KSHV     |      3 | 31.08 | 31.51 |  758 | 23.51 | 25.38 |  955 | 26.86 | 28.09 | 1713
 V6BBrelKuNoBB | KSHV     |    4.5 | 29.34 | 29.97 |  468 | 22.38 | 24.24 |  396 | 26.15 | 27.34 |  864
 V6BBrelKuNoBB | KSHV     |      6 | 30.66 | 31.49 |  170 | 20.56 | 23.03 |    6 | 30.31 |  31.2 |  176
 V6BBrelKuNoBB | KTBW     |     -3 | 41.51 | 44.36 |  218 | 31.13 | 32.86 |  562 | 34.03 | 36.08 |  780
 V6BBrelKuNoBB | KTBW     |   -1.5 | 41.19 | 43.93 |  445 | 30.37 | 31.99 | 1403 | 32.98 | 34.87 | 1848
 V6BBrelKuNoBB | KTBW     |    1.5 | 32.32 | 31.77 |  231 | 24.41 | 25.77 |  624 | 26.55 | 27.39 |  855
 V6BBrelKuNoBB | KTBW     |      3 | 30.62 | 30.04 |  228 | 22.89 | 23.91 |  372 | 25.83 | 26.24 |  600
 V6BBrelKuNoBB | KTBW     |    4.5 | 29.51 | 29.41 |  108 | 21.84 | 22.48 |   20 | 28.31 | 28.32 |  128
 V6BBrelKuNoBB | KTLH     |     -3 | 42.09 | 48.64 |    6 | 27.79 |  31.7 |   54 | 29.22 | 33.39 |   60
 V6BBrelKuNoBB | KTLH     |   -1.5 | 39.53 |  42.7 |  389 | 31.33 | 34.77 | 1765 | 32.81 |  36.2 | 2154
 V6BBrelKuNoBB | KTLH     |    1.5 | 29.31 | 30.15 |  182 | 24.82 | 26.95 |  989 | 25.52 | 27.45 | 1171
 V6BBrelKuNoBB | KTLH     |      3 | 28.23 | 28.96 |  214 | 23.96 | 26.07 |  983 | 24.72 | 26.59 | 1197
 V6BBrelKuNoBB | KTLH     |    4.5 | 28.49 | 29.16 |   61 | 22.76 | 24.78 |  267 | 23.82 | 25.59 |  328
(112 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b  where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.radar_id, a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel a, commontemp d where a.regime in ('C_in', 'C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1,2 order by 1,2;

select b.radar_id, b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp d where b.regime in ('S_in', 'S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1,2 order by 1,2;

select c.radar_id, c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1,2 order by 1,2;

select 'V6_BBrel_Ku_BB', a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height and a.radar_id=b.radar_id and a.radar_id=c.radar_id;

    ?column?    | radar_id | height |  prc  |  gvc  |  nc  |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
----------------+----------+--------+-------+-------+------+-------+-------+-------+-------+-------+-------
 V6_BBrel_Ku_BB | KAMX     |     -3 | 39.75 |  43.8 |  270 | 33.07 | 35.19 |  1080 | 34.41 | 36.91 |  1350
 V6_BBrel_Ku_BB | KAMX     |   -1.5 | 39.89 |  42.6 | 1002 | 32.22 | 33.48 |  2552 | 34.38 | 36.05 |  3554
 V6_BBrel_Ku_BB | KAMX     |      0 | 38.21 | 40.25 |  860 | 31.81 |  34.1 |  2037 | 33.71 | 35.93 |  2897
 V6_BBrel_Ku_BB | KAMX     |    1.5 | 32.95 | 33.91 |  390 | 25.93 | 27.43 |   795 | 28.24 | 29.56 |  1185
 V6_BBrel_Ku_BB | KAMX     |      3 | 30.34 | 30.36 |  178 |  23.2 | 24.38 |   195 | 26.61 | 27.23 |   373
 V6_BBrel_Ku_BB | KAMX     |    4.5 | 28.24 |    29 |   66 | 21.77 | 22.86 |    15 | 27.04 | 27.86 |    81
 V6_BBrel_Ku_BB | KBMX     |     -3 | 38.85 | 43.72 |   80 | 30.91 | 33.09 |   238 | 32.91 | 35.77 |   318
 V6_BBrel_Ku_BB | KBMX     |   -1.5 | 41.22 | 42.87 | 1180 | 30.93 | 31.93 |  3660 | 33.44 |  34.6 |  4840
 V6_BBrel_Ku_BB | KBMX     |      0 | 39.87 | 42.19 | 2498 | 30.28 | 33.21 | 10703 |  32.1 | 34.91 | 13201
 V6_BBrel_Ku_BB | KBMX     |    1.5 | 35.28 | 36.12 | 1509 | 25.94 |  27.8 |  4382 | 28.33 | 29.93 |  5891
 V6_BBrel_Ku_BB | KBMX     |      3 |  33.7 | 34.13 |  862 | 24.29 | 25.75 |  1523 | 27.69 | 28.78 |  2385
 V6_BBrel_Ku_BB | KBMX     |    4.5 |  33.3 | 34.09 |  460 | 23.27 | 24.79 |   499 | 28.08 | 29.25 |   959
 V6_BBrel_Ku_BB | KBMX     |      6 | 33.16 | 34.23 |  249 | 22.75 | 24.91 |    65 | 31.01 |  32.3 |   314
 V6_BBrel_Ku_BB | KBRO     |     -3 | 38.98 | 42.97 |   48 | 28.56 |  30.5 |   348 | 29.82 | 32.01 |   396
 V6_BBrel_Ku_BB | KBRO     |   -1.5 | 39.56 | 43.51 |  235 | 28.83 | 30.55 |  1664 | 30.16 | 32.16 |  1899
 V6_BBrel_Ku_BB | KBRO     |      0 | 38.51 | 41.15 |  285 | 29.73 | 32.92 |  1590 | 31.07 | 34.17 |  1875
 V6_BBrel_Ku_BB | KBRO     |    1.5 | 35.89 | 38.11 |  212 | 25.43 |  27.7 |   513 | 28.49 | 30.74 |   725
 V6_BBrel_Ku_BB | KBRO     |      3 | 33.55 | 34.46 |  200 | 23.61 | 25.65 |   185 | 28.77 | 30.22 |   385
 V6_BBrel_Ku_BB | KBRO     |    4.5 | 31.63 | 32.57 |  102 | 23.32 | 25.77 |    70 | 28.25 |  29.8 |   172
 V6_BBrel_Ku_BB | KBYX     |     -3 | 40.16 | 43.26 |  239 | 30.66 | 31.88 |  1525 | 31.95 | 33.43 |  1764
 V6_BBrel_Ku_BB | KBYX     |   -1.5 | 39.56 | 41.98 |  517 | 31.01 | 31.79 |  3017 | 32.26 | 33.28 |  3534
 V6_BBrel_Ku_BB | KBYX     |      0 | 37.72 | 39.24 |  379 | 31.28 | 33.22 |  2330 | 32.18 | 34.06 |  2709
 V6_BBrel_Ku_BB | KBYX     |    1.5 | 33.44 | 33.13 |  150 | 26.21 |  26.5 |   569 | 27.72 | 27.88 |   719
 V6_BBrel_Ku_BB | KBYX     |      3 | 29.72 | 29.43 |   38 | 23.17 | 23.42 |    74 | 25.39 | 25.46 |   112
 V6_BBrel_Ku_BB | KBYX     |    4.5 | 31.17 |  28.1 |    5 |  23.4 | 23.47 |     5 | 27.29 | 25.78 |    10
 V6_BBrel_Ku_BB | KCLX     |     -3 | 41.49 | 44.49 |   35 | 29.59 | 30.82 |   235 | 31.14 | 32.59 |   270
 V6_BBrel_Ku_BB | KCLX     |   -1.5 | 39.87 | 40.94 |  917 | 31.08 | 32.16 |  5107 | 32.42 | 33.49 |  6024
 V6_BBrel_Ku_BB | KCLX     |      0 | 38.22 | 40.19 | 1488 | 31.61 | 34.34 |  7675 | 32.68 | 35.29 |  9163
 V6_BBrel_Ku_BB | KCLX     |    1.5 | 31.83 | 32.89 |  799 | 26.14 | 28.32 |  3933 |  27.1 | 29.09 |  4732
 V6_BBrel_Ku_BB | KCLX     |      3 | 27.32 | 27.63 |  476 | 23.78 | 24.57 |  1393 | 24.68 | 25.35 |  1869
 V6_BBrel_Ku_BB | KCLX     |    4.5 | 26.93 | 27.32 |  128 | 22.77 | 23.73 |   266 | 24.12 |  24.9 |   394
 V6_BBrel_Ku_BB | KCLX     |      6 | 28.37 | 28.97 |   29 | 22.98 | 24.39 |    21 | 26.11 | 27.05 |    50
 V6_BBrel_Ku_BB | KCRP     |     -3 | 39.37 | 44.08 |   83 | 29.93 | 31.42 |   358 |  31.7 |  33.8 |   441
 V6_BBrel_Ku_BB | KCRP     |   -1.5 | 38.92 | 41.34 |  249 |    30 | 30.48 |  1311 | 31.42 | 32.21 |  1560
 V6_BBrel_Ku_BB | KCRP     |      0 | 36.78 | 37.88 |  182 | 29.76 | 31.88 |  1308 | 30.62 | 32.61 |  1490
 V6_BBrel_Ku_BB | KCRP     |    1.5 |    31 | 30.33 |   50 | 25.26 | 26.43 |   410 | 25.88 | 26.86 |   460
 V6_BBrel_Ku_BB | KDGX     |     -3 | 38.57 | 41.82 |  183 | 29.23 | 31.43 |  1941 | 30.03 | 32.33 |  2124
 V6_BBrel_Ku_BB | KDGX     |   -1.5 | 39.93 | 41.99 | 1302 | 29.94 | 31.47 |  5318 |  31.9 | 33.54 |  6620
 V6_BBrel_Ku_BB | KDGX     |      0 | 38.29 | 40.38 | 1530 | 30.52 | 33.19 |  9461 |  31.6 | 34.19 | 10991
 V6_BBrel_Ku_BB | KDGX     |    1.5 |  32.8 | 33.54 |  784 | 26.25 | 27.52 |  3941 | 27.33 | 28.52 |  4725
 V6_BBrel_Ku_BB | KDGX     |      3 | 29.48 | 29.88 |  349 | 24.11 | 24.98 |  1059 | 25.44 |  26.2 |  1408
 V6_BBrel_Ku_BB | KDGX     |    4.5 |  27.7 | 28.17 |  141 | 23.24 |  24.2 |   107 | 25.77 | 26.46 |   248
 V6_BBrel_Ku_BB | KEVX     |     -3 | 41.84 | 44.44 |   37 |  32.8 | 31.95 |    86 | 35.52 | 35.71 |   123
 V6_BBrel_Ku_BB | KEVX     |   -1.5 | 41.54 | 42.01 | 1854 | 33.05 | 32.43 |  3973 | 35.75 | 35.48 |  5827
 V6_BBrel_Ku_BB | KEVX     |      0 | 39.39 | 39.68 | 2110 | 32.59 |  33.5 |  5104 | 34.58 | 35.31 |  7214
 V6_BBrel_Ku_BB | KEVX     |    1.5 | 33.46 | 33.24 | 1120 | 26.81 | 27.55 |  2020 | 29.18 | 29.58 |  3140
 V6_BBrel_Ku_BB | KEVX     |      3 | 29.57 | 29.14 |  481 | 23.81 | 24.01 |   513 |  26.6 | 26.49 |   994
 V6_BBrel_Ku_BB | KEVX     |    4.5 |  29.3 | 29.75 |  110 | 23.05 | 23.06 |    67 | 26.93 | 27.22 |   177
 V6_BBrel_Ku_BB | KFWS     |     -3 | 42.67 | 44.31 |   52 | 29.36 | 29.28 |   149 | 32.81 | 33.17 |   201
 V6_BBrel_Ku_BB | KFWS     |   -1.5 | 40.38 | 40.92 |  619 | 29.34 | 28.93 |  1658 | 32.34 | 32.19 |  2277
 V6_BBrel_Ku_BB | KFWS     |      0 | 38.56 | 39.25 | 1106 | 28.96 | 30.69 |  3889 | 31.08 | 32.58 |  4995
 V6_BBrel_Ku_BB | KFWS     |    1.5 | 35.24 | 35.26 |  684 | 25.42 | 26.69 |  1737 | 28.19 | 29.11 |  2421
 V6_BBrel_Ku_BB | KFWS     |      3 | 31.24 | 31.08 |  406 | 23.79 |  24.6 |   978 | 25.98 |  26.5 |  1384
 V6_BBrel_Ku_BB | KFWS     |    4.5 | 29.26 | 29.48 |  231 | 22.51 | 23.34 |   205 | 26.09 | 26.59 |   436
 V6_BBrel_Ku_BB | KFWS     |      6 | 28.49 | 27.39 |   57 | 21.44 | 21.99 |     9 | 27.53 | 26.66 |    66
 V6_BBrel_Ku_BB | KGRK     |     -3 | 37.91 | 42.71 |   14 | 30.24 | 30.03 |    10 | 34.71 | 37.43 |    24
 V6_BBrel_Ku_BB | KGRK     |   -1.5 | 41.46 | 41.17 |  257 | 30.94 | 30.48 |   167 | 37.31 | 36.96 |   424
 V6_BBrel_Ku_BB | KGRK     |      0 | 40.55 | 40.38 |  401 | 29.32 |  30.8 |   480 | 34.43 | 35.16 |   881
 V6_BBrel_Ku_BB | KGRK     |    1.5 | 36.42 | 36.37 |  285 |  25.9 | 27.11 |   319 | 30.87 | 31.48 |   604
 V6_BBrel_Ku_BB | KGRK     |      3 | 33.26 | 32.59 |  218 | 24.22 | 23.86 |   382 |  27.5 | 27.03 |   600
 V6_BBrel_Ku_BB | KGRK     |    4.5 | 33.47 | 32.87 |  107 | 23.26 | 22.82 |   141 | 27.66 | 27.15 |   248
 V6_BBrel_Ku_BB | KGRK     |      6 | 34.33 | 33.95 |   57 | 22.36 | 22.12 |    16 | 31.71 | 31.36 |    73
 V6_BBrel_Ku_BB | KHGX     |     -3 | 39.08 | 39.75 |  124 | 35.03 | 35.21 |   959 | 35.49 | 35.73 |  1083
 V6_BBrel_Ku_BB | KHGX     |   -1.5 | 40.93 | 41.64 |  740 |  33.3 | 32.88 |  2131 | 35.27 | 35.14 |  2871
 V6_BBrel_Ku_BB | KHGX     |      0 | 39.59 | 40.47 |  830 | 32.28 | 33.94 |  2813 | 33.94 | 35.43 |  3643
 V6_BBrel_Ku_BB | KHGX     |    1.5 | 34.87 | 34.42 |  473 | 26.23 |  27.3 |  1721 | 28.09 | 28.83 |  2194
 V6_BBrel_Ku_BB | KHGX     |      3 | 30.53 | 29.62 |  273 | 24.19 | 24.75 |   608 | 26.15 | 26.26 |   881
 V6_BBrel_Ku_BB | KHGX     |    4.5 | 28.91 | 28.28 |   97 | 23.25 | 23.74 |    66 | 26.62 | 26.44 |   163
 V6_BBrel_Ku_BB | KHGX     |      6 | 28.64 | 28.79 |   27 | 24.52 | 24.35 |     6 | 27.89 | 27.99 |    33
 V6_BBrel_Ku_BB | KHTX     |     -3 | 41.27 |  45.4 |   11 | 31.45 | 31.66 |    90 | 32.52 | 33.15 |   101
 V6_BBrel_Ku_BB | KHTX     |   -1.5 | 41.26 | 42.52 | 1062 |  31.2 | 31.25 |  5726 | 32.77 | 33.02 |  6788
 V6_BBrel_Ku_BB | KHTX     |      0 |  38.9 | 40.02 | 2568 |  31.4 | 33.74 | 17315 | 32.37 | 34.55 | 19883
 V6_BBrel_Ku_BB | KHTX     |    1.5 |  35.1 |  34.9 | 1453 | 26.34 | 27.72 |  6826 | 27.88 | 28.98 |  8279
 V6_BBrel_Ku_BB | KHTX     |      3 |  31.6 | 31.18 |  912 | 24.43 | 25.37 |  2508 | 26.34 | 26.92 |  3420
 V6_BBrel_Ku_BB | KHTX     |    4.5 | 29.79 | 30.09 |  444 | 22.96 | 24.17 |   704 |  25.6 | 26.46 |  1148
 V6_BBrel_Ku_BB | KHTX     |      6 | 30.27 | 31.23 |  105 | 22.87 | 24.09 |    39 | 28.27 |  29.3 |   144
 V6_BBrel_Ku_BB | KJAX     |     -3 | 41.13 | 42.63 |  115 | 33.02 |  33.3 |   309 | 35.22 | 35.83 |   424
 V6_BBrel_Ku_BB | KJAX     |   -1.5 | 40.87 | 42.17 | 1486 | 32.13 | 32.63 |  4993 | 34.14 | 34.82 |  6479
 V6_BBrel_Ku_BB | KJAX     |      0 | 38.88 | 40.78 | 1758 | 31.79 |  33.5 |  6004 |  33.4 | 35.15 |  7762
 V6_BBrel_Ku_BB | KJAX     |    1.5 | 32.69 | 35.41 |  986 | 25.74 | 30.08 |  2760 | 27.57 | 31.48 |  3746
 V6_BBrel_Ku_BB | KJAX     |      3 | 28.49 | 29.46 |  485 | 23.75 | 24.88 |   678 | 25.72 | 26.79 |  1163
 V6_BBrel_Ku_BB | KJAX     |    4.5 | 27.59 | 28.91 |  175 | 22.68 | 24.05 |   141 |  25.4 | 26.74 |   316
 V6_BBrel_Ku_BB | KJAX     |      6 | 30.21 | 32.32 |   50 | 23.78 | 24.66 |     5 | 29.63 | 31.63 |    55
 V6_BBrel_Ku_BB | KJGX     |     -3 | 43.54 |  47.2 |   54 | 31.35 |  31.9 |    38 |  38.5 | 40.88 |    92
 V6_BBrel_Ku_BB | KJGX     |   -1.5 | 40.92 | 41.39 |  910 | 33.98 | 33.54 |  5750 | 34.93 | 34.61 |  6660
 V6_BBrel_Ku_BB | KJGX     |      0 | 39.75 | 41.01 | 1581 | 33.07 | 34.91 | 10282 | 33.96 | 35.72 | 11863
 V6_BBrel_Ku_BB | KJGX     |    1.5 | 33.56 | 33.64 |  886 |  26.9 | 28.09 |  5108 | 27.88 | 28.91 |  5994
 V6_BBrel_Ku_BB | KJGX     |      3 | 30.27 | 30.35 |  378 | 23.99 | 24.01 |   810 | 25.99 | 26.03 |  1188
 V6_BBrel_Ku_BB | KJGX     |    4.5 | 30.47 | 30.97 |  129 |  23.7 |  24.4 |    50 | 28.58 | 29.14 |   179
 V6_BBrel_Ku_BB | KLCH     |     -3 | 38.83 | 43.32 |  116 | 30.45 | 32.28 |   258 | 33.05 | 35.71 |   374
 V6_BBrel_Ku_BB | KLCH     |   -1.5 | 41.43 | 43.57 |  465 | 30.53 | 31.64 |  1285 | 33.43 | 34.81 |  1750
 V6_BBrel_Ku_BB | KLCH     |      0 | 40.12 | 43.25 |  742 | 32.97 | 36.47 |  2838 | 34.45 | 37.87 |  3580
 V6_BBrel_Ku_BB | KLCH     |    1.5 | 33.35 | 34.21 |  618 | 26.29 | 28.24 |  1771 | 28.12 | 29.79 |  2389
 V6_BBrel_Ku_BB | KLCH     |      3 | 29.09 | 29.96 |  437 | 23.82 | 25.17 |   641 | 25.96 | 27.11 |  1078
 V6_BBrel_Ku_BB | KLCH     |    4.5 | 28.59 | 29.96 |  178 | 22.43 | 23.96 |    94 | 26.46 | 27.89 |   272
 V6_BBrel_Ku_BB | KLIX     |     -3 | 41.68 | 45.71 |  220 | 30.97 | 33.08 |   286 | 35.63 | 38.57 |   506
 V6_BBrel_Ku_BB | KLIX     |   -1.5 | 41.98 | 44.68 |  941 | 31.16 | 33.15 |  2494 | 34.12 | 36.31 |  3435
 V6_BBrel_Ku_BB | KLIX     |      0 | 40.15 | 42.51 | 1076 | 31.42 | 35.08 |  4175 | 33.21 |  36.6 |  5251
 V6_BBrel_Ku_BB | KLIX     |    1.5 | 34.94 | 35.55 |  621 | 26.01 | 27.62 |  3155 | 27.48 | 28.93 |  3776
 V6_BBrel_Ku_BB | KLIX     |      3 | 30.11 | 30.33 |  409 | 23.36 | 25.09 |  1503 | 24.81 | 26.21 |  1912
 V6_BBrel_Ku_BB | KLIX     |    4.5 | 28.78 | 29.26 |  170 | 22.37 | 24.61 |   337 | 24.52 | 26.17 |   507
 V6_BBrel_Ku_BB | KLIX     |      6 | 32.01 | 31.38 |   30 | 20.88 | 23.14 |    25 | 26.96 | 27.63 |    55
 V6_BBrel_Ku_BB | KMLB     |     -3 | 41.47 | 40.86 |  129 | 31.03 | 28.88 |   515 | 33.12 | 31.28 |   644
 V6_BBrel_Ku_BB | KMLB     |   -1.5 | 40.98 | 40.37 |  886 |  32.1 | 30.37 |  1477 | 35.43 | 34.12 |  2363
 V6_BBrel_Ku_BB | KMLB     |      0 | 39.17 | 38.64 |  940 | 31.61 | 31.77 |  1882 | 34.13 | 34.06 |  2822
 V6_BBrel_Ku_BB | KMLB     |    1.5 | 34.16 | 33.09 |  417 | 26.13 | 26.33 |   906 | 28.66 | 28.46 |  1323
 V6_BBrel_Ku_BB | KMLB     |      3 | 31.08 | 29.78 |  196 | 23.76 | 23.07 |   311 | 26.59 | 25.66 |   507
 V6_BBrel_Ku_BB | KMLB     |    4.5 | 29.97 | 29.35 |   87 | 23.03 | 22.61 |    30 | 28.19 | 27.62 |   117
 V6_BBrel_Ku_BB | KMOB     |     -3 | 39.43 | 43.73 |  179 |  31.6 | 33.68 |   207 | 35.23 | 38.34 |   386
 V6_BBrel_Ku_BB | KMOB     |   -1.5 | 40.34 | 41.16 |  769 | 30.62 | 31.05 |  2477 | 32.93 | 33.45 |  3246
 V6_BBrel_Ku_BB | KMOB     |      0 | 39.75 | 39.79 | 1025 | 31.26 | 33.55 |  4829 | 32.74 | 34.64 |  5854
 V6_BBrel_Ku_BB | KMOB     |    1.5 | 33.85 | 30.99 |  637 | 26.31 | 26.52 |  2654 | 27.77 | 27.38 |  3291
 V6_BBrel_Ku_BB | KMOB     |      3 | 29.74 | 26.32 |  295 | 23.59 | 22.91 |   635 | 25.54 | 23.99 |   930
 V6_BBrel_Ku_BB | KMOB     |    4.5 |  33.2 | 30.26 |   75 |  23.1 | 22.47 |    37 | 29.86 | 27.69 |   112
 V6_BBrel_Ku_BB | KSHV     |     -3 | 44.67 | 49.85 |   16 | 29.22 | 31.95 |   285 | 30.04 |  32.9 |   301
 V6_BBrel_Ku_BB | KSHV     |   -1.5 | 42.03 | 44.21 |  930 | 29.81 | 31.24 |  1949 | 33.75 | 35.43 |  2879
 V6_BBrel_Ku_BB | KSHV     |      0 | 39.01 |  40.9 | 1504 | 30.35 | 33.56 |  3740 | 32.83 | 35.67 |  5244
 V6_BBrel_Ku_BB | KSHV     |    1.5 | 34.68 | 35.45 |  971 | 25.62 | 27.58 |  1876 | 28.71 | 30.27 |  2847
 V6_BBrel_Ku_BB | KSHV     |      3 | 31.08 | 31.51 |  758 | 23.51 | 25.38 |   955 | 26.86 | 28.09 |  1713
 V6_BBrel_Ku_BB | KSHV     |    4.5 | 29.34 | 29.97 |  468 | 22.38 | 24.24 |   396 | 26.15 | 27.34 |   864
 V6_BBrel_Ku_BB | KSHV     |      6 | 30.66 | 31.49 |  170 | 20.56 | 23.03 |     6 | 30.31 |  31.2 |   176
 V6_BBrel_Ku_BB | KTBW     |     -3 | 41.51 | 44.36 |  218 | 31.13 | 32.86 |   562 | 34.03 | 36.08 |   780
 V6_BBrel_Ku_BB | KTBW     |   -1.5 |    41 | 42.99 |  874 | 30.34 | 31.49 |  2395 | 33.19 | 34.57 |  3269
 V6_BBrel_Ku_BB | KTBW     |      0 |  39.2 | 40.79 |  908 | 30.91 | 33.48 |  2858 | 32.91 | 35.24 |  3766
 V6_BBrel_Ku_BB | KTBW     |    1.5 | 34.15 | 34.49 |  466 | 25.66 |  27.6 |  1212 | 28.02 | 29.51 |  1678
 V6_BBrel_Ku_BB | KTBW     |      3 | 30.62 | 30.04 |  228 | 22.89 | 23.91 |   372 | 25.83 | 26.24 |   600
 V6_BBrel_Ku_BB | KTBW     |    4.5 | 29.51 | 29.41 |  108 | 21.84 | 22.48 |    20 | 28.31 | 28.32 |   128
 V6_BBrel_Ku_BB | KTLH     |     -3 | 42.09 | 48.64 |    6 | 27.79 |  31.7 |    54 | 29.22 | 33.39 |    60
 V6_BBrel_Ku_BB | KTLH     |   -1.5 | 39.54 | 42.52 |  643 | 31.05 | 33.78 |  3328 | 32.42 |  35.2 |  3971
 V6_BBrel_Ku_BB | KTLH     |      0 | 37.23 | 39.77 |  808 | 31.14 | 34.87 |  4569 | 32.06 | 35.61 |  5377
 V6_BBrel_Ku_BB | KTLH     |    1.5 |  31.5 | 33.22 |  395 | 25.95 | 28.89 |  2254 | 26.78 | 29.54 |  2649
 V6_BBrel_Ku_BB | KTLH     |      3 | 28.23 | 28.96 |  214 | 23.96 | 26.07 |   983 | 24.72 | 26.59 |  1197
 V6_BBrel_Ku_BB | KTLH     |    4.5 | 28.49 | 29.16 |   61 | 22.76 | 24.78 |   267 | 23.82 | 25.59 |   328
(133 rows)
