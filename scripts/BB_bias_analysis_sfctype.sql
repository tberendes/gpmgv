-- queries to investigate why biases are lower at the BB level

-- THIS VERSION BREAKS OUT RESULTS BY UNDERLYING SURFACE TYPE TO SEE
-- IF THE ATTENUATION ALGORITHM IS AN INFLUENCE

select radar_id, sfctype, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as mean_pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv, sum(numpts) as total into stratstatsfc from dbzdiff_stats_by_sfc_geo where percent_of_bins=100 and numpts>5 and regime like 'S_%' group by 1,2,3 order by 1,3,2;

-- number of cases where PR Z is higher below BB than at BB

select a.sfctype, count(*) from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_below' and b.regime = 'S_in' and a.mean_pr > b.mean_pr group by 1;

 sfctype | count
---------+-------
       2 |    20
       1 |    20
       0 |    15
(3 rows)

-- number of cases where GV Z is higher at BB level than below it

select a.sfctype, count(*) from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_below' and b.regime = 'S_in' and a.mean_gv < b.mean_gv group by 1;

 sfctype | count
---------+-------
       2 |    16
       1 |    14
       0 |    10
(3 rows)

-- number of sites where the BB bias is not lower than below the BB

select a.sfctype, count(*) from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff group by 1;

 sfctype | count
---------+-------
       2 |     1
       1 |     1
       0 |     1
(3 rows)

select a.sfctype, count(*) from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff group by 1;

 sfctype | count
---------+-------
       2 |     3
       1 |     1
       0 |     1
(3 rows)

-- sites where bias at BB is lower than bias above BB
select a.radar_id, a.sfctype, a.meanmeandiff as abovediff, b.meanmeandiff as bbdiff from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_above' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;

 radar_id | sfctype | abovediff | bbdiff
----------+---------+-----------+--------
 KDGX     |       2 |     -2.34 |  -1.89
 KJGX     |       2 |     -1.07 |  -1.03
 KWAJ     |       0 |     -1.88 |  -0.02
 RMOR     |       1 |     -0.22 |   0.64
 RMOR     |       2 |     -0.49 |   0.87
(5 rows)

-- sites where bias at BB is lower than bias below BB
select a.radar_id, a.sfctype, a.meanmeandiff as belowdiff, b.meanmeandiff as bbdiff from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_below' and b.regime = 'S_in' and a.meanmeandiff < b.meanmeandiff;

 radar_id | sfctype | belowdiff | bbdiff
----------+---------+-----------+--------
 KHTX     |       1 |     -1.47 |  -1.07
 KHTX     |       2 |     -1.49 |  -0.92
 KWAJ     |       0 |     -3.24 |  -0.02
(3 rows)

-- contributions of PR and GV profiles to the increase in negative bias at BB:
-- how much does the PR decrease (GV increase) from below BB to at BB?
select a.radar_id, a.sfctype, a.meanmeandiff as biasbelow, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as pr_part, round((a.mean_gv-b.mean_gv)*100.)/100. as gv_part from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_below' and b.regime = 'S_in';

-- how much does the PR decrease (GV increase) from above BB to at BB?
select a.radar_id, a.sfctype, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, b.meanmeandiff-a.meanmeandiff as diffchg, round((b.mean_pr-a.mean_pr)*100.)/100. as pr_part, round((a.mean_gv-b.mean_gv)*100.)/100. as gv_part from stratstatsfc a, stratstatsfc b where a.radar_id=b.radar_id and a.sfctype=b.sfctype and a.regime='S_above' and b.regime = 'S_in';

-- How does the reflectivity at the BB compare to the mean of the above and below BB Zs?
select a.radar_id, a.sfctype, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))*100.)/100. as pr_part, round((2.0*b.mean_gv-(a.mean_gv+c.mean_gv))*100.)/100. as gv_part from stratstatsfc a, stratstatsfc b, stratstatsfc c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.sfctype=b.sfctype and a.sfctype=c.sfctype and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below';

select a.radar_id, a.sfctype, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round( ((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))/(2.0*b.mean_gv-(a.mean_gv+c.mean_gv)))*100.)/100. as relative_chg from stratstatsfc a, stratstatsfc b, stratstatsfc c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.sfctype=b.sfctype and a.sfctype=c.sfctype and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below'; 

select a.radar_id, d.sfctext, a.meanmeandiff as biasabove, b.meanmeandiff as biasbb, c.meanmeandiff as biasbelow, round( ((2.0*b.mean_pr-(a.mean_pr+c.mean_pr))/(2.0*b.mean_gv-(a.mean_gv+c.mean_gv)))*100.)/100. as relative_chg, a.total from stratstatsfc a, stratstatsfc b, stratstatsfc c, surface_type d where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.sfctype=b.sfctype and a.sfctype=c.sfctype and a.regime='S_above' and b.regime = 'S_in' and c.regime = 'S_below' and  a.sfctype=d.sfctype;

