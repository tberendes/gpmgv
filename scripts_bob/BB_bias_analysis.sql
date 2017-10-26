-- queries to investigate why biases are lower at the BB level

select radar_id, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as mean_pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv, sum(numpts) as total into stratstats from dbzdiff_stats_by_dist_geo where percent_of_bins=95 and numpts>5 and regime like 'S_%' group by 1,2 order by 1,2;

-- number of cases where PR Z is higher below BB than at BB

select count(*) from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.mean_pr > b.mean_pr;

 count 
-------
    21

-- number of cases where GV Z is higher at BB level than below it

select count(*) from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.mean_gv < b.mean_gv;
 count 
-------
    15
(1 row)

-- number of sites where the BB bias is not lower than below the BB

 select count(*) from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;
 count 
-------
     2

select count(*) from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;
 count 
-------
     2

-- sites where bias at BB is lower than bias above BB
select a.radar_id, a.meanmeandiff as abovediff, b.meanmeandiff as bbdiff from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;
 radar_id | abovediff | bbdiff 
----------+-----------+--------
 KWAJ     |     -1.35 |   0.01
 RMOR     |      0.13 |   0.81
(2 rows)

-- sites where bias at BB is lower than bias below BB
select a.radar_id, a.meanmeandiff as belowdiff, b.meanmeandiff as bbdiff from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;
 radar_id | belowdiff | bbdiff 
----------+-----------+--------
 KHTX     |     -1.39 |   -0.8
 KWAJ     |     -3.13 |   0.01
(2 rows)

-- contributions of PR and GV profiles to the increase in negative bias at BB:
-- how much does the PR decrease (GV increase) from below BB to at BB?
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as pr_part, round((a.mean_gv-b.mean_gv)*100.)/100. as gv_part from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in';

-- how much does the PR decrease (GV increase) from above BB to at BB?
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as pr_part, round((a.mean_gv-b.mean_gv)*100.)/100. as gv_part from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

-- How does the reflectivity at the BB compare to the mean of the above and below BB Zs?
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))*100.)/100. as pr_part, round((2.0*b.mean_gv-(a.mean_gv+c.mean_gv))*100.)/100. as gv_part from stratstats a, stratstats b, stratstats c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below';

select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round( ((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))/(2.0*b.mean_gv-(a.mean_gv+c.mean_gv)))*100.)/100. as relative_chg from stratstats a, stratstats b, stratstats c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below';


 radar_id | biasabove | biasbb | biasbelow | relative_chg 
----------+-----------+--------+-----------+--------------
 KAMX     |      -0.6 |  -1.58 |     -0.24 |         0.39
 KBMX     |     -1.78 |  -2.61 |     -1.93 |         0.64
 KBRO     |     -1.27 |  -2.59 |     -0.61 |         0.45
 KBYX     |     -0.74 |  -1.94 |     -0.82 |         0.49
 KCLX     |     -1.31 |  -2.34 |     -0.79 |         0.57
 KCRP     |     -0.09 |  -1.27 |     -0.01 |         0.35
 KDGX     |     -1.19 |  -1.82 |     -1.01 |         0.69
 KEVX     |     -0.76 |  -1.06 |      0.22 |          0.7
 KFWS     |      0.22 |  -0.55 |      1.04 |         0.55
 KGRK     |      1.81 |   1.32 |      2.12 |         0.58
 KHGX     |     -1.17 |  -1.73 |      0.38 |         0.24
 KHTX     |     -0.78 |   -0.8 |     -1.39 |         1.17
 KJAX     |      -1.3 |  -1.84 |       0.6 |         0.52
 KJGX     |      0.05 |   -0.8 |      0.45 |         0.61
 KLCH     |     -2.59 |  -3.16 |     -1.41 |         0.46
 KLIX     |     -2.62 |  -2.94 |     -1.38 |         0.51
 KMLB     |      0.23 |  -0.79 |       1.3 |         0.26
 KMOB     |      0.52 |  -0.34 |      0.35 |         0.59
 KSHV     |     -1.93 |  -2.53 |     -1.36 |         0.66
 KTBW     |     -1.61 |  -2.42 |     -0.95 |         0.18
 KTLH     |     -2.45 |     -3 |     -1.63 |         0.59
 KWAJ     |     -1.35 |   0.01 |     -3.13 |        15.09
 RGSN     |      2.13 |   1.62 |      3.11 |         0.66
 RMOR     |      0.13 |   0.81 |       1.4 |         1.02
(24 rows)

-- as above, but for above/within only
select a.radar_id, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, round( ((b.mean_pr-a.mean_pr)/(b.mean_gv-a.mean_gv))*100.)/100. as relative_chg from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_in';

 radar_id | biasabove | biasbb | relative_chg
----------+-----------+--------+--------------
 KAMX     |      -0.6 |  -1.58 |         0.76
 KBMX     |     -1.78 |  -2.61 |         0.77
 KBRO     |     -1.27 |  -2.59 |         0.72
 KBYX     |     -0.74 |  -1.94 |         0.72
 KCLX     |     -1.31 |  -2.34 |         0.78
 KCRP     |     -0.09 |  -1.27 |          0.7
 KDGX     |     -1.19 |  -1.82 |         0.85
 KEVX     |     -0.76 |  -1.06 |         0.93
 KFWS     |      0.22 |  -0.55 |         0.83
 KGRK     |      1.81 |   1.32 |         0.89
 KHGX     |     -1.17 |  -1.73 |         0.84
 KHTX     |     -0.78 |   -0.8 |         0.99
 KJAX     |      -1.3 |  -1.84 |         0.89
 KJGX     |      0.05 |   -0.8 |         0.82
 KLCH     |     -2.59 |  -3.16 |         0.84
 KLIX     |     -2.62 |  -2.94 |         0.91
 KMLB     |      0.23 |  -0.79 |         0.77
 KMOB     |      0.52 |  -0.34 |         0.82
 KSHV     |     -1.93 |  -2.53 |         0.86
 KTBW     |     -1.61 |  -2.42 |         0.75
 KTLH     |     -2.45 |     -3 |         0.85
 KWAJ     |     -1.35 |   0.01 |         1.43
 RGSN     |      2.13 |   1.62 |          0.9
 RMOR     |      0.13 |   0.81 |         1.19
(24 rows)


-- as above, but for below/within only
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, round( ((b.mean_pr-a.mean_pr)/(b.mean_gv-a.mean_gv))*100.)/100. as relative_chg from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_below' and b.regime = 'S_in';

 radar_id | biasbelow | biasbb | relative_chg
----------+-----------+--------+--------------
 KAMX     |     -0.24 |  -1.58 |         5.47
 KBMX     |     -1.93 |  -2.61 |        -0.17
 KBRO     |     -0.61 |  -2.59 |        -0.48
 KBYX     |     -0.82 |  -1.94 |        -3.27
 KCLX     |     -0.79 |  -2.34 |        -0.24
 KCRP     |     -0.01 |  -1.27 |         7.63
 KDGX     |     -1.01 |  -1.82 |        -0.56
 KEVX     |      0.22 |  -1.06 |         -0.8
 KFWS     |      1.04 |  -0.55 |        -1.01
 KGRK     |      2.12 |   1.32 |         1.62
 KHGX     |      0.38 |  -1.73 |         43.4
 KHTX     |     -1.39 |   -0.8 |        -1.36
 KJAX     |       0.6 |  -1.84 |        -0.65
 KJGX     |      0.45 |   -0.8 |        -1.05
 KLCH     |     -1.41 |  -3.16 |        -1.57
 KLIX     |     -1.38 |  -2.94 |           -5
 KMLB     |       1.3 |  -0.79 |        15.93
 KMOB     |      0.35 |  -0.34 |         1.73
 KSHV     |     -1.36 |  -2.53 |        -0.09
 KTBW     |     -0.95 |  -2.42 |          4.2
 KTLH     |     -1.63 |     -3 |        -0.37
 KWAJ     |     -3.13 |   0.01 |        -0.09
 RGSN     |      3.11 |   1.62 |        -0.43
 RMOR     |       1.4 |   0.81 |         0.58
(24 rows)


-- as above, but for above/below only
select a.radar_id, a.meanmeandiff as biasbelow, b.meanmeandiff as biasabove, round( ((a.mean_pr-b.mean_pr)/(a.mean_gv-b.mean_gv))*100.)/100. as relative_chg from stratstats a, stratstats b where a.radar_id=b.radar_id and a.regime='S_above' and b.regime = 'S_below';
