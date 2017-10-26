\copy dbzdiff_stats_by_dist from '/data/gpmgv/tmp/StatsByDistToDB_2A55andREOgrids.unl' with delimiter '|' 

select gvtype, radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist where regime='S_above' and numpts>5 and rangecat < 2 group by 1,2 order by 2,1;
 gvtype | radar_id | meanmeandiff | total 
--------+----------+--------------+-------
 REOR   | DARW     |        -1.63 |  3033
 2A55   | KAMX     |         0.15 |  6740
 REOR   | KAMX     |        -0.34 |  4592
 2A55   | KBMX     |         -0.4 | 26125
 REOR   | KBMX     |        -0.77 | 22927
 2A55   | KBRO     |        -0.54 |  7040
 REOR   | KBRO     |        -0.75 |  4047
 2A55   | KBYX     |        -0.22 |  2993
 REOR   | KBYX     |        -0.75 |  2313
 2A55   | KCLX     |        -0.45 | 15826
 REOR   | KCLX     |        -0.64 | 13974
 2A55   | KCRP     |         0.48 |  5394
 REOR   | KCRP     |         0.28 |  3788
 2A55   | KDGX     |         0.23 | 13159
 REOR   | KDGX     |        -0.21 | 10842
 2A55   | KEVX     |            0 | 16066
 REOR   | KEVX     |        -0.24 | 11483
 2A55   | KFWS     |         1.06 | 22150
 REOR   | KFWS     |         0.77 | 20494
 2A55   | KGRK     |         2.44 |  9115
 REOR   | KGRK     |         2.05 |  8336
 2A55   | KHGX     |         0.16 |  5389
 REOR   | KHGX     |        -0.31 |  4810
 2A55   | KHTX     |         0.49 | 19898
 REOR   | KHTX     |         0.05 | 17516
 2A55   | KJAX     |        -0.97 | 10257
 REOR   | KJAX     |        -1.33 |  7019
 2A55   | KJGX     |         0.86 | 15082
 REOR   | KJGX     |         0.47 | 12109
 2A55   | KLCH     |        -1.55 | 13610
 REOR   | KLCH     |        -1.46 |  8789
 2A55   | KLIX     |        -1.16 | 19417
 REOR   | KLIX     |        -1.26 | 14530
 2A55   | KMLB     |         0.87 |  4563
 REOR   | KMLB     |         0.43 |  3872
 2A55   | KMOB     |         1.37 |  9023
 REOR   | KMOB     |         1.05 |  7119
 2A55   | KSHV     |        -0.64 | 23298
 REOR   | KSHV     |        -0.82 | 19054
 2A55   | KTBW     |        -0.57 |  8552
 REOR   | KTBW     |        -0.87 |  6554
 2A55   | KTLH     |        -1.34 | 12206
 REOR   | KTLH     |        -1.33 |  7879
 REOR   | RGSN     |         1.78 |  9382
 REOR   | RMOR     |         0.53 |  6984
(45 rows)

select gvtype, radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into gridstats_100km from dbzdiff_stats_by_dist where regime='S_above' and numpts>5 and rangecat < 2 group by 1,2 order by 2,1;

select gvtype, radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp geostats from dbzdiff_stats_defaultAGL where regime='S_above' and numpts>5 and orbit between (select min(orbit) from dbzdiff_stats_by_dist) and (select max(orbit) from dbzdiff_stats_by_dist) and percent_of_bins=100 group by 1,2 order by 2,1;

select a.radar_id, a.meanmeandiff as bias55, a.total as n55, b.meanmeandiff as biasreo, b.total as nreo, c.meanmeandiff as biasgeo, c.total as ngeo from  gridstats_100km a, gridstats_100km b, geostats c where a.radar_id = b.radar_id and a.radar_id =c.radar_id and a.gvtype='2A55' and b.gvtype='REOR';

 radar_id | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo  
----------+--------+-------+---------+-------+---------+-------
 KAMX     |   0.15 |  6740 |   -0.34 |  4592 |   -0.77 |  2716
 KBMX     |   -0.4 | 26125 |   -0.77 | 22927 |   -2.38 | 10856
 KBRO     |  -0.54 |  7040 |   -0.75 |  4047 |   -1.15 |  2352
 KBYX     |  -0.22 |  2993 |   -0.75 |  2313 |   -1.22 |  1276
 KCLX     |  -0.45 | 15826 |   -0.64 | 13974 |   -1.64 |  7278
 KCRP     |   0.48 |  5394 |    0.28 |  3788 |   -0.27 |  3527
 KDGX     |   0.23 | 13159 |   -0.21 | 10842 |   -1.41 |  5691
 KEVX     |      0 | 16066 |   -0.24 | 11483 |   -1.14 |  6645
 KFWS     |   1.06 | 22150 |    0.77 | 20494 |   -0.19 | 11434
 KGRK     |   2.44 |  9115 |    2.05 |  8336 |    1.76 |  7096
 KHGX     |   0.16 |  5389 |   -0.31 |  4810 |   -1.17 |  3548
 KHTX     |   0.49 | 19898 |    0.05 | 17516 |   -1.91 | 10822
 KJAX     |  -0.97 | 10257 |   -1.33 |  7019 |    -2.1 |  4952
 KJGX     |   0.86 | 15082 |    0.47 | 12109 |   -0.72 |  6456
 KLCH     |  -1.55 | 13610 |   -1.46 |  8789 |   -2.63 |  3847
 KLIX     |  -1.16 | 19417 |   -1.26 | 14530 |   -2.43 |  9737
 KMLB     |   0.87 |  4563 |    0.43 |  3872 |    0.01 |  2867
 KMOB     |   1.37 |  9023 |    1.05 |  7119 |    0.62 |  4830
 KSHV     |  -0.64 | 23298 |   -0.82 | 19054 |    -2.1 |  7077
 KTBW     |  -0.57 |  8552 |   -0.87 |  6554 |   -2.03 |  3917
 KTLH     |  -1.34 | 12206 |   -1.33 |  7879 |   -2.43 |  3474
(21 rows)

select gvtype, radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp geostats from dbzdiff_stats_defaultAGL where regime='S_above' and numpts>5 and orbit < (select max(orbit) from dbzdiff_stats_by_dist) and orbit > (select min(orbit) from dbzdiff_stats_by_dist) and percent_of_bins=25 group by 1,2 order by 2,1;
SELECT
gpmgv=# select a.radar_id, a.meanmeandiff as bias55, a.total as n55, b.meanmeandiff as biasreo, b.total as nreo, c.meanmeandiff as biasgeo, c.total as ngeo from  gridstats_100km a, gridstats_100km b, geostats c where a.radar_id = b.radar_id and a.radar_id =c.radar_id and a.gvtype='2A55' and b.gvtype='REOR';
 radar_id | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo  
----------+--------+-------+---------+-------+---------+-------
 KAMX     |   0.15 |  6740 |   -0.34 |  4592 |     0.3 |  8894
 KBMX     |   -0.4 | 26125 |   -0.77 | 22927 |      -1 | 30292
 KBRO     |  -0.54 |  7040 |   -0.75 |  4047 |   -0.17 |  6192
 KBYX     |  -0.22 |  2993 |   -0.75 |  2313 |    0.14 |  5746
 KCLX     |  -0.45 | 15826 |   -0.64 | 13974 |   -0.29 | 24087
 KCRP     |   0.48 |  5394 |    0.28 |  3788 |     0.7 |  9234
 KDGX     |   0.23 | 13159 |   -0.21 | 10842 |    0.07 | 19862
 KEVX     |      0 | 16066 |   -0.24 | 11483 |    0.14 | 18633
 KFWS     |   1.06 | 22150 |    0.77 | 20494 |    0.97 | 33152
 KGRK     |   2.44 |  9115 |    2.05 |  8336 |    2.55 | 20865
 KHGX     |   0.16 |  5389 |   -0.31 |  4810 |    0.57 | 12652
 KHTX     |   0.49 | 19898 |    0.05 | 17516 |    -0.4 | 33179
 KJAX     |  -0.97 | 10257 |   -1.33 |  7019 |   -0.84 | 15077
 KJGX     |   0.86 | 15082 |    0.47 | 12109 |    0.61 | 19766
 KLCH     |  -1.55 | 13610 |   -1.46 |  8789 |   -1.23 | 11717
 KLIX     |  -1.16 | 19417 |   -1.26 | 14530 |   -1.43 | 22771
 KMLB     |   0.87 |  4563 |    0.43 |  3872 |    1.16 | 12205
 KMOB     |   1.37 |  9023 |    1.05 |  7119 |    1.64 | 15464
 KSHV     |  -0.64 | 23298 |   -0.82 | 19054 |   -0.73 | 21811
 KTBW     |  -0.57 |  8552 |   -0.87 |  6554 |   -0.61 | 12022
 KTLH     |  -1.34 | 12206 |   -1.33 |  7879 |   -1.11 |  9910
(21 rows)

-- get a common set of samples between 2A55 and REOR for KMLB, the only site
-- with all 11 geomatch pct_abv_thresh categories
drop table common2a55reo;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp common2a55reo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b where a.rangecat<2 and a.radar_id = 'KMLB' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR';

-- get a common set of samples between 2A55, REOR, and geo-match for KMLB
drop table commongeogridbypct;
select a.percent_of_bins, round(a.timediff/60) as minutesoff, a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commongeogridbypct from zdiff_stats_by_dist_time_geo a, common2a55reo b where a.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime;

select percent_of_bins, count(*) from commongeogridbypct group by 1 order by 1;
 percent_of_bins | count 
-----------------+-------
               0 |  1154
              10 |  1153
              20 |  1145
              30 |  1134
              40 |  1115
              50 |  1092
              60 |  1038
              70 |   986
              80 |   905
              90 |   757
             100 |   625
(11 rows)

-- DIFFERENCES BY FRACTION OF CONVECTIVE VS. STRATIFORM RAIN

-- compute a percent stratiform and convective from the geo-match dataset
select percent_of_bins, radar_id, orbit, sum(numpts) as n_conv into temp npts_conv from zdiff_stats_by_dist_time_geo where regime like 'C_%' group by 1,2,3 order by 1,2,3;
select percent_of_bins, radar_id, orbit, sum(numpts) as n_strat into temp npts_strat from zdiff_stats_by_dist_time_geo where regime like 'S_%' group by 1,2,3 order by 1,2,3;
select a.percent_of_bins, a.radar_id, a.orbit, round((cast(n_conv as float)/(n_conv+n_strat))*10)*10 as pct_conv into temp pct_conv_temp from npts_conv a, npts_strat b where a.percent_of_bins=b.percent_of_bins and a.radar_id=b.radar_id and a.orbit=b.orbit and (b.n_strat>0 OR a.n_conv>0);

-- get mean differences for each source, as function of geo-match percent convective, for S_above:
select e.pct_conv, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prz_55, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvz_55, sum(a.numpts) as n55, round(avg(a.numpts)) as mean_n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prz_REO, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvz_REO, sum(b.numpts) as nREO, round(avg(b.numpts)) as mean_nreo, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as prz_geo, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gvz_geo, sum(c.numpts) as ngeo, round(avg(c.numpts)) as mean_ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d, pct_conv_temp e where a.height=b.height and a.height=c.height and a.height=d.height and a.orbit=b.orbit and a.orbit=c.orbit and a.orbit=d.orbit and a.orbit=e.orbit and a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.radar_id=d.radar_id and a.radar_id=e.radar_id and a.rangecat = b.rangecat and a.rangecat = c.rangecat and a.rangecat = d.rangecat and a.regime = b.regime and a.regime = c.regime and a.regime = d.regime and c.percent_of_bins= d.percent_of_bins and e.percent_of_bins=c.percent_of_bins and a.gvtype='2A55' and b.gvtype='REOR' and a.regime='S_above' and c.percent_of_bins=100 group by 1 order by 1;

 pct_conv | bias55 | prz_55 | gvz_55 | n55 | biasreo | prz_reo | gvz_reo | nreo | biasgeo | prz_geo | gvz_geo | ngeo
----------+--------+--------+--------+-----+---------+---------+---------+------+---------+---------+---------+------
        0 |   0.23 |  21.08 |  20.86 | 726 |   -0.12 |   21.18 |   21.31 |  603 |   -0.35 |   22.29 |   22.64 |  260
       10 |   1.01 |  21.63 |  20.62 | 776 |    0.74 |   21.65 |   20.91 |  664 |     0.8 |   22.98 |   22.18 |  394
       20 |   0.84 |  21.47 |  20.63 | 725 |    0.21 |   21.43 |   21.22 |  600 |   -0.06 |   22.72 |   22.78 |  336
       30 |   0.46 |  21.45 |  20.99 | 192 |    -0.1 |   21.39 |   21.49 |  167 |    -0.5 |   22.31 |    22.8 |   70
       50 |   2.37 |  22.61 |  20.24 | 240 |    1.58 |   22.25 |   20.66 |  225 |    2.07 |   24.66 |   22.59 |  183
       60 |   0.57 |  21.99 |  21.42 | 662 |    0.35 |   22.08 |   21.73 |  578 |   -0.33 |   23.17 |    23.5 |  353
       80 |   0.67 |  22.22 |  21.54 | 110 |    0.15 |   21.97 |   21.82 |  102 |   -0.06 |   23.24 |    23.3 |   31
       90 |   1.04 |  22.52 |  21.48 | 189 |    0.31 |   22.63 |   22.32 |  160 |   -0.12 |   23.13 |   23.25 |   84
      100 |   1.23 |  22.73 |   21.5 |  56 |    1.27 |   23.13 |   21.85 |   51 |    0.08 |   22.16 |   22.08 |   13
(9 rows)

-- as above but regime like 'C_%'
 pct_conv | bias55 | prz_55 | gvz_55 | n55  | biasreo | prz_reo | gvz_reo | nreo | biasgeo | prz_geo | gvz_geo | ngeo
----------+--------+--------+--------+------+---------+---------+---------+------+---------+---------+---------+------
       10 |   1.82 |  32.28 |  30.46 |  566 |    2.32 |   32.65 |   30.32 |  512 |     0.8 |   34.04 |   33.24 |  153
       20 |   2.51 |  31.74 |  29.23 | 1415 |    2.72 |   32.09 |   29.37 | 1221 |   -0.05 |   33.51 |   33.56 |  542
       30 |   3.07 |  34.46 |  31.39 |  419 |    3.23 |   35.14 |   31.91 |  372 |    1.37 |   36.89 |   35.52 |  153
       40 |   1.16 |  35.49 |  34.33 |  115 |    1.94 |   36.05 |   34.11 |  104 |   -2.46 |   39.14 |   41.61 |   36
       50 |   5.43 |  36.44 |  31.01 | 1157 |    5.25 |   36.86 |   31.62 |  999 |    2.78 |   38.49 |   35.71 |  810
       60 |   2.05 |  33.84 |   31.8 | 1198 |    2.66 |   34.31 |   31.64 | 1050 |   -0.35 |   33.79 |   34.15 |  605
       70 |   4.44 |  33.76 |  29.32 |   90 |    4.43 |   34.41 |   29.98 |   81 |    1.08 |    35.5 |   34.42 |   27
       80 |   2.35 |  32.35 |     30 |  561 |    2.94 |   32.49 |   29.55 |  507 |   -0.04 |   32.76 |    32.8 |  182
       90 |   3.45 |  35.19 |  31.74 | 1692 |    3.18 |   35.69 |   32.51 | 1350 |   -0.14 |   36.86 |      37 |  398
      100 |    1.7 |  31.94 |  30.25 |  602 |    2.26 |   32.37 |   30.11 |  516 |   -0.87 |   32.59 |   33.46 |  254
(10 rows)

-- as above but regime like 'S_%'
 pct_conv | bias55 | prz_55 | gvz_55 | n55  | biasreo | prz_reo | gvz_reo | nreo | biasgeo | prz_geo | gvz_geo | ngeo
----------+--------+--------+--------+------+---------+---------+---------+------+---------+---------+---------+------
        0 |   0.79 |  24.09 |   23.3 | 3388 |    0.54 |   24.17 |   23.63 | 2907 |    -0.3 |   26.79 |   27.09 | 1381
       10 |   1.68 |  26.39 |  24.71 | 6264 |    1.43 |   26.62 |   25.19 | 5715 |    0.62 |   28.45 |   27.84 | 3279
       20 |   1.59 |   26.3 |  24.71 | 3389 |    1.51 |   26.54 |   25.03 | 3026 |    0.03 |   27.94 |   27.91 | 1185
       30 |   1.38 |  26.31 |  24.93 | 1043 |       1 |   26.31 |   25.31 |  949 |   -0.13 |   27.25 |   27.38 |  255
       40 |   1.72 |  27.52 |   25.8 |  314 |     2.1 |   27.72 |   25.62 |  275 |    -0.4 |   29.44 |   29.84 |   48
       50 |   3.37 |  28.22 |  24.85 |  885 |    3.15 |   28.16 |   25.01 |  837 |    1.76 |   29.06 |    27.3 |  417
       60 |   0.79 |  24.37 |  23.58 | 1446 |    0.68 |   24.46 |   23.78 | 1327 |   -0.81 |    25.1 |   25.91 |  556
       70 |    0.8 |  26.89 |  26.09 |   66 |     0.6 |   26.85 |   26.24 |   65 |   -1.01 |    28.4 |   29.42 |   17
       80 |   1.41 |  24.56 |  23.15 |  225 |    0.49 |   24.01 |   23.52 |  193 |   -0.19 |   25.26 |   25.46 |   47
       90 |   1.23 |  22.93 |   21.7 |  237 |    0.15 |   22.78 |   22.63 |  199 |   -0.17 |   23.18 |   23.35 |   89
      100 |   1.23 |  22.73 |   21.5 |   56 |    1.27 |   23.13 |   21.85 |   51 |    0.08 |   22.16 |   22.08 |   13
(11 rows)


-- get mean differences for each source, as function of geo-match number of samples, for S_above:
select c.numpts/25 as ngeo25, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and c.percent_of_bins=100 and a.regime='S_above' group by 1 order by 1;

 ngeo25 | bias55 | n55  | biasreo | nreo | biasgeo | ngeo
--------+--------+------+---------+------+---------+------
      0 |   0.78 | 1382 |    0.23 | 1179 |   -0.06 |  312
      1 |   0.92 | 1323 |     0.5 | 1147 |    0.08 |  448
      2 |  -1.48 |   74 |   -0.61 |   58 |    -0.4 |  111
      3 |   0.77 |  859 |    0.41 |  742 |    0.27 |  328
      5 |   0.99 |   78 |    1.08 |   62 |    0.66 |  535
(5 rows)

--get mean differences by time offset in minutes
select c.regime,  d.minutesoff,round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and c.percent_of_bins=100  group by 1,2 order by 1,2;
 regime  | minutesoff | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo  
---------+------------+--------+-------+---------+-------+---------+-------
 C_above |          0 |   2.47 |  1279 |    2.38 |   992 |    0.18 |   522
 C_above |          1 |   1.37 |   959 |     1.8 |   777 |   -0.32 |   591
 C_above |          2 |   2.43 |   220 |    2.87 |   195 |    2.13 |    77
 C_above |          3 |   2.19 |   256 |    1.62 |   201 |    0.58 |    79
 C_above |          4 |   2.26 |   164 |    2.82 |   140 |    1.38 |    78
 C_below |          0 |   4.27 |  1428 |    4.48 |  1278 |    1.92 |   496
 C_below |          1 |   2.94 |   883 |    3.28 |   785 |    0.29 |   159
 C_below |          2 |   2.69 |   223 |    2.56 |   203 |    0.51 |    60
 C_below |          3 |   3.94 |   641 |    3.76 |   574 |    0.96 |   159
 C_below |          4 |   5.19 |    95 |    5.46 |    78 |    1.89 |    14
 C_in    |          0 |   2.72 |   612 |    2.86 |   531 |    2.24 |   428
 C_in    |          1 |   2.49 |   472 |       3 |   438 |   -1.13 |   278
 C_in    |          2 |   4.37 |   199 |    4.21 |   186 |    1.05 |    90
 C_in    |          3 |   3.51 |   384 |    3.64 |   334 |   -1.33 |   129
 S_above |          0 |   1.16 |  1646 |    0.67 |  1395 |    0.73 |   868
 S_above |          1 |   0.47 |  1189 |    0.05 |  1030 |   -0.23 |   586
 S_above |          2 |   0.73 |    48 |   -0.34 |    40 |    0.65 |    19
 S_above |          3 |   0.43 |   505 |    0.29 |   446 |   -0.23 |   129
 S_above |          4 |   0.64 |   328 |     0.3 |   277 |   -0.47 |   132
 S_below |          0 |    2.4 |  5428 |    2.18 |  5041 |    1.53 |  1956
 S_below |          1 |   1.85 |  1438 |    1.74 |  1337 |    0.99 |   266
 S_below |          2 |   1.68 |   972 |    1.17 |   853 |    0.78 |   129
 S_below |          3 |   1.15 |  1587 |    1.06 |  1480 |    0.53 |   289
 S_in    |          0 |   0.68 |  2233 |    0.52 |  1913 |   -0.34 |  1784
 S_in    |          1 |   0.36 |   704 |    0.39 |   659 |   -1.09 |   471
 S_in    |          2 |   1.95 |   466 |    1.16 |   426 |   -0.68 |   389
 S_in    |          3 |   0.82 |   809 |    1.11 |   685 |   -2.58 |   279
 Total   |          0 |    2.1 | 22972 |    1.82 | 20208 |    0.46 | 10756
 Total   |          1 |   1.47 |  9449 |    1.35 |  8318 |   -0.36 |  3478
 Total   |          2 |   1.81 |  5418 |    1.47 |  4739 |    0.11 |  1701
 Total   |          3 |   1.75 |  6900 |    1.67 |  5908 |   -0.25 |  2323
 Total   |          4 |   1.67 |  1650 |    1.39 |  1377 |   -0.02 |   566
 Total   |          5 |   0.13 |    66 |   -0.36 |    58 |   -1.27 |    11
(33 rows)

-- get mean of the Standard Deviation of the differences, by time offset
select c.regime,  d.minutesoff, round((sum(a.diffstddev*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.diffstddev*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and c.percent_of_bins=100 group by 1,2 order by 1,2;
 regime  | minutesoff | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo  
---------+------------+--------+-------+---------+-------+---------+-------
 C_above |          0 |   3.37 |  1279 |    4.79 |   992 |    2.02 |   522
 C_above |          1 |   3.45 |   959 |    4.28 |   777 |    2.66 |   591
 C_above |          2 |   4.44 |   220 |    5.52 |   195 |     4.8 |    77
 C_above |          3 |   4.42 |   256 |    5.27 |   201 |    4.71 |    79
 C_above |          4 |   3.09 |   164 |    4.99 |   140 |    3.05 |    78
 C_below |          0 |   5.02 |  1428 |     6.3 |  1278 |    2.33 |   496
 C_below |          1 |   5.38 |   883 |    7.07 |   785 |    2.18 |   159
 C_below |          2 |   5.92 |   223 |    6.68 |   203 |    2.73 |    60
 C_below |          3 |   6.09 |   641 |    6.78 |   574 |    3.51 |   159
 C_below |          4 |   5.51 |    95 |    6.81 |    78 |    3.17 |    14
 C_in    |          0 |   4.18 |   612 |    5.45 |   531 |    2.19 |   428
 C_in    |          1 |   4.49 |   472 |    5.66 |   438 |    2.31 |   278
 C_in    |          2 |   5.42 |   199 |    7.12 |   186 |    3.12 |    90
 C_in    |          3 |   6.22 |   384 |     6.6 |   334 |    5.11 |   129
 S_above |          0 |   1.22 |  1646 |    1.85 |  1395 |    0.96 |   868
 S_above |          1 |   1.38 |  1189 |    1.81 |  1030 |    1.03 |   586
 S_above |          2 |   1.69 |    48 |     2.3 |    40 |     1.4 |    19
 S_above |          3 |   2.23 |   505 |    2.43 |   446 |     2.3 |   129
 S_above |          4 |   1.88 |   328 |    2.71 |   277 |    0.88 |   132
 S_below |          0 |   2.66 |  5428 |    3.45 |  5041 |    1.31 |  1956
 S_below |          1 |   2.87 |  1438 |    3.56 |  1337 |    1.41 |   266
 S_below |          2 |   2.77 |   972 |    3.52 |   853 |    1.68 |   129
 S_below |          3 |   2.93 |  1587 |    3.65 |  1480 |     2.5 |   289
 S_in    |          0 |   1.92 |  2233 |    2.72 |  1913 |     1.7 |  1784
 S_in    |          1 |   2.17 |   704 |    2.97 |   659 |    1.82 |   471
 S_in    |          2 |   3.08 |   466 |    3.75 |   426 |     2.4 |   389
 S_in    |          3 |   3.33 |   809 |    3.87 |   685 |    3.19 |   279
 Total   |          0 |   3.03 | 22972 |    4.04 | 20208 |    1.73 | 10756
 Total   |          1 |   3.38 |  9449 |    4.41 |  8318 |    1.95 |  3478
 Total   |          2 |   3.72 |  5418 |    4.66 |  4739 |     2.5 |  1701
 Total   |          3 |   4.08 |  6900 |    4.71 |  5908 |    3.43 |  2323
 Total   |          4 |   3.75 |  1650 |    5.08 |  1377 |    2.37 |   566
 Total   |          5 |   3.26 |    66 |    4.41 |    58 |    1.83 |    11
(33 rows)

-- get mean differences for each source, as function of geo-match percent_of_bins, for S_above:
select d.percent_of_bins, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and a.regime='S_above' group by 1 order by 1;

-- same thing, but for all rain types
select d.percent_of_bins, d.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins group by 1,2 order by 2,1;

-- add mean Z's to above
select d.percent_of_bins as pctabv, d.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as pr _55, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvz_55, sum(a.numpts) as n55, round(avg(a.numpts)) as n55avg, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100  s biasREO, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prz_REO, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvz_REO, sum(b.numpts) as nREO, round(avg(b.nu pts)) as nreoavg, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as prz_geo, round((sum(c.gvmean*c.numpts /sum(c.numpts))*100)/100 as gvz_geo, sum(c.numpts) as ngeo, round(avg(c.numpts)) as ngeoavg from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, c mmongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins group by 1,2 order by 2,1;
 pctabv | regime  | bias55 | prz_55 | gvz_55 |  n55  | n55avg | biasreo | prz_reo | gvz_reo | nreo  | nreoavg | biasgeo | prz_geo | gvz_geo | ngeo  | ngeoavg 
--------+---------+--------+--------+--------+-------+--------+---------+---------+---------+-------+---------+---------+---------+---------+-------+---------
      0 | C_above |   1.99 |  27.89 |  25.91 |  3842 |     31 |    1.96 |   28.05 |   26.09 |  2989 |      24 |    1.26 |   25.75 |   24.49 |  4689 |      38
     10 | C_above |   1.99 |  27.89 |  25.91 |  3842 |     31 |    1.96 |   28.05 |   26.09 |  2989 |      24 |    1.02 |   25.89 |   24.87 |  4572 |      37
     20 | C_above |   1.99 |   27.9 |  25.91 |  3837 |     31 |    1.97 |   28.06 |   26.09 |  2984 |      24 |    0.78 |   26.25 |   25.48 |  4287 |      35
     30 | C_above |   1.99 |   27.9 |  25.91 |  3837 |     31 |    1.97 |   28.06 |   26.09 |  2984 |      24 |    0.62 |   26.65 |   26.03 |  3981 |      33
     40 | C_above |   1.99 |  27.92 |  25.92 |  3822 |     32 |    1.98 |   28.08 |    26.1 |  2972 |      25 |    0.55 |   26.93 |   26.38 |  3729 |      31
     50 | C_above |      2 |  27.92 |  25.93 |  3812 |     32 |    1.98 |   28.09 |   26.11 |  2962 |      25 |    0.47 |   27.28 |   26.81 |  3459 |      29
     60 | C_above |   1.99 |  27.94 |  25.94 |  3775 |     33 |    1.98 |    28.1 |   26.12 |  2933 |      26 |    0.36 |   27.73 |   27.36 |  3083 |      27
     70 | C_above |   2.02 |  27.99 |  25.97 |  3705 |     35 |    2.04 |   28.16 |   26.12 |  2885 |      27 |    0.35 |   28.15 |   27.79 |  2751 |      26
     80 | C_above |   2.04 |  28.08 |  26.04 |  3582 |     37 |    2.08 |   28.24 |   26.16 |  2800 |      29 |    0.28 |   28.51 |   28.24 |  2404 |      25
     90 | C_above |    2.1 |  28.36 |  26.26 |  3251 |     42 |    2.16 |   28.51 |   26.35 |  2575 |      33 |    0.27 |   29.45 |   29.18 |  1864 |      24
    100 | C_above |   2.06 |  28.31 |  26.24 |  2878 |     45 |    2.19 |   28.48 |   26.29 |  2305 |      36 |    0.16 |   30.11 |   29.95 |  1347 |      21
      0 | C_below |   3.41 |   37.5 |  34.09 |  5536 |     48 |    3.54 |   37.88 |   34.34 |  4816 |      42 |    1.96 |   34.91 |   32.95 |  5065 |      44
     10 | C_below |   3.41 |   37.5 |  34.09 |  5536 |     48 |    3.54 |   37.88 |   34.34 |  4816 |      42 |    1.35 |   35.51 |   34.17 |  4774 |      41
     20 | C_below |   3.41 |  37.54 |  34.13 |  5477 |     48 |    3.54 |   37.91 |   34.37 |  4770 |      42 |    0.97 |   36.33 |   35.36 |  4373 |      38
     30 | C_below |   3.41 |  37.53 |  34.12 |  5446 |     48 |    3.54 |   37.91 |   34.37 |  4744 |      42 |    0.92 |   37.05 |   36.13 |  3980 |      35
     40 | C_below |   3.42 |  37.58 |  34.16 |  5391 |     49 |    3.57 |   37.95 |   34.38 |  4705 |      43 |     0.9 |    37.6 |   36.69 |  3661 |      34
     50 | C_below |   3.31 |  37.55 |  34.24 |  5145 |     49 |    3.47 |   37.91 |   34.45 |  4498 |      43 |    0.88 |   38.12 |   37.25 |  3298 |      31
     60 | C_below |   3.36 |  37.62 |  34.26 |  4948 |     52 |    3.55 |   37.97 |   34.42 |  4337 |      45 |    0.91 |   38.79 |   37.88 |  2895 |      30
     70 | C_below |   3.42 |  37.76 |  34.34 |  4732 |     54 |    3.64 |   38.12 |   34.49 |  4152 |      47 |    1.04 |   39.43 |   38.39 |  2479 |      28
     80 | C_below |   3.44 |  37.94 |   34.5 |  4407 |     58 |    3.65 |   38.29 |   34.63 |  3872 |      51 |    1.06 |   39.99 |   38.92 |  2021 |      27
     90 | C_below |   3.54 |  38.39 |  34.85 |  3820 |     63 |    3.73 |   38.66 |   34.93 |  3392 |      56 |    1.09 |   40.66 |   39.57 |  1438 |      24
    100 | C_below |   3.77 |  38.74 |  34.97 |  3270 |     71 |    3.91 |      39 |   35.09 |  2918 |      63 |    1.36 |   41.26 |    39.9 |   888 |      19
      0 | C_in    |   2.96 |  33.36 |   30.4 |  1847 |     46 |    3.09 |   33.45 |   30.36 |  1628 |      41 |    0.96 |    33.6 |   32.64 |  2673 |      67
     10 | C_in    |   2.96 |   33.4 |  30.44 |  1833 |     47 |     3.1 |   33.49 |   30.39 |  1617 |      41 |    0.68 |   33.84 |   33.16 |  2610 |      67
     20 | C_in    |   2.96 |   33.4 |  30.44 |  1833 |     47 |     3.1 |   33.49 |   30.39 |  1617 |      41 |    0.45 |   34.33 |   33.87 |  2484 |      64
     30 | C_in    |   2.96 |   33.4 |  30.44 |  1833 |     47 |     3.1 |   33.49 |   30.39 |  1617 |      41 |    0.36 |   34.81 |   34.45 |  2354 |      60
     40 | C_in    |   2.96 |   33.4 |  30.44 |  1833 |     47 |     3.1 |   33.49 |   30.39 |  1617 |      41 |    0.35 |   35.26 |   34.91 |  2211 |      57
     50 | C_in    |   2.95 |  33.42 |  30.47 |  1824 |     48 |    3.09 |   33.52 |   30.43 |  1609 |      42 |    0.37 |   35.71 |   35.34 |  2070 |      54
     60 | C_in    |   2.95 |  33.43 |  30.49 |  1817 |     49 |    3.09 |   33.54 |   30.45 |  1601 |      43 |    0.38 |   36.14 |   35.76 |  1905 |      51
     70 | C_in    |   2.95 |  33.46 |  30.51 |  1801 |     50 |     3.1 |   33.55 |   30.45 |  1591 |      44 |    0.46 |    36.5 |   36.05 |  1756 |      49
     80 | C_in    |   2.97 |  33.58 |  30.61 |  1770 |     52 |    3.13 |   33.65 |   30.52 |  1568 |      46 |    0.54 |   36.94 |    36.4 |  1519 |      45
     90 | C_in    |   2.99 |  33.77 |  30.78 |  1715 |     55 |    3.19 |   33.79 |   30.61 |  1529 |      49 |    0.54 |    37.3 |   36.76 |  1255 |      40
    100 | C_in    |   3.03 |  33.74 |  30.71 |  1667 |     57 |    3.25 |   33.77 |   30.52 |  1489 |      51 |    0.62 |   37.53 |   36.91 |   925 |      32
      0 | S_above |   0.87 |  21.72 |  20.85 |  4519 |     45 |    0.42 |   21.68 |   21.26 |  3839 |      38 |    1.68 |   21.18 |   19.49 |  8142 |      81
     10 | S_above |   0.87 |  21.72 |  20.85 |  4519 |     45 |    0.42 |   21.68 |   21.26 |  3839 |      38 |    1.55 |    21.2 |   19.65 |  8007 |      79
     20 | S_above |   0.87 |  21.72 |  20.85 |  4519 |     45 |    0.42 |   21.68 |   21.26 |  3839 |      38 |    1.33 |   21.35 |   20.02 |  7328 |      73
     30 | S_above |   0.87 |  21.72 |  20.85 |  4519 |     45 |    0.42 |   21.68 |   21.26 |  3839 |      38 |    1.13 |   21.51 |   20.38 |  6603 |      65
     40 | S_above |   0.86 |   21.7 |  20.84 |  4485 |     45 |     0.4 |   21.67 |   21.27 |  3809 |      38 |    1.02 |    21.6 |   20.58 |  6168 |      62
     50 | S_above |   0.86 |   21.7 |  20.84 |  4478 |     45 |    0.41 |   21.67 |   21.26 |  3804 |      38 |    0.91 |   21.71 |   20.79 |  5696 |      58
     60 | S_above |   0.86 |  21.71 |  20.85 |  4429 |     47 |    0.41 |   21.68 |   21.27 |  3760 |      40 |     0.8 |   21.88 |   21.08 |  5000 |      53
     70 | S_above |   0.87 |  21.72 |  20.86 |  4395 |     48 |    0.41 |   21.69 |   21.28 |  3735 |      41 |    0.67 |   22.09 |   21.42 |  4231 |      46
     80 | S_above |   0.87 |  21.73 |  20.86 |  4324 |     51 |    0.41 |    21.7 |   21.29 |  3671 |      44 |    0.54 |   22.28 |   21.74 |  3589 |      43
     90 | S_above |   0.82 |  21.67 |  20.84 |  4069 |     62 |    0.38 |   21.67 |   21.28 |  3456 |      52 |     0.4 |   22.68 |   22.27 |  2500 |      38
    100 | S_above |   0.79 |  21.68 |  20.89 |  3716 |     71 |    0.37 |    21.7 |   21.33 |  3188 |      61 |    0.24 |   23.02 |   22.78 |  1734 |      33
      0 | S_below |   1.98 |  27.78 |   25.8 | 13898 |     86 |    1.65 |   27.82 |   26.17 | 12530 |      78 |    2.56 |    25.4 |   22.84 | 13125 |      82
     10 | S_below |   1.98 |  27.78 |   25.8 | 13898 |     86 |    1.65 |   27.82 |   26.17 | 12530 |      78 |    2.08 |   25.57 |   23.49 | 12493 |      78
     20 | S_below |   1.98 |  27.79 |   25.8 | 13829 |     88 |    1.67 |   27.83 |   26.17 | 12478 |      79 |    1.83 |   25.79 |   23.97 | 11647 |      74
     30 | S_below |   1.97 |  27.78 |  25.81 | 13685 |     89 |    1.66 |   27.83 |   26.17 | 12356 |      81 |    1.64 |   26.11 |   24.47 | 10559 |      69
     40 | S_below |   1.99 |  27.79 |  25.81 | 13517 |     93 |    1.68 |   27.86 |   26.18 | 12225 |      84 |    1.56 |   26.41 |   24.85 |  9558 |      66
     50 | S_below |   1.99 |  27.81 |  25.81 | 13332 |     98 |     1.7 |   27.87 |   26.18 | 12094 |      89 |    1.49 |   26.65 |   25.16 |  8756 |      64
     60 | S_below |      2 |   27.8 |   25.8 | 13145 |    102 |     1.7 |   27.87 |   26.17 | 11937 |      93 |    1.44 |   27.06 |   25.62 |  7642 |      59
     70 | S_below |   2.01 |   27.8 |  25.79 | 12887 |    111 |    1.73 |   27.88 |   26.15 | 11724 |     101 |    1.44 |    27.5 |   26.06 |  6586 |      57
     80 | S_below |   1.98 |  27.73 |  25.75 | 11876 |    119 |    1.69 |   27.81 |   26.11 | 10851 |     109 |     1.4 |   27.94 |   26.53 |  5583 |      56
     90 | S_below |   1.99 |  27.79 |   25.8 | 10732 |    136 |    1.73 |   27.87 |   26.14 |  9846 |     125 |    1.34 |   28.45 |   27.11 |  4346 |      55
    100 | S_below |   2.03 |  27.99 |  25.95 |  9425 |    165 |    1.82 |    28.1 |   26.28 |  8711 |     153 |    1.33 |      30 |   28.67 |  2640 |      46
      0 | S_in    |   0.79 |   24.3 |  23.52 |  4819 |     74 |    0.63 |   24.36 |   23.72 |  4174 |      64 |    0.69 |   25.02 |   24.33 |  7631 |     117
     10 | S_in    |   0.79 |   24.3 |  23.52 |  4819 |     74 |    0.63 |   24.36 |   23.72 |  4174 |      64 |    0.42 |   25.12 |   24.71 |  7437 |     114
     20 | S_in    |   0.79 |  24.32 |  23.53 |  4772 |     76 |    0.64 |   24.38 |   23.74 |  4129 |      66 |    0.12 |   25.41 |   25.28 |  6990 |     111
     30 | S_in    |   0.81 |  24.38 |  23.57 |  4685 |     78 |    0.66 |   24.42 |   23.77 |  4070 |      68 |   -0.08 |   25.69 |   25.78 |  6507 |     108
     40 | S_in    |   0.81 |  24.38 |  23.57 |  4685 |     78 |    0.66 |   24.42 |   23.77 |  4070 |      68 |   -0.19 |   25.91 |    26.1 |  6156 |     103
     50 | S_in    |    0.8 |  24.38 |  23.58 |  4674 |     79 |    0.66 |   24.43 |   23.77 |  4062 |      69 |   -0.32 |   26.18 |    26.5 |  5726 |      97
     60 | S_in    |   0.81 |  24.39 |  23.58 |  4635 |     83 |    0.66 |   24.44 |   23.78 |  4026 |      72 |   -0.45 |   26.52 |   26.97 |  5158 |      92
     70 | S_in    |   0.81 |  24.39 |  23.59 |  4611 |     84 |    0.66 |   24.44 |   23.78 |  4006 |      73 |   -0.53 |   26.94 |   27.47 |  4636 |      84
     80 | S_in    |   0.82 |  24.44 |  23.62 |  4525 |     87 |    0.68 |    24.5 |   23.82 |  3935 |      76 |    -0.6 |    27.3 |   27.91 |  4181 |      80
     90 | S_in    |   0.81 |  24.46 |  23.64 |  4373 |     93 |    0.68 |   24.53 |   23.85 |  3815 |      81 |   -0.63 |   27.98 |   28.61 |  3396 |      72
    100 | S_in    |    0.8 |  24.42 |  23.63 |  4212 |     98 |    0.68 |    24.5 |   23.82 |  3683 |      86 |   -0.72 |   28.38 |    29.1 |  2923 |      68
      0 | Total   |   1.83 |  28.38 |  26.54 | 52693 |     96 |    1.56 |    28.5 |   26.94 | 45407 |      83 |    1.53 |    26.3 |   24.77 | 72779 |     133
     10 | Total   |   1.83 |  28.38 |  26.54 | 52693 |     96 |    1.56 |    28.5 |   26.94 | 45407 |      83 |    1.17 |   26.47 |    25.3 | 70147 |     128
     20 | Total   |   1.83 |  28.38 |  26.54 | 52693 |     96 |    1.56 |    28.5 |   26.94 | 45407 |      83 |    0.88 |   26.85 |   25.97 | 65017 |     119
     30 | Total   |   1.83 |  28.38 |  26.54 | 52680 |     96 |    1.56 |    28.5 |   26.94 | 45397 |      83 |    0.69 |   27.26 |   26.56 | 59403 |     109
     40 | Total   |   1.83 |  28.38 |  26.55 | 52584 |     97 |    1.56 |    28.5 |   26.94 | 45339 |      84 |     0.6 |   27.57 |   26.98 | 54737 |     101
     50 | Total   |   1.83 |  28.38 |  26.55 | 52523 |     98 |    1.56 |   28.51 |   26.94 | 45286 |      84 |    0.51 |   27.85 |   27.34 | 50337 |      94
     60 | Total   |   1.84 |   28.4 |  26.56 | 52101 |    102 |    1.57 |   28.53 |   26.95 | 44971 |      88 |    0.43 |   28.29 |   27.86 | 44623 |      87
     70 | Total   |   1.84 |  28.42 |  26.57 | 51769 |    105 |    1.58 |   28.55 |   26.96 | 44713 |      91 |    0.39 |   28.77 |   28.38 | 39001 |      79
     80 | Total   |   1.84 |  28.42 |  26.58 | 51056 |    111 |    1.59 |   28.55 |   26.96 | 44193 |      96 |    0.33 |   29.14 |   28.81 | 33629 |      73
     90 | Total   |   1.84 |  28.42 |  26.58 | 49197 |    125 |     1.6 |   28.55 |   26.95 | 42784 |     108 |    0.28 |   29.78 |    29.5 | 26421 |      67
    100 | Total   |   1.87 |  28.49 |  26.63 | 46455 |    139 |    1.64 |   28.63 |   26.98 | 40608 |     122 |    0.18 |   30.48 |    30.3 | 18835 |      56
(77 rows)



-- same thing, but for Convective rain types
select d.percent_of_bins, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and a.regime like 'C_%' group by 1 order by 1;

-- Convective mean zdiff, by height, for 100% above thresh
select d.height, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and a.regime like 'C_%' and d.percent_of_bins=100 group by 1 order by 1;


-- Convective mean PR Z, by height, for 100% above thresh
select d.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and a.regime like 'C_%' and d.percent_of_bins=100 group by 1 order by 1;

-- Convective mean GR Z, by height, for 100% above thresh
select d.height, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and a.regime like 'C_%' and d.percent_of_bins=100 group by 1 order by 1;

-- get mean differences for each source, as function of distance category, for each type/slab, for 100% above thresh cases:
 select d.rangecat*50+25 as distance, d.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime  and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and d.percent_of_bins=100 group by 1,2 order by 2,1;
 distance | regime  | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo
----------+---------+--------+-------+---------+-------+---------+-------
       25 | C_above |   2.35 |   513 |    2.17 |   326 |     0.3 |   165
       75 | C_above |      2 |  2365 |    2.19 |  1979 |    0.14 |  1182
       25 | C_below |   4.07 |  1021 |    4.35 |   888 |    1.55 |   445
       75 | C_below |   3.63 |  2249 |    3.71 |  2030 |    1.17 |   443
       25 | C_in    |   5.18 |   175 |    4.08 |   123 |    3.04 |    85
       75 | C_in    |   2.78 |  1492 |    3.17 |  1366 |    0.37 |   840
       25 | S_above |    0.9 |   749 |     0.4 |   631 |   -0.03 |   237
       75 | S_above |   0.76 |  2967 |    0.36 |  2557 |    0.28 |  1497
       25 | S_below |   2.09 |  3201 |    1.68 |  2950 |    1.19 |  1540
       75 | S_below |      2 |  6224 |     1.9 |  5761 |    1.53 |  1100
       25 | S_in    |    1.4 |   597 |    1.79 |   451 |    -2.4 |   105
       75 | S_in    |    0.7 |  3615 |    0.53 |  3232 |   -0.66 |  2818
       25 | Total   |   2.04 | 10834 |    1.73 |  9103 |    0.32 |  5900
       75 | Total   |   1.81 | 35621 |    1.62 | 31505 |    0.11 | 12935
(14 rows)

-- as above, but for 0% above thresh (all points):
 distance | regime  | bias55 |  n55  | biasreo | nreo  | biasgeo | ngeo
----------+---------+--------+-------+---------+-------+---------+-------
       25 | C_above |   2.14 |   800 |    2.03 |   502 |    1.13 |   874
       75 | C_above |   1.94 |  3042 |    1.95 |  2487 |    1.29 |  3815
       25 | C_below |    3.6 |  1502 |    3.91 |  1267 |    2.04 |  2960
       75 | C_below |   3.34 |  4034 |    3.41 |  3549 |    1.84 |  2105
       25 | C_in    |   4.88 |   212 |    3.87 |   152 |    2.47 |   414
       75 | C_in    |   2.72 |  1635 |       3 |  1476 |    0.68 |  2259
       25 | S_above |   0.96 |  1024 |    0.44 |   823 |    1.31 |  1393
       75 | S_above |   0.84 |  3495 |    0.41 |  3016 |    1.76 |  6749
       25 | S_below |   2.14 |  3941 |    1.67 |  3544 |    2.49 |  8536
       75 | S_below |   1.92 |  9957 |    1.65 |  8986 |    2.68 |  4589
       25 | S_in    |   1.42 |   793 |    1.65 |   605 |    1.16 |   691
       75 | S_in    |   0.66 |  4026 |    0.46 |  3569 |    0.64 |  6940
       25 | Total   |   1.99 | 13024 |    1.67 | 10684 |    1.63 | 27402
       75 | Total   |   1.78 | 39669 |    1.52 | 34723 |    1.47 | 45377
(14 rows)

-- mean differences for each source for C_below, as a function of PR max Z from geo:
 select round((c.prmax/5))*5  as przmaxgeo, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo, count(*) as ncases from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and c.percent_of_bins=0 and a.regime='C_below' group by 1 order by 1;

-- all cases (pct=0)
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
-----------+--------+------+---------+------+---------+------+--------
        30 |   0.07 |   26 |   -0.17 |   22 |    4.07 |   37 |      2
        35 |   1.89 |  211 |     1.4 |  171 |    1.96 |  205 |     10
        40 |   2.14 | 1050 |    1.98 |  897 |     2.2 |  880 |     35
        45 |   3.11 | 1761 |    3.47 | 1524 |    0.77 | 1179 |     42
        50 |   4.38 | 1777 |    4.42 | 1583 |    2.24 | 2294 |     22
        55 |   4.15 |  711 |    4.44 |  619 |    2.93 |  470 |      5
(6 rows)

--  for geo pct above = 100
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
-----------+--------+------+---------+------+---------+------+--------
        35 |   3.27 |   38 |    3.88 |   36 |   -2.57 |    6 |      1
        40 |   1.49 |  199 |    1.59 |  179 |   -0.83 |   72 |      8
        45 |   2.69 |  883 |     3.1 |  805 |   -0.02 |  178 |     16
        50 |   4.57 | 1439 |    4.48 | 1279 |    1.88 |  477 |     16
        55 |   4.15 |  711 |    4.44 |  619 |    2.53 |  155 |      5
(5 rows)

-- as above, but C_above, percent_of_bins=0:
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo 
-----------+--------+------+---------+------+---------+------
        20 |  -0.11 |    5 |    1.61 |    5 |    3.42 |   12
        25 |   0.77 |  140 |     0.2 |  119 |    2.06 |  181
        30 |   1.16 |  404 |    0.72 |  299 |    1.81 |  503
        35 |    2.1 |  682 |    1.45 |  482 |    2.05 |  807
        40 |   2.09 | 1259 |    2.06 |  957 |    1.23 | 1296
        45 |   1.96 | 1186 |    2.48 |  997 |    0.38 | 1344
        50 |      4 |  166 |    3.64 |  130 |    1.56 |  546
(7 rows)

-- as above, but C_above, percent_of_bins=100:
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo 
-----------+--------+------+---------+------+---------+------
        25 |   0.73 |   42 |    0.29 |   35 |    1.35 |   10
        30 |   1.74 |  184 |    1.61 |  151 |    1.43 |   74
        35 |   2.28 |  461 |    1.55 |  340 |    0.99 |  127
        40 |   1.91 |  902 |    2.06 |  701 |   -0.01 |  327
        45 |   1.92 | 1123 |    2.47 |  948 |   -0.23 |  593
        50 |      4 |  166 |    3.64 |  130 |    0.55 |  216
(6 rows)

-- as above, but all convective:
-- all cases (pct=0)
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
-----------+--------+------+---------+------+---------+------+--------
        20 |  -0.11 |    5 |    1.61 |    5 |    3.42 |   12 |      1
        25 |   0.77 |  140 |     0.2 |  119 |    2.06 |  181 |      9
        30 |   1.14 |  448 |     0.7 |  337 |    1.91 |  563 |     28
        35 |    2.1 | 1072 |    1.67 |  811 |    2.02 | 1140 |     48
        40 |   2.05 | 2604 |    1.97 | 2118 |    1.61 | 2285 |     73
        45 |   2.67 | 3662 |     3.1 | 3175 |    0.44 | 2947 |     73
        50 |   4.24 | 2449 |    4.22 | 2136 |    1.82 | 3751 |     37
        55 |   4.28 |  845 |     4.5 |  732 |    1.83 | 1548 |     10
(8 rows)

--  for geo pct above = 100
 przmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
-----------+--------+------+---------+------+---------+------+--------
        25 |   0.73 |   42 |    0.29 |   35 |    1.35 |   10 |      2
        30 |   1.74 |  184 |    1.61 |  151 |    1.43 |   74 |      7
        35 |   2.34 |  610 |    2.12 |  482 |    0.77 |  172 |     15
        40 |   1.74 | 1371 |    1.87 | 1126 |   -0.19 |  435 |     33
        45 |   2.39 | 2678 |    2.89 | 2377 |   -0.39 |  947 |     42
        50 |   4.38 | 2085 |    4.27 | 1809 |    1.08 |  976 |     30
        55 |   4.28 |  845 |     4.5 |  732 |    2.11 |  546 |     10
(7 rows)

-- as above set, but by GV max value in geo-match:
-- all cases (pct=0), C_below
 grmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
----------+--------+------+---------+------+---------+------+--------
       30 |   4.94 |   53 |    5.71 |   46 |   11.13 |   20 |      2
       35 |   1.83 |  193 |    1.64 |  161 |    1.69 |  238 |     11
       40 |   3.14 | 1175 |    3.25 | 1012 |    2.87 |  679 |     30
       45 |   2.55 | 1571 |    2.65 | 1361 |    0.85 | 1356 |     42
       50 |   4.42 | 2280 |    4.52 | 2001 |    2.59 | 2416 |     27
       55 |   1.83 |  264 |    2.48 |  235 |   -0.22 |  356 |      4
(6 rows)

--  for geo pct above = 100, C_below
 grmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
----------+--------+------+---------+------+---------+------+--------
       40 |      2 |  150 |    2.51 |  137 |   -0.12 |   50 |      6
       45 |   2.99 | 1312 |    3.18 | 1197 |    0.24 |  310 |     22
       50 |   4.93 | 1544 |    4.94 | 1349 |    2.84 |  422 |     14
       55 |   1.83 |  264 |    2.48 |  235 |   -0.54 |  106 |      4
(4 rows)

-- as above, but all convective:
-- all cases (pct=0)
 grmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
----------+--------+------+---------+------+---------+------+--------
       20 |   1.26 |    5 |    0.45 |    5 |    2.18 |   14 |      1
       25 |   1.29 |  195 |    0.89 |  157 |    2.53 |  238 |     12
       30 |   2.12 |  460 |    1.51 |  356 |    2.47 |  540 |     27
       35 |   2.06 | 1014 |    1.72 |  744 |    2.13 | 1156 |     47
       40 |    2.5 | 2711 |    2.64 | 2253 |    1.82 | 2107 |     66
       45 |   2.36 | 2962 |    2.62 | 2535 |    0.56 | 2538 |     65
       50 |   3.97 | 3281 |    4.09 | 2867 |    1.81 | 4628 |     50
       55 |   3.09 |  597 |    3.25 |  516 |    0.27 | 1206 |     11
(8 rows)

--  for geo pct above = 100
 grmaxgeo | bias55 | n55  | biasreo | nreo | biasgeo | ngeo | ncases 
----------+--------+------+---------+------+---------+------+--------
       25 |   1.21 |   74 |    1.05 |   61 |    2.04 |   20 |      3
       30 |   2.23 |  250 |    1.75 |  198 |    1.62 |   90 |      9
       35 |   2.37 |  339 |    2.15 |  258 |    1.09 |   98 |      9
       40 |   1.99 | 1639 |    2.14 | 1362 |    0.17 |  489 |     35
       45 |   2.59 | 2637 |    2.99 | 2334 |   -0.08 |  768 |     41
       50 |   4.39 | 2365 |    4.39 | 2038 |    1.17 | 1315 |     32
       55 |   2.69 |  511 |    3.16 |  461 |    0.39 |  380 |     10
(7 rows)

-- case by case for C_below, pct=100, by AVG(pr max z):
select c.orbit, round(avg(c.prmax)) as przmaxgeo, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as bias55, sum(a.numpts) as n55, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as biasREO, sum(b.numpts) as nREO, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo, sum(c.numpts) as ngeo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b, zdiff_stats_by_dist_time_geo c, commongeogridbypct d where a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR' and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime   and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and c.percent_of_bins= d.percent_of_bins and c.percent_of_bins=100 and a.regime='C_below' group by 1 order by 2, 3;
 orbit | przmaxgeo | bias55 | n55 | biasreo | nreo | biasgeo | ngeo 
-------+-----------+--------+-----+---------+------+---------+------
 51745 |        37 |   3.27 |  38 |    3.88 |   36 |   -2.57 |    6
 54389 |        39 |   0.45 |  12 |   -0.09 |   11 |   -0.04 |    7
 56721 |        40 |   3.37 |  18 |    5.77 |   14 |   -1.69 |    5
 56129 |        41 |   0.66 |  21 |     0.5 |   19 |    0.59 |    5
 54813 |        42 |   0.77 |  39 |   -0.92 |   33 |   -2.36 |    9
 49837 |        42 |   1.58 |  61 |    2.01 |   57 |    0.57 |   27
 54569 |        42 |   2.06 |  38 |    2.75 |   36 |   -3.24 |    5
 60308 |        44 |   0.31 |  45 |    1.08 |   40 |   -0.08 |   14
 59209 |        44 |   4.48 |  94 |    4.72 |   82 |     0.6 |    8
 56202 |        45 |   0.71 |  91 |    1.29 |   82 |   -2.68 |   30
 55332 |        45 |   1.38 | 140 |     2.3 |  138 |   -0.39 |   25
 54908 |        46 |   2.05 | 119 |    2.56 |  105 |    0.67 |   48
 55717 |        46 |   3.54 |  46 |    3.18 |   37 |    1.12 |    9
 54752 |        46 |   5.62 |  77 |    5.39 |   64 |    3.88 |    9
 56370 |        47 |   1.98 |  31 |    2.31 |   26 |   -0.66 |   10
 58049 |        47 |    3.4 | 131 |    3.72 |  129 |    0.87 |   52
 58751 |        48 |   3.04 | 115 |       3 |  114 |    1.87 |   52
 55500 |        49 |   2.32 |  39 |    0.09 |   28 |   -1.83 |    5
 54691 |        49 |   2.56 | 214 |    2.54 |  185 |   -1.02 |   66
 50405 |        49 |   2.85 | 433 |    2.78 |  365 |    0.39 |   50
 59197 |        49 |    3.8 | 128 |    4.24 |  109 |    1.05 |   36
 59957 |        49 |   4.82 | 426 |    4.68 |  370 |    0.86 |   71
 51916 |        50 |   3.66 | 101 |    3.38 |   99 |    1.62 |   35
 54847 |        51 |   2.71 | 325 |    3.58 |  312 |    0.32 |   91
 60537 |        52 |    7.9 | 488 |    7.94 |  427 |    4.69 |  213
(25 rows)

-- for C_above:
 orbit | przmaxgeo | bias55 | n55 | biasreo | nreo | biasgeo | ngeo 
-------+-----------+--------+-----+---------+------+---------+------
 49837 |        27 |   1.29 |  15 |    0.71 |   14 |    1.98 |    5
 57457 |        29 |   1.84 |  32 |    2.08 |   26 |    2.73 |   10
 58049 |        29 |   1.85 |  75 |    1.56 |   63 |    0.76 |   33
 50344 |        30 |   1.46 |  39 |       1 |   29 |    1.96 |   12
 56370 |        32 |   0.85 |  42 |   -0.66 |   33 |   -0.59 |   13
 54908 |        32 |   1.73 |  68 |    1.67 |   57 |    1.68 |   26
 54569 |        35 |   1.14 |  16 |    1.33 |   15 |    0.25 |    8
 59209 |        35 |   1.54 | 134 |    2.35 |  126 |    0.08 |   65
 54691 |        35 |   1.95 | 111 |    1.01 |   78 |    0.14 |   22
 56068 |        36 |   1.37 |  23 |       1 |   25 |    2.91 |    5
 56248 |        36 |   1.78 |  54 |    1.63 |   43 |    2.21 |   16
 59957 |        38 |   2.71 | 117 |    0.91 |   72 |    0.28 |   14
 55717 |        39 |   1.71 | 104 |    1.43 |   80 |   -0.39 |   34
 59194 |        40 |   0.96 | 107 |    2.25 |   90 |   -1.06 |   48
 58751 |        41 |   1.79 |  92 |    2.19 |   89 |    0.09 |   50
 59136 |        42 |   1.06 |  83 |    1.48 |   60 |   -1.37 |   23
 50405 |        42 |   1.77 | 394 |    2.09 |  316 |    -0.1 |  246
 54752 |        42 |   2.26 | 164 |    2.82 |  140 |    1.38 |   78
 54847 |        43 |   0.83 | 335 |    1.51 |  259 |   -0.79 |  251
 59148 |        43 |    1.5 | 105 |    2.09 |   91 |    0.65 |   33
 53943 |        43 |    1.6 | 265 |    2.28 |  233 |   -0.95 |  151
 59197 |        43 |   2.52 | 235 |    2.26 |  173 |   -0.55 |   92
 60537 |        43 |   5.98 | 215 |    5.21 |  143 |    3.67 |   85
 51916 |        44 |   5.43 |  53 |    6.33 |   50 |    3.86 |   27
(24 rows)

-- for S_above:
 orbit | przmaxgeo | bias55 | n55 | biasreo | nreo | biasgeo | ngeo 
-------+-----------+--------+-----+---------+------+---------+------
 49886 |        22 |   0.76 |  30 |    -0.1 |   18 |   -0.08 |    5
 56068 |        22 |   1.28 |  23 |   -0.54 |   19 |    0.09 |    6
 54645 |        23 |  -0.48 |  46 |   -0.72 |   46 |   -1.06 |   10
 56248 |        23 |   0.16 |  37 |   -0.31 |   32 |   -0.06 |    8
 49837 |        23 |   0.48 | 149 |   -0.01 |  128 |   -0.27 |   50
 50249 |        24 |  -0.08 | 167 |   -0.38 |  140 |   -0.69 |   53
 56019 |        24 |   0.08 |  40 |   -0.62 |   38 |    -0.7 |   10
 54691 |        24 |   0.33 |  72 |   -0.07 |   61 |   -0.41 |   40
 52676 |        25 |  -0.17 |   5 |   -0.77 |    5 |    1.44 |    7
 50234 |        25 |   0.15 |  27 |   -0.25 |   25 |   -0.15 |   10
 55332 |        25 |   0.23 |  87 |   -0.37 |   74 |   -0.14 |   56
 55668 |        25 |   0.34 |  88 |    0.03 |   76 |    -0.5 |   43
 54752 |        25 |   0.64 | 328 |     0.3 |  277 |   -0.47 |  132
 58751 |        25 |   0.79 |  82 |    0.51 |   73 |    -1.7 |   19
 58049 |        25 |   1.14 | 200 |    0.61 |  169 |    0.09 |   61
 53943 |        25 |   3.31 |  19 |    3.93 |   19 |    0.31 |    5
 50344 |        26 |   0.33 |  20 |    0.03 |   16 |    0.27 |    6
 59136 |        26 |   0.37 |  43 |   -0.37 |   39 |   -1.06 |   20
 56141 |        26 |   0.38 | 390 |    0.05 |  318 |   -0.23 |  142
 50405 |        27 |    0.7 | 502 |    0.08 |  412 |    -0.1 |  269
 59209 |        27 |   0.84 |  83 |    0.27 |   77 |   -0.02 |   21
 60537 |        27 |   3.19 | 158 |     2.1 |  152 |     2.5 |  164
 54908 |        28 |   1.55 | 442 |    1.13 |  370 |    1.06 |  288
 57457 |        29 |   0.31 | 247 |    0.45 |  220 |    0.36 |   50
 54847 |        30 |   0.52 | 314 |    0.41 |  285 |   -0.26 |  215
 59197 |        30 |   1.48 | 117 |    0.54 |   99 |    0.15 |   44
(26 rows)

select c.percent_of_bins, round(avg(c.prmax)*100)/100. as avgprmax, round(avg(c.gvmax)*100)/100. as avggvmax, count(*) as ncases from zdiff_stats_by_dist_time_geo c, commongeogridbypct d where c.percent_of_bins=d.percent_of_bins and c.rangecat=d.rangecat and c.regime=d.regime and c.radar_id=d.radar_id and c.orbit=d.orbit and c.height=d.height and c.regime = 'C_above' group by 1 order by 1;
 percent_of_bins | avgprmax | avggvmax | ncases 
-----------------+----------+----------+--------
               0 |    36.74 |    36.88 |    123
              10 |    36.74 |    36.88 |    123
              20 |    36.84 |    36.98 |    122
              30 |    36.84 |    36.98 |    122
              40 |    36.94 |    37.12 |    120
              50 |    37.07 |    37.26 |    118
              60 |    37.19 |    37.38 |    114
              70 |    37.62 |    37.66 |    107
              80 |    38.08 |    38.02 |     97
              90 |    39.14 |    39.11 |     78
             100 |    39.52 |     39.5 |     64
(11 rows)

select c.percent_of_bins, round(avg(c.prmax)*100)/100. as avgprmax, round(avg(c.gvmax)*100)/100. as avggvmax, count(*) as ncases from zdiff_stats_by_dist_time_geo c, commongeogridbypct d where c.percent_of_bins=d.percent_of_bins and c.rangecat=d.rangecat and c.regime=d.regime and c.radar_id=d.radar_id and c.orbit=d.orbit and c.height=d.height and c.regime = 'S_above' group by 1 order by 1;
 percent_of_bins | avgprmax | avggvmax | ncases 
-----------------+----------+----------+--------
               0 |    25.71 |    26.34 |    101
              10 |    25.71 |    26.34 |    101
              20 |     25.7 |    26.21 |    101
              30 |    25.63 |    25.88 |    101
              40 |    25.63 |     25.8 |    100
              50 |    25.62 |    25.77 |     99
              60 |    25.76 |    25.79 |     94
              70 |    25.65 |    25.63 |     91
              80 |    25.75 |    25.76 |     84
              90 |    25.99 |    26.08 |     66
             100 |    25.87 |    26.18 |     52
(11 rows)

-- is the fraction of beam filling sensitive to the regime?
select c.percent_of_bins, c.regime, sum(c.numpts) from zdiff_stats_by_dist_time_geo c, commongeogridbypct d where c.percent_of_bins=d.percent_of_bins and c.rangecat=d.rangecat and c.regime=d.regime and c.radar_id=d.radar_id and c.orbit=d.orbit and c.height=d.height and c.percent_of_bins in (0,100) group by 1,2 order by 2,1;
 percent_of_bins | regime  |  sum  
-----------------+---------+-------
               0 | C_above |  4689
             100 | C_above |  1347
               0 | C_below |  5065
             100 | C_below |   888
               0 | C_in    |  2673
             100 | C_in    |   925
               0 | S_above |  8142
             100 | S_above |  1734
               0 | S_below | 13125
             100 | S_below |  2640
               0 | S_in    |  7631
             100 | S_in    |  2923
               0 | Total   | 72779
             100 | Total   | 18835
(14 rows)


-- get a common set of samples between 2A55 and REOR for KMLB, the only site
-- with all 11 geomatch pct_abv_thresh categories
drop table common2a55reo;
select a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp common2a55reo from dbzdiff_stats_by_dist a, dbzdiff_stats_by_dist b where a.rangecat<2 and a.radar_id = 'KMLB' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.gvtype='2A55' and b.gvtype='REOR';

-- get a common set of samples between 2A55, REOR, and geo-matches for KMLB
drop table commongeogridbypct;
select a.percent_of_bins, a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commongeogridbypct from zdiff_stats_by_dist_time_geo a, zdiff_stats_by_dist_time_geo_s2ku c, common2a55reo b where a.rangecat<2 and a.radar_id = 'KMLB' and a.percent_of_bins = 100 and a.regime not in ('Total') and a.numpts>4 and c.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and a.percent_of_bins = c.percent_of_bins;

-- All regimes broken out by site and regime, original vs. s2ku:

select a.radar_id, a.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as origmeandiff, sum(a.numpts) as n_orig, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as s2kumeandiff, sum(b.numpts) as n_s2ku from zdiff_stats_by_dist_time_geo a, zdiff_stats_by_dist_time_geo_s2ku b, commongeogridbypct c where  a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.percent_of_bins = b.percent_of_bins and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime group by 1,2 order by 2,1;

 radar_id | regime  | origmeandiff | n_orig | s2kumeandiff | n_s2ku 
----------+---------+--------------+--------+--------------+--------
 KMLB     | C_above |         0.16 |   1347 |         1.35 |   1347
 KMLB     | C_below |         1.36 |    888 |         -0.3 |    888
 KMLB     | C_in    |         0.62 |    925 |         0.62 |    925
 KMLB     | S_above |         0.24 |   1734 |         0.73 |   1734
 KMLB     | S_below |         1.33 |   2640 |         0.61 |   2640
 KMLB     | S_in    |        -0.72 |   2923 |        -0.72 |   2923
(6 rows)

