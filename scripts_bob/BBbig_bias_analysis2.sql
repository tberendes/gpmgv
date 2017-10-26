-- queries to investigate why biases are lower at the BB level

-- make sure we are taking matched sets (e.g., > 5 points at all BB-respective levels for each orbit)
select radar_id, regime, orbit, sum(numpts) as total into temp countbyperm3 from dbzdiff_stats_by_dist_geo_bb where percent_of_bins=95 and regime like 'S_%' group by 1,2,3 order by 1,2,3;

select radar_id, orbit, min(total) as minbylev into temp countbyperm2 from countbyperm3 group by 1,2 order by 1,2;

select a.radar_id, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as mean_pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv, sum(numpts) as total into stratstats_bb from dbzdiff_stats_by_dist_geo_bb a, countbyperm2 b where a.radar_id=b.radar_id and a.orbit=b.orbit and percent_of_bins=95 and minbylev > 24 and regime like 'S_%' group by 1,2 order by 1,2;

select radar_id, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as mean_pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv, sum(numpts) as total into stratstats_bb from dbzdiff_stats_by_dist_geo_bb where percent_of_bins=95 and numpts>5 and regime like 'S_%' group by 1,2 order by 1,2;

-- number of cases where PR Z is higher below BB than at BB

select count(*) from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.mean_pr > b.mean_pr;


-- number of cases where GV Z is higher at BB level than below it

select count(*) from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.mean_gv < b.mean_gv;


-- number of sites where the PR-GV bias is greater at the BB than below

 select count(*) from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;


-- number of sites where the PR-GV bias is greater at the BB than above

select count(*) from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;


-- sites where bias at BB is lower than bias above BB
select a.radar_id, a.meanmeandiff as abovediff, b.meanmeandiff as bbdiff from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;


-- sites where bias at BB is lower than bias below BB
select a.radar_id, a.meanmeandiff as belowdiff, b.meanmeandiff as bbdiff from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;


-- contributions of PR and GV profiles to the increase in negative bias at BB:
-- how much do the Zs drop off (if -) or jump (if +) from below BB to at BB?
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as prchgblo2bb, round((b.mean_gv-a.mean_gv)*100.)/100. as gvchgblo2bb from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in';

 radar_id | biasbelow | biasbb | diffchg | prchgblo2bb | gvchgblo2bb 
----------+-----------+--------+---------+-------------+-------------
 KAMX     |     -0.18 |  -1.58 |    -1.4 |       -2.07 |       -0.68
 KBMX     |     -1.32 |  -2.39 |   -1.07 |       -0.31 |        0.77
 KBRO     |     -0.43 |  -2.41 |   -1.98 |       -0.04 |        1.93
 KBYX     |     -0.64 |  -1.92 |   -1.28 |       -0.79 |        0.49
 KCLX     |     -0.67 |  -2.55 |   -1.88 |       -0.74 |        1.15
 KCRP     |      0.29 |  -1.45 |   -1.74 |       -1.75 |       -0.02
 KDGX     |     -0.75 |  -1.54 |   -0.79 |       -0.65 |        0.14
 KEVX     |         1 |  -0.54 |   -1.54 |       -0.95 |        0.59
 KFWS     |      1.41 |  -0.44 |   -1.85 |       -0.88 |        0.97
 KGRK     |      2.71 |   1.39 |   -1.32 |       -1.62 |        -0.3
 KHGX     |      0.76 |  -1.43 |   -2.19 |       -2.69 |       -0.49
 KHTX     |     -0.84 |  -0.71 |    0.13 |        0.21 |        0.08
 KJAX     |       0.5 |  -1.98 |   -2.48 |       -1.45 |        1.03
 KJGX     |      0.64 |  -0.96 |    -1.6 |       -0.88 |        0.73
 KLCH     |     -1.35 |  -3.16 |   -1.81 |       -0.86 |        0.95
 KLIX     |     -1.01 |  -2.96 |   -1.95 |       -1.74 |         0.2
 KMLB     |      1.53 |  -0.69 |   -2.22 |       -2.06 |        0.17
 KMOB     |      0.36 |  -1.02 |   -1.38 |       -1.11 |        0.25
 KSHV     |     -1.16 |  -2.47 |   -1.31 |       -0.58 |        0.73
 KTBW     |     -0.84 |  -2.68 |   -1.84 |       -2.28 |       -0.43
 KTLH     |     -1.76 |  -3.04 |   -1.28 |       -0.37 |        0.91
 KWAJ     |     -3.91 |  -2.28 |    1.63 |       -0.97 |        -2.6
 RGSN     |      3.06 |   1.83 |   -1.23 |        -0.7 |        0.52
 RMOR     |      1.12 |   0.63 |   -0.49 |        1.03 |        1.53

-- how much do the PR and GV increase from above BB to at BB?
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as prchgabv2bb, round((b.mean_gv-a.mean_gv)*100.)/100. as gvchgabv2bb from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

 radar_id | biasabove | biasbb | diffchg | prchgabv2bb | gvchgabv2bb 
----------+-----------+--------+---------+-------------+-------------
 KAMX     |     -0.49 |  -1.58 |   -1.09 |        5.55 |        6.63
 KBMX     |     -1.47 |  -2.39 |   -0.92 |        5.88 |         6.8
 KBRO     |     -1.12 |  -2.41 |   -1.29 |        5.66 |        6.95
 KBYX     |     -0.49 |  -1.92 |   -1.43 |        4.93 |        6.36
 KCLX     |     -1.42 |  -2.55 |   -1.13 |        5.65 |        6.79
 KCRP     |     -0.03 |  -1.45 |   -1.42 |        4.63 |        6.06
 KDGX     |     -0.53 |  -1.54 |   -1.01 |        5.57 |        6.58
 KEVX     |     -0.68 |  -0.54 |    0.14 |        7.39 |        7.25
 KFWS     |      0.43 |  -0.44 |   -0.87 |        5.46 |        6.32
 KGRK     |      2.19 |   1.39 |    -0.8 |        6.58 |        7.39
 KHGX     |     -0.68 |  -1.43 |   -0.75 |        5.48 |        6.24
 KHTX     |     -0.16 |  -0.71 |   -0.55 |        5.62 |        6.17
 KJAX     |     -1.33 |  -1.98 |   -0.65 |        5.88 |        6.52
 KJGX     |      0.17 |  -0.96 |   -1.13 |        5.98 |        7.11
 KLCH     |     -2.06 |  -3.16 |    -1.1 |        5.94 |        7.04
 KLIX     |     -2.15 |  -2.96 |   -0.81 |        5.94 |        6.75
 KMLB     |      0.26 |  -0.69 |   -0.95 |        4.69 |        5.64
 KMOB     |       0.5 |  -1.02 |   -1.52 |        6.23 |        7.74
 KSHV     |     -1.71 |  -2.47 |   -0.76 |        5.46 |        6.22
 KTBW     |     -1.62 |  -2.68 |   -1.06 |           5 |        6.07
 KTLH     |     -2.34 |  -3.04 |    -0.7 |         5.6 |         6.3
 KWAJ     |     -3.83 |  -2.28 |    1.55 |        6.34 |        4.78
 RGSN     |      2.03 |   1.83 |    -0.2 |        5.15 |        5.35
 RMOR     |     -0.07 |   0.63 |     0.7 |        5.05 |        4.35
(24 rows)

-- ratios of mean Z, (below BB) / (at BB)  If < 1, then BB is warmer than below
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((a.mean_pr/b.mean_pr)*100.)/100. as pr_blo_ovr_in, round((a.mean_gv/b.mean_gv)*100.)/100. as gv_blo_ovr_in from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in';

 radar_id | biasbelow | biasbb | diffchg | pr_blo_ovr_in | gv_blo_ovr_in 
----------+-----------+--------+---------+---------------+---------------
 KAMX     |     -0.18 |  -1.58 |    -1.4 |          1.07 |          1.02
 KBMX     |     -1.32 |  -2.39 |   -1.07 |          1.01 |          0.98
 KBRO     |     -0.43 |  -2.41 |   -1.98 |             1 |          0.94
 KBYX     |     -0.64 |  -1.92 |   -1.28 |          1.03 |          0.98
 KCLX     |     -0.67 |  -2.55 |   -1.88 |          1.03 |          0.96
 KCRP     |      0.29 |  -1.45 |   -1.74 |          1.06 |             1
 KDGX     |     -0.75 |  -1.54 |   -0.79 |          1.02 |             1
 KEVX     |         1 |  -0.54 |   -1.54 |          1.03 |          0.98
 KFWS     |      1.41 |  -0.44 |   -1.85 |          1.03 |          0.97
 KGRK     |      2.71 |   1.39 |   -1.32 |          1.05 |          1.01
 KHGX     |      0.76 |  -1.43 |   -2.19 |          1.09 |          1.02
 KHTX     |     -0.84 |  -0.71 |    0.13 |          0.99 |             1
 KJAX     |       0.5 |  -1.98 |   -2.48 |          1.05 |          0.97
 KJGX     |      0.64 |  -0.96 |    -1.6 |          1.03 |          0.98
 KLCH     |     -1.35 |  -3.16 |   -1.81 |          1.03 |          0.97
 KLIX     |     -1.01 |  -2.96 |   -1.95 |          1.06 |          0.99
 KMLB     |      1.53 |  -0.69 |   -2.22 |          1.08 |          0.99
 KMOB     |      0.36 |  -1.02 |   -1.38 |          1.04 |          0.99
 KSHV     |     -1.16 |  -2.47 |   -1.31 |          1.02 |          0.98
 KTBW     |     -0.84 |  -2.68 |   -1.84 |          1.08 |          1.01
 KTLH     |     -1.76 |  -3.04 |   -1.28 |          1.01 |          0.97
 KWAJ     |     -3.91 |  -2.28 |    1.63 |          1.03 |          1.08
 RGSN     |      3.06 |   1.83 |   -1.23 |          1.02 |          0.98
 RMOR     |      1.12 |   0.63 |   -0.49 |          0.96 |          0.95
(24 rows)

-- how much does the PR decrease (GV increase) from above BB to at BB?
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as pr_part, round((a.mean_gv-b.mean_gv)*100.)/100. as gv_part from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

-- ratios of mean Z, (above BB) / (at BB)  If < 1, then BB is warmer than above
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((a.mean_pr/b.mean_pr)*100.)/100. as pr_abv_ovr_in, round((a.mean_gv/b.mean_gv)*100.)/100. as gv_abv_ovr_in from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

 radar_id | biasabove | biasbb | diffchg | pr_abv_ovr_in | gv_abv_ovr_in 
----------+-----------+--------+---------+---------------+---------------
 KAMX     |     -0.49 |  -1.58 |   -1.09 |           0.8 |          0.78
 KBMX     |     -1.47 |  -2.39 |   -0.92 |           0.8 |          0.79
 KBRO     |     -1.12 |  -2.41 |   -1.29 |           0.8 |          0.78
 KBYX     |     -0.49 |  -1.92 |   -1.43 |          0.82 |          0.79
 KCLX     |     -1.42 |  -2.55 |   -1.13 |          0.81 |          0.79
 KCRP     |     -0.03 |  -1.45 |   -1.42 |          0.83 |          0.79
 KDGX     |     -0.53 |  -1.54 |   -1.01 |          0.81 |          0.79
 KEVX     |     -0.68 |  -0.54 |    0.14 |          0.76 |          0.77
 KFWS     |      0.43 |  -0.44 |   -0.87 |          0.81 |          0.79
 KGRK     |      2.19 |   1.39 |    -0.8 |          0.79 |          0.75
 KHGX     |     -0.68 |  -1.43 |   -0.75 |          0.81 |          0.79
 KHTX     |     -0.16 |  -0.71 |   -0.55 |          0.81 |           0.8
 KJAX     |     -1.33 |  -1.98 |   -0.65 |           0.8 |          0.79
 KJGX     |      0.17 |  -0.96 |   -1.13 |           0.8 |          0.77
 KLCH     |     -2.06 |  -3.16 |    -1.1 |           0.8 |          0.78
 KLIX     |     -2.15 |  -2.96 |   -0.81 |           0.8 |          0.79
 KMLB     |      0.26 |  -0.69 |   -0.95 |          0.83 |           0.8
 KMOB     |       0.5 |  -1.02 |   -1.52 |          0.79 |          0.75
 KSHV     |     -1.71 |  -2.47 |   -0.76 |          0.81 |           0.8
 KTBW     |     -1.62 |  -2.68 |   -1.06 |          0.82 |           0.8
 KTLH     |     -2.34 |  -3.04 |    -0.7 |          0.81 |           0.8
 KWAJ     |     -3.83 |  -2.28 |    1.55 |          0.78 |          0.85
 RGSN     |      2.03 |   1.83 |    -0.2 |          0.82 |           0.8
 RMOR     |     -0.07 |   0.63 |     0.7 |          0.83 |          0.85
(24 rows)

-- How does the reflectivity at the BB compare to the mean of the above and below BB Zs?
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))*100.)/100. as pr_part, round((2.0*b.mean_gv-(a.mean_gv+c.mean_gv))*100.)/100. as gv_part from stratstats_bb a, stratstats_bb b, stratstats_bb c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below';

select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round( ((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))/(2.0*b.mean_gv-(a.mean_gv+c.mean_gv)))*100.)/100. as relative_chg from stratstats_bb a, stratstats_bb b, stratstats_bb c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below';

 radar_id | biasabove | biasbb | biasbelow | relative_chg 
----------+-----------+--------+-----------+--------------
 KAMX     |     -0.49 |  -1.58 |     -0.18 |         0.58
 KBMX     |     -1.47 |  -2.39 |     -1.32 |         0.74
 KBRO     |     -1.12 |  -2.41 |     -0.43 |         0.63
 KBYX     |     -0.49 |  -1.92 |     -0.64 |          0.6
 KCLX     |     -1.42 |  -2.55 |     -0.67 |         0.62
 KCRP     |     -0.03 |  -1.45 |      0.29 |         0.48
 KDGX     |     -0.53 |  -1.54 |     -0.75 |         0.73
 KEVX     |     -0.68 |  -0.54 |         1 |         0.82
 KFWS     |      0.43 |  -0.44 |      1.41 |         0.63
 KGRK     |      2.19 |   1.39 |      2.71 |          0.7
 KHGX     |     -0.68 |  -1.43 |      0.76 |         0.49
 KHTX     |     -0.16 |  -0.71 |     -0.84 |         0.93
 KJAX     |     -1.33 |  -1.98 |       0.5 |         0.59
 KJGX     |      0.17 |  -0.96 |      0.64 |         0.65
 KLCH     |     -2.06 |  -3.16 |     -1.35 |         0.64
 KLIX     |     -2.15 |  -2.96 |     -1.01 |          0.6
 KMLB     |      0.26 |  -0.69 |      1.53 |         0.45
 KMOB     |       0.5 |  -1.02 |      0.36 |         0.64
 KSHV     |     -1.71 |  -2.47 |     -1.16 |          0.7
 KTBW     |     -1.62 |  -2.68 |     -0.84 |         0.48
 KTLH     |     -2.34 |  -3.04 |     -1.76 |         0.73
 KWAJ     |     -3.83 |  -2.28 |     -3.91 |         2.46
 RGSN     |      2.03 |   1.83 |      3.06 |         0.76
 RMOR     |     -0.07 |   0.63 |      1.12 |         1.03
(24 rows)


-- as above, but for above/within only
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, round( ((b.mean_pr-a.mean_pr)/(b.mean_gv-a.mean_gv))*100.)/100. as relative_chg from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

 radar_id | biasabove | biasbb | relative_chg 
----------+-----------+--------+--------------
 KAMX     |     -0.49 |  -1.58 |         0.84
 KBMX     |     -1.47 |  -2.39 |         0.86
 KBRO     |     -1.12 |  -2.41 |         0.81
 KBYX     |     -0.49 |  -1.92 |         0.78
 KCLX     |     -1.42 |  -2.55 |         0.83
 KCRP     |     -0.03 |  -1.45 |         0.76
 KDGX     |     -0.53 |  -1.54 |         0.85
 KEVX     |     -0.68 |  -0.54 |         1.02
 KFWS     |      0.43 |  -0.44 |         0.86
 KGRK     |      2.19 |   1.39 |         0.89
 KHGX     |     -0.68 |  -1.43 |         0.88
 KHTX     |     -0.16 |  -0.71 |         0.91
 KJAX     |     -1.33 |  -1.98 |          0.9
 KJGX     |      0.17 |  -0.96 |         0.84
 KLCH     |     -2.06 |  -3.16 |         0.84
 KLIX     |     -2.15 |  -2.96 |         0.88
 KMLB     |      0.26 |  -0.69 |         0.83
 KMOB     |       0.5 |  -1.02 |          0.8
 KSHV     |     -1.71 |  -2.47 |         0.88
 KTBW     |     -1.62 |  -2.68 |         0.82
 KTLH     |     -2.34 |  -3.04 |         0.89
 KWAJ     |     -3.83 |  -2.28 |         1.33
 RGSN     |      2.03 |   1.83 |         0.96
 RMOR     |     -0.07 |   0.63 |         1.16
(24 rows)


-- as above, but for below/within only
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, round( ((b.mean_pr-a.mean_pr)/(b.mean_gv-a.mean_gv))*100.)/100. as relative_chg from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in';

 radar_id | biasbelow | biasbb | relative_chg 
----------+-----------+--------+--------------
 KAMX     |     -0.18 |  -1.58 |         3.04
 KBMX     |     -1.32 |  -2.39 |         -0.4
 KBRO     |     -0.43 |  -2.41 |        -0.02
 KBYX     |     -0.64 |  -1.92 |        -1.61
 KCLX     |     -0.67 |  -2.55 |        -0.64
 KCRP     |      0.29 |  -1.45 |         87.5
 KDGX     |     -0.75 |  -1.54 |        -4.64
 KEVX     |         1 |  -0.54 |        -1.61
 KFWS     |      1.41 |  -0.44 |        -0.91
 KGRK     |      2.71 |   1.39 |          5.4
 KHGX     |      0.76 |  -1.43 |         5.49
 KHTX     |     -0.84 |  -0.71 |         2.63
 KJAX     |       0.5 |  -1.98 |        -1.41
 KJGX     |      0.64 |  -0.96 |        -1.21
 KLCH     |     -1.35 |  -3.16 |        -0.91
 KLIX     |     -1.01 |  -2.96 |         -8.7
 KMLB     |      1.53 |  -0.69 |       -12.12
 KMOB     |      0.36 |  -1.02 |        -4.44
 KSHV     |     -1.16 |  -2.47 |        -0.79
 KTBW     |     -0.84 |  -2.68 |          5.3
 KTLH     |     -1.76 |  -3.04 |        -0.41
 KWAJ     |     -3.91 |  -2.28 |         0.37
 RGSN     |      3.06 |   1.83 |        -1.35
 RMOR     |      1.12 |   0.63 |         0.67
(24 rows)


-- as above, but for above/below only - which has the steeper dBZ profile: PR (>1) or GV (<1)
select a.radar_id, b.meanmeandiff as biasbelow, a.meanmeandiff as biasabove, round( ((a.mean_pr-b.mean_pr)/(a.mean_gv-b.mean_gv))*100.)/100. as relative_chg from stratstats_bb a, stratstats_bb b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_below';

 radar_id | biasbelow | biasabove | relative_chg 
----------+-----------+-----------+--------------
 KAMX     |     -0.18 |     -0.49 |         1.04
 KBMX     |     -1.32 |     -1.47 |         1.03
 KBRO     |     -0.43 |     -1.12 |         1.14
 KBYX     |     -0.64 |     -0.49 |         0.97
 KCLX     |     -0.67 |     -1.42 |         1.13
 KCRP     |      0.29 |     -0.03 |         1.05
 KDGX     |     -0.75 |     -0.53 |         0.97
 KEVX     |         1 |     -0.68 |         1.25
 KFWS     |      1.41 |      0.43 |         1.19
 KGRK     |      2.71 |      2.19 |         1.07
 KHGX     |      0.76 |     -0.68 |         1.21
 KHTX     |     -0.84 |     -0.16 |         0.89
 KJAX     |       0.5 |     -1.33 |         1.34
 KJGX     |      0.64 |      0.17 |         1.08
 KLCH     |     -1.35 |     -2.06 |         1.12
 KLIX     |     -1.01 |     -2.15 |         1.17
 KMLB     |      1.53 |      0.26 |         1.23
 KMOB     |      0.36 |       0.5 |         0.98
 KSHV     |     -1.16 |     -1.71 |          1.1
 KTBW     |     -0.84 |     -1.62 |         1.12
 KTLH     |     -1.76 |     -2.34 |         1.11
 KWAJ     |     -3.91 |     -3.83 |         0.99
 RGSN     |      3.06 |      2.03 |         1.21
 RMOR     |      1.12 |     -0.07 |         1.43
(24 rows)

-- number of cases where BB mean Z is greater than below BB mean Z, for PR and GV
-- - first get stats by event
select radar_id, orbit, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as mean_pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv, sum(numpts) as total into stratstats_bb_byorb from dbzdiff_stats_by_dist_geo_bb where percent_of_bins=95 and numpts>0 and regime like 'S_%' group by 1,2,3 order by 1,2,3;

select a.radar_id, count(*) as nprbbgtblo into temp prbbgtblo from stratstats_bb_byorb a, stratstats_bb_byorb b where a.radar_id = b.radar_id and a.orbit = b.orbit and a.regime = 'S_in' and b.regime='S_below' and a.mean_pr > b.mean_pr group by 1 order by 1;

select a.radar_id, count(*) as nprbbltblo into temp prbbltblo from stratstats_bb_byorb a, stratstats_bb_byorb b where a.radar_id = b.radar_id and a.orbit = b.orbit and a.regime = 'S_in' and b.regime='S_below' and a.mean_pr <  b.mean_pr group by 1 order by 1;

select a.radar_id, count(*) as ngvbbgtblo into temp gvbbgtblo from stratstats_bb_byorb a, stratstats_bb_byorb b where a.radar_id = b.radar_id and a.orbit = b.orbit and a.regime = 'S_in' and b.regime='S_below' and a.mean_gv > b.mean_gv group by 1 order by 1;

select a.radar_id, count(*) as ngvbbltblo into temp gvbbltblo from stratstats_bb_byorb a, stratstats_bb_byorb b where a.radar_id = b.radar_id and a.orbit = b.orbit and a.regime = 'S_in' and b.regime='S_below' and a.mean_gv <  b.mean_gv group by 1 order by 1;

select a.radar_id, a.nprbbgtblo, b.nprbbltblo, c.ngvbbgtblo, d.ngvbbltblo from prbbgtblo a, prbbltblo b, gvbbgtblo c, gvbbltblo d where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.radar_id=d.radar_id;

 radar_id | nprbbgtblo | nprbbltblo | ngvbbgtblo | ngvbbltblo 
----------+------------+------------+------------+------------
 KAMX     |          6 |         62 |         21 |         47
 KBMX     |         45 |         91 |         72 |         65
 KBRO     |         15 |         32 |         26 |         21
 KBYX     |         16 |         41 |         20 |         37
 KCLX     |         30 |         91 |         63 |         58
 KCRP     |          9 |         43 |         21 |         31
 KDGX     |         41 |         70 |         56 |         54
 KEVX     |         14 |         66 |         40 |         40
 KFWS     |         23 |         87 |         57 |         54
 KGRK     |         11 |         50 |         21 |         40
 KHGX     |         12 |         54 |         22 |         44
 KHTX     |         62 |         90 |         56 |         97
 KJAX     |         15 |         56 |         46 |         25
 KJGX     |         50 |         79 |         72 |         57
 KLCH     |         15 |         60 |         27 |         48
 KLIX     |         17 |         76 |         42 |         52
 KMLB     |          8 |         66 |         23 |         51
 KMOB     |         20 |         67 |         36 |         51
 KSHV     |         38 |         77 |         64 |         51
 KTBW     |          6 |         63 |         25 |         44
 KTLH     |         18 |         64 |         39 |         43
 KWAJ     |          6 |         24 |          2 |         28
 RGSN     |         26 |         34 |         46 |         14
 RMOR     |          6 |         10 |          8 |          8
(24 rows)

