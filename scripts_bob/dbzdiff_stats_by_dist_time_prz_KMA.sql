-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table zdiff_stats_by_dist_time_prz_kma (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   przcat float,
   timediff integer,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, przcat, timediff)
);


create table zdiff_stats_by_dist_time_prz_kma_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   przcat float,
   timediff integer,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, przcat, timediff)
);

delete from zdiff_stats_by_dist_time_prz_kma;
\copy zdiff_stats_by_dist_time_prz_kma from '/data/gpmgv/tmp/StatsBy_PR_Z_ToDBGeo_Pct90_KMA_BBW500m_DefaultS.unl' with delimiter '|' 
delete from zdiff_stats_by_dist_time_prz_kma_s2ku;
\copy zdiff_stats_by_dist_time_prz_kma_s2ku from '/data/gpmgv/tmp/StatsBy_PR_Z_ToDBGeo_Pct90_KMA_BBW500m_S2Ku.unl' with delimiter '|' 


-- differences and profiles by przcat/percent:
select przcat, percent_of_bins, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanprv, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangr, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime like 'C_%' and numpts>5 and radar_id='KMLB' group by 1,2 order by 1,2;
select percent_of_bins, rangecat, gvtype, radar_id, orbit, przcat, sum(numpts) as totalany into temp anytotal from zdiff_stats_by_dist_time_prz_kma where regime='Total' group by 1,2,3,4,5,6;


select percent_of_bins, rangecat, gvtype, radar_id, orbit, przcat, sum(numpts) as totaltypes into temp totalbytypes from zdiff_stats_by_dist_time_prz_kma where regime!='Total' group by 1,2,3,4,5,6;

select a.*, b.totaltypes from anytotal a, totalbytypes b where a.percent_of_bins = b.percent_of_bins and a.rangecat = b.rangecat and a.gvtype = b.gvtype and a.radar_id = b.radar_id and a.orbit = b.orbit and a.przcat = b.przcat and a.totalany < b.totaltypes;

-- "Best" bias regime (stratiform above BB), broken out by site and range:
select radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 and percent_of_bins=100 group by 1,2 order by 1,2;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinmax/10)*10+5 as grmaxz, regime, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime like 'S%' and numpts>0 group by 3,2 order by 1;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinstddev/3)*3 as stddev, regime, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime like 'S%' and numpts>5 group by 3,2 order by 3,2;
 meanmeandiff | stddev | regime  | total 
--------------+--------+---------+-------
        -1.35 |      3 | S_above | 24893
        -1.49 |      6 | S_above | 10716
        -0.11 |      9 | S_above |   310
         -0.1 |      3 | S_below |  3492
        -0.21 |      6 | S_below | 20926
         0.23 |      9 | S_below |  1252
         -1.4 |      3 | S_in    |  9494
         -1.4 |      6 | S_in    | 82489
        -1.66 |      9 | S_in    |  5707
(9 rows)

-- "Best" bias regime (stratiform above BB), broken out by site only:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 group by 1 order by 1;

-- As above, but by PR Z categories also
select radar_id, przcat, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 group by 1,2 order by 1,2;

-- As above, but output to HTML table
\o /data/tmp/BiasByDistance.html \\select radar_id, rangecat*50+25 as mean_range_km, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 and percent_of_bins=100 group by 1,2 order by 1,2;

-- Bias by site, przcat, and regime(s), for given gv source
select radar_id, przcat, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime like 'S_%' and numpts>0 and gvtype='GeoM' group by 1,2 order by 1,2;

-- Bias by site and regime
select radar_id, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_z_diff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where numpts>25 group by 1,2 order by 1,2;
 radar_id | regime  | mean_z_diff | total  
----------+---------+-------------+--------
 RGSN     | C_above |        3.66 |    792
 RGSN     | C_below |        2.96 |   6431
 RGSN     | C_in    |        2.63 |   3511
 RGSN     | S_above |        2.17 |  11238
 RGSN     | S_below |        2.98 |  76416
 RGSN     | S_in    |        1.78 |  88840
 RGSN     | Total   |        2.35 | 194957
 RJNI     | C_above |       -0.06 |   1957
 RJNI     | C_below |        0.72 |   4572
 RJNI     | C_in    |        0.12 |   3920
 RJNI     | S_above |       -1.02 |  24258
 RJNI     | S_below |         0.2 |  67054
 RJNI     | S_in    |       -1.27 |  84543
 RJNI     | Total   |       -0.61 | 197306
 RPSN     | C_above |        1.29 |   1123
 RPSN     | C_below |        2.04 |   6152
 RPSN     | C_in    |        1.22 |   5040
 RPSN     | S_above |        0.12 |  11489
 RPSN     | S_below |        2.16 |  59810
 RPSN     | S_in    |        0.55 |  77929
 RPSN     | Total   |        1.17 | 168537
 RSSP     | C_above |        2.24 |    820
 RSSP     | C_below |        2.71 |   5631
 RSSP     | C_in    |        2.24 |   3825
 RSSP     | S_above |        1.74 |  11892
 RSSP     | S_below |        3.07 |  68373
 RSSP     | S_in    |        1.85 |  87435
 RSSP     | Total   |        2.33 | 186887
(28 rows)


-- "Best" bias regime (stratiform above BB), broken out by site, GV type and range:
select gvtype, radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanpr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangv, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- breakout by regime and 5 dBZ GR Z ranges
 select regime,  round((gvmean+2.5)/5)*5 as GV_dbz, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_z_diff, sum(numpts) as total, count(orbit) as cases from zdiff_stats_by_dist_time_prz_kma where numpts>25 group by 1,2 order by 1,2;
 regime  | gv_dbz | mean_z_diff | total  | cases 
---------+--------+-------------+--------+-------
 C_above |     25 |         3.1 |    597 |    14
 C_above |     30 |        1.68 |   2765 |    60
 C_above |     35 |       -0.33 |   1275 |    27
 C_above |     40 |       -0.45 |     55 |     2
 C_below |     30 |        6.11 |    383 |    10
 C_below |     35 |        3.57 |   5351 |   100
 C_below |     40 |        2.05 |  15065 |   208
 C_below |     45 |        -0.9 |   1880 |    29
 C_below |     50 |       -5.01 |    107 |     2
 C_in    |     25 |         6.4 |     29 |     1
 C_in    |     30 |        3.29 |    670 |    17
 C_in    |     35 |        2.35 |   5869 |   116
 C_in    |     40 |        1.05 |   9192 |   148
 C_in    |     45 |        -2.6 |    536 |    11
 S_above |     20 |        2.51 |   1662 |    28
 S_above |     25 |         0.8 |  47138 |   587
 S_above |     30 |       -1.96 |   9941 |   114
 S_above |     35 |       -3.58 |    104 |     3
 S_above |     40 |       -9.09 |     32 |     1
 S_below |     20 |        2.55 |    282 |     3
 S_below |     25 |        2.75 |  61149 |   342
 S_below |     30 |        2.27 | 160490 |   662
 S_below |     35 |        0.96 |  49523 |   238
 S_below |     40 |       -3.79 |    209 |     4
 S_in    |     20 |        2.77 |    504 |     8
 S_in    |     25 |        2.28 |  49438 |   350
 S_in    |     30 |           1 | 191554 |   968
 S_in    |     35 |       -0.47 |  94570 |   442
 S_in    |     40 |       -2.54 |   2681 |    17
 Total   |     20 |        2.53 |   1552 |    23
 Total   |     25 |        2.03 | 153457 |   982
 Total   |     30 |        1.45 | 382042 |  1419
 Total   |     35 |        0.58 | 197359 |   714
 Total   |     40 |       -0.92 |  12778 |   112
 Total   |     45 |       -4.66 |    499 |     7
(35 rows)


-- Non-site/regime-specific summary stats, broken out by GV type, przcat and range only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, przcat, rangecat
 into temp dbzsums from zdiff_stats_by_dist_time_prz_kma where meandiff > -99.9
 group by 4,5,6 order by 4,5,6; 
select round(100.*w/n)/100. as bias, gvtype, przcat, rangecat from dbzsums; 

-- Full breakout: site, regime, raintype, przcat and range
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(prmean*numpts) as p, sum(gvmean*numpts) as g,
       max(prmax) as px, max(gvmax) as gx,
       sum(numpts) as n, gvtype, regime, radar_id, przcat, rangecat
  into temp sitedbzsums from dbzdiff_stats_by_dist
 where meandiff > -99.9 and diffstddev > -99.9
 group by 8,9,10,11,12 order by 8,9,10,11,12;

select a.radar_id, a.regime, a.przcat, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(a.s/a.n))/100 as stddev2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, round(100*(b.s/b.n))/100 as stddevREORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.regime = b.regime and a.przcat = b.przcat and a.rangecat = b.rangecat order by 1,2,4,3;

select a.radar_id, a.regime, a.przcat, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddev2A55, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_2A55, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.przcat = b.przcat and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, a.przcat, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_REOR, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddevREOR, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_REOR, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.przcat = b.przcat and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, round(100*SUM(a.w)/SUM(a.n))/100 as bias_vs_GRID, round(100*SUM(b.w)/SUM(b.n))/100 as bias_vs_GEOM, round(100*SUM(a.s)/SUM(a.n))/100 as stddevGRID, round(100*SUM(b.s)/SUM(b.n))/100 as stddevGEOM, SUM(a.n) as num_GRID, SUM(b.n) as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.przcat = b.przcat and a.rangecat = b.rangecat and a.regime = 'S_above' group by 1,2 order by 1,2;

-- "Best" bias regime (stratiform above BB), broken out by site and month, for 2A55:
select a.radar_id, date_trunc('month',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma a, overpass_event b where regime='S_above' and numpts>5 and percent_of_bins=100 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id ='KAMX' group by 1,2 order by 1,2;

-- Vertical profiles of PR and GV mean Z:
select radar_id, przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 and regime like 'S_%' and numpts > 0 group by 1,2 order by 1,2;

select gvtype, radar_id, przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 group by 1,2,3 order by 2,1,3;

--Strat profile forPrlx, non-BB
select przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 and regime in ('S_above','S_below') and numpts > 0 and radar_id < 'KWAJ' group by 1 order by 1;
 przcat |  pr   |  gv   |   n   
--------+-------+-------+-------
    1.5 | 27.64 |  27.8 | 18252
      3 | 26.51 | 27.06 | 11129
    4.5 | 23.67 | 25.26 | 11261
      6 | 23.19 |  24.6 | 14778
    7.5 | 22.46 | 23.63 |  5963
      9 | 21.93 | 22.89 |   830
   10.5 | 23.53 | 24.87 |    52
     12 | 24.92 | 27.51 |     3
(8 rows)
--Conv profile forPrlx, non-BB
select przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 and regime in ('C_above','C_below') and numpts > 0 and radar_id < 'KWAJ' group by 1 order by 1;
 przcat |  pr   |  gv   |   n   
--------+-------+-------+-------
    1.5 | 41.05 | 41.36 |  9969
      3 | 38.14 |    39 |  5342
    4.5 | 31.12 | 32.31 |  7547
      6 | 29.89 |  31.3 | 10409
    7.5 |  28.9 | 30.35 |  5622
      9 | 29.16 | 30.64 |  2279
   10.5 | 30.16 | 32.32 |   711
     12 | 31.14 | 33.37 |   185
   13.5 | 35.43 | 36.55 |    25
     15 | 29.64 | 33.95 |     1
(10 rows)

--Strat profile for V6 for 2008
select przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 and regime in ('S_above','S_below') and numpts > 0 and radar_id < 'KWAJ' and orbit between 57821 and 63364 group by 1 order by 1;
 przcat |  pr   |  gv   |   n   
--------+-------+-------+-------
    1.5 | 27.59 | 27.83 | 22347
      3 | 26.49 | 27.12 | 11870
    4.5 | 23.73 | 25.25 | 10765
      6 |  23.2 | 24.58 | 14039
    7.5 | 22.46 | 23.61 |  5673
      9 | 21.91 | 22.85 |   810
   10.5 | 23.31 | 24.67 |    50
     12 | 24.19 | 24.24 |     2
(8 rows)
--Conv profile for V6 for 2008
select przcat, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from zdiff_stats_by_dist_time_prz_kma where rangecat<2 and regime in  ('C_above','C_below') and numpts > 0 and radar_id < 'KWAJ' and orbit between 57821 and 63364 group by 1 order by 1;
 przcat |  pr   |  gv   |   n   
--------+-------+-------+-------
    1.5 | 40.49 | 40.91 | 11617
      3 | 38.16 | 39.29 |  5292
    4.5 | 31.99 | 33.09 |  8178
      6 | 30.05 | 31.22 | 10554
    7.5 | 28.95 | 30.21 |  5687
      9 | 29.21 | 30.56 |  2291
   10.5 | 30.18 | 32.19 |   714
     12 | 31.24 | 33.44 |   185
   13.5 | 34.72 | 35.99 |    26
     15 | 29.65 | 34.04 |     1
(10 rows)

-- Both profiles for V6 Fixed for input to plot_mean_profiles.pro
select a.przcat, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma b, zdiff_stats_by_dist_time_prz_kma c where a.rangecat<2 and a.regime in ('C_above','C_below') and a.numpts > 4 and b.numpts>4 and c.numpts > 4 and a.radar_id < 'KWAJ' and b.regime in ('S_above','S_below') and a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.przcat=c.przcat and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat group by 1 order by 1;
 przcat |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
    1.5 | 40.99 | 41.05 | 25289 |  28.1 | 28.12 | 37800 | 33.62 | 33.73 | 59040
      3 | 37.11 | 37.84 | 14682 | 27.03 | 27.46 | 30819 | 31.07 | 31.86 | 60795
    4.5 | 31.31 | 32.52 | 25360 | 24.04 | 25.61 | 26768 | 28.15 | 29.74 | 53568
      6 | 30.04 | 31.45 | 26681 | 23.33 | 24.78 | 33439 | 26.05 | 27.51 | 47902
    7.5 | 29.11 | 30.64 | 12660 | 22.55 | 23.79 | 11691 |  25.6 | 27.02 | 18249
      9 |  29.3 | 31.02 |  2589 | 22.07 | 23.26 |  1233 | 26.69 | 28.27 |  2703
   10.5 | 27.64 | 29.89 |    45 | 24.88 | 25.71 |    27 |  26.5 | 28.21 |    49
(7 rows)

-- Both profiles for V6/2008 for input to plot_mean_profiles.pro
select a.przcat, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma b, zdiff_stats_by_dist_time_prz_kma c where a.rangecat<2 and a.regime in ('C_above','C_below') and a.numpts > 4 and b.numpts>4 and c.numpts > 4 and a.radar_id < 'KWAJ' and b.regime in ('S_above','S_below') and a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.przcat=c.przcat and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.orbit between 57821 and 63364 group by 1 order by 1;
 przcat |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
    1.5 | 40.42 | 40.58 | 31223 | 28.05 | 28.13 | 47491 | 33.44 | 33.59 | 73076
      3 | 37.69 | 38.69 | 15472 | 27.13 | 27.71 | 31624 | 31.49 | 32.28 | 61355
    4.5 | 31.62 | 32.63 | 25103 |  24.1 | 25.59 | 25327 | 28.27 | 29.78 | 50955
      6 | 30.21 |  31.4 | 26672 | 23.35 | 24.77 | 32293 | 26.13 | 27.48 | 46792
    7.5 | 29.05 | 30.36 | 12409 | 22.56 | 23.77 | 10877 | 25.63 | 26.95 | 17613
      9 |  29.4 | 30.83 |  2526 | 21.99 | 23.05 |  1140 | 26.78 | 28.14 |  2603
   10.5 | 27.59 | 29.55 |    48 | 24.51 | 25.72 |    27 | 26.39 | 28.07 |    51
(7 rows)


-- DIFFERENCES BY FRACTION OF CONVECTIVE VS. STRATIFORM RAIN

-- compute a percent stratiform and convective from the geo-match dataset
select percent_of_bins, radar_id, orbit, sum(numpts) as n_conv into temp npts_conv from zdiff_stats_by_dist_time_prz_kma where regime like 'C_%' group by 1,2,3 order by 1,2,3;
select percent_of_bins, radar_id, orbit, sum(numpts) as n_strat into temp npts_strat from zdiff_stats_by_dist_time_prz_kma where regime like 'S_%' group by 1,2,3 order by 1,2,3;
select a.percent_of_bins, a.radar_id, a.orbit, round((cast(n_conv as float)/(n_conv+n_strat))*10)*10 as pct_conv into temp pct_conv_temp from npts_conv a, npts_strat b where a.percent_of_bins=b.percent_of_bins and a.radar_id=b.radar_id and a.orbit=b.orbit and (b.n_strat>0 OR a.n_conv>0);

-- compute convective and stratiform areas of rain at 3 km from the geo-match dataset
select percent_of_bins, radar_id, orbit, ((sum(numpts)/250)+1)*250 as n_conv into temp area_conv from zdiff_stats_by_dist_time_prz_kma where regime like 'C_%' and przcat=3 group by 1,2,3 order by 1,2,3;
select percent_of_bins, radar_id, orbit, ((sum(numpts)/250)+1)*250 as n_strat into temp area_strat from zdiff_stats_by_dist_time_prz_kma where regime like 'S_%' and przcat=3 group by 1,2,3 order by 1,2,3;
-- compute mean bias, stdDev as function of area of precip for KMLB
select e.n_strat, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from zdiff_stats_by_dist_time_prz_kma c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%' and c.radar_id='KMLB' group by 1 order by 1;
 n_strat | biasgeo | stdev | ngeo
---------+---------+-------+-------
     250 |   -0.58 |  0.18 | 11818
     500 |    0.36 |  1.81 |  5141
     750 |    0.18 |  1.83 |  8386
    1000 |   -0.44 |  1.99 |  9805
    1250 |    1.64 |  1.87 |  3042
    1500 |   -0.74 |  2.13 |  5375
    2250 |   -0.26 |  2.17 |  4568
(7 rows)

--as above, but over all sites
select e.n_strat, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from zdiff_stats_by_dist_time_prz_kma c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%'  group by 1 order by 1;
 n_strat | biasgeo | stdev |  ngeo 
---------+---------+-------+--------
     250 |   -1.66 |  1.03 | 404442
     500 |   -1.51 |  2.03 | 300791
     750 |   -1.29 |  2.05 | 240853
    1000 |   -1.03 |  2.16 | 202471
    1250 |   -1.01 |  2.24 | 173931
    1500 |   -1.27 |  2.18 |  85409
    1750 |   -1.13 |  2.19 |  63208
    2000 |   -0.67 |  2.26 |  48963
    2250 |    0.01 |  2.36 |  14162
    2750 |    -2.3 |  1.84 |   6562
(10 rows)

-- as above, site by site
 select e.n_strat, e.radar_id, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from zdiff_stats_by_dist_time_prz_kma c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%' group by 1,2 order by 2,1;
 n_strat | radar_id | biasgeo | stdev | ngeo
---------+----------+---------+-------+-------
     250 | KAMX     |   -1.09 |   0.6 | 14682
     500 | KAMX     |   -0.94 |  2.04 |  5994
     750 | KAMX     |   -0.53 |  2.32 |  2476
    1000 | KAMX     |   -0.28 |  1.39 |  4580
    1250 | KAMX     |   -1.24 |   1.9 |  3495
    1750 | KAMX     |   -0.22 |  2.02 |  3783
     250 | KBMX     |   -2.28 |  1.41 | 33262
     500 | KBMX     |   -2.17 |  2.04 | 31583
     750 | KBMX     |   -2.28 |  2.07 | 25441
    1000 | KBMX     |    -1.9 |  2.39 | 18260
    1250 | KBMX     |   -1.03 |  2.05 | 15567
    1500 | KBMX     |   -1.42 |  2.52 | 17174
    1750 | KBMX     |   -2.91 |  2.43 | 15974
    2000 | KBMX     |   -1.13 |  1.98 | 18791
    2750 | KBMX     |    -2.3 |  1.84 |  6562
     250 | KBRO     |   -2.31 |  0.75 | 11105
     500 | KBRO     |   -2.09 |   1.6 |  2154
     750 | KBRO     |   -1.09 |  1.63 |  7471
    1000 | KBRO     |   -1.98 |  3.28 |  4494
    1500 | KBRO     |   -2.45 |  1.38 |  2456
     250 | KBYX     |   -1.27 |  0.23 | 11157
     500 | KBYX     |    -1.2 |  1.48 |  5963
     750 | KBYX     |   -1.31 |  1.69 |  8712
    1250 | KBYX     |    -0.8 |  1.45 |  2773
     250 | KCLX     |   -2.18 |  1.08 | 22793
     500 | KCLX     |   -2.21 |  2.08 | 23681
     750 | KCLX     |   -2.06 |  2.02 | 19222
    1000 | KCLX     |   -2.04 |  2.31 | 16647
    1250 | KCLX     |   -2.26 |  1.87 | 14279
    1500 | KCLX     |   -2.07 |  1.85 | 15501
     250 | KCRP     |   -1.15 |  0.82 | 10036
     500 | KCRP     |   -0.58 |  1.56 |  6659
     750 | KCRP     |   -0.91 |  1.67 |  7229
    1250 | KCRP     |   -1.27 |  1.72 |  2229
    1500 | KCRP     |   -0.76 |  3.08 |  3516
     250 | KDGX     |   -1.75 |  1.14 | 25597
     500 | KDGX     |    -1.5 |  1.93 | 22278
     750 | KDGX     |   -1.31 |  2.34 | 11428
    1000 | KDGX     |   -0.89 |  2.24 |  7874
    1250 | KDGX     |   -1.23 |  2.27 | 18812
    1500 | KDGX     |   -1.35 |  1.86 |  3994
    1750 | KDGX     |   -1.45 |  1.83 |  3743
     250 | KEVX     |   -1.57 |  1.07 | 13343
     500 | KEVX     |   -1.19 |  2.44 | 20065
     750 | KEVX     |   -0.54 |  2.73 | 14939
    1000 | KEVX     |   -0.19 |  2.52 |  9972
    1250 | KEVX     |    1.37 |  2.88 |  9175
    1750 | KEVX     |   -0.78 |  2.65 |  5067
    2000 | KEVX     |   -0.42 |  2.82 |  4836
     250 | KFWS     |    -0.8 |     1 | 23866
     500 | KFWS     |   -1.28 |  2.03 | 14176
     750 | KFWS     |   -1.02 |  1.82 | 16973
    1000 | KFWS     |   -0.78 |  1.99 | 12660
    1250 | KFWS     |    0.12 |  1.68 |  3540
    1500 | KFWS     |   -1.27 |  1.66 |  6213
     250 | KGRK     |   -0.16 |  1.05 | 14413
     500 | KGRK     |    1.14 |  2.13 |  4472
     750 | KGRK     |     0.3 |  2.05 | 11902
    1000 | KGRK     |    0.57 |  1.91 |  6789
    1250 | KGRK     |    1.89 |  1.61 |  6392
     250 | KHGX     |   -1.32 |  0.73 | 14882
     500 | KHGX     |   -0.08 |  2.09 |  5154
     750 | KHGX     |   -1.08 |  1.88 |  4793
    1000 | KHGX     |   -0.86 |  2.06 | 11754
     250 | KHTX     |   -1.49 |   1.5 | 39892
     500 | KHTX     |   -1.33 |  2.09 | 30934
     750 | KHTX     |    -0.8 |  2.24 | 26449
    1000 | KHTX     |   -1.03 |  1.92 | 26873
    1250 | KHTX     |   -1.01 |  2.57 | 20518
    1500 | KHTX     |   -1.26 |  2.15 | 10237
    1750 | KHTX     |   -0.83 |  2.38 |  7595
    2000 | KHTX     |   -0.02 |  2.78 |  8807
    2250 | KHTX     |   -0.44 |  3.03 |  4820
     250 | KJAX     |   -1.78 |  1.08 | 12893
     500 | KJAX     |   -1.49 |  2.34 | 14886
     750 | KJAX     |    -1.8 |  2.24 |  7239
    1000 | KJAX     |   -1.06 |  2.45 |  9366
    1250 | KJAX     |   -1.03 |  2.63 | 14212
    1750 | KJAX     |    0.71 |  1.47 |  3467
     250 | KJGX     |   -1.54 |  1.23 | 26456
     500 | KJGX     |   -1.23 |  2.14 | 19515
     750 | KJGX     |   -1.34 |  2.14 | 16166
    1000 | KJGX     |   -0.84 |  2.39 | 16116
    1250 | KJGX     |   -0.89 |  2.21 |  7997
    1750 | KJGX     |   -0.72 |  2.09 | 12473
     250 | KLCH     |    -2.2 |  0.93 | 17014
     500 | KLCH     |   -2.04 |  2.32 | 11945
     750 | KLCH     |   -1.18 |  1.67 |  5808
    1000 | KLCH     |   -0.32 |  1.68 |  8054
    1250 | KLCH     |   -1.79 |  2.26 | 13633
    1750 | KLCH     |   -1.12 |  2.37 |  3407
     250 | KLIX     |   -1.81 |  1.07 | 24567
     500 | KLIX     |   -1.61 |  1.75 | 16318
     750 | KLIX     |   -1.45 |  1.97 |  7449
    1000 | KLIX     |   -1.19 |  2.06 | 15187
    1250 | KLIX     |   -1.74 |   2.3 |  6142
    1500 | KLIX     |    0.97 |  2.11 |  6964
    2250 | KLIX     |    0.73 |  1.87 |  4774
     250 | KMLB     |   -0.58 |  0.18 | 11818
     500 | KMLB     |    0.36 |  1.81 |  5141
     750 | KMLB     |    0.18 |  1.83 |  8386
    1000 | KMLB     |   -0.44 |  1.99 |  9805
    1250 | KMLB     |    1.64 |  1.87 |  3042
    1500 | KMLB     |   -0.74 |  2.13 |  5375
    2250 | KMLB     |   -0.26 |  2.17 |  4568
     250 | KMOB     |   -1.34 |  0.94 | 19459
     500 | KMOB     |   -0.87 |  2.04 | 15464
     750 | KMOB     |   -1.59 |  2.08 |  9565
    1000 | KMOB     |   -1.28 |  1.83 | 11783
    1250 | KMOB     |   -1.01 |  2.27 | 10467
    1500 | KMOB     |   -0.69 |  2.35 |  4935
    1750 | KMOB     |    1.25 |   2.1 |  4506
    2000 | KMOB     |   -1.63 |  2.87 |  4084
     250 | KSHV     |   -2.61 |  1.04 | 27435
     500 | KSHV     |   -2.27 |  2.11 | 17200
     750 | KSHV     |   -2.53 |   1.7 | 12216
    1000 | KSHV     |   -0.18 |  3.02 |  1767
    1250 | KSHV     |    -2.2 |  2.35 |  6853
    1500 | KSHV     |   -1.54 |  1.63 |  2742
     250 | KTBW     |   -1.71 |  0.77 | 15860
     500 | KTBW     |   -1.57 |  1.84 | 11593
     750 | KTBW     |   -1.43 |  2.28 |  5549
    1000 | KTBW     |    0.06 |  2.67 |  2473
    1250 | KTBW     |    -1.4 |  2.17 | 14805
    1500 | KTBW     |   -1.65 |  2.78 |  3274
    1750 | KTBW     |   -1.09 |  1.52 |  3193
    2000 | KTBW     |    0.49 |   1.8 |  4315
     250 | KTLH     |   -2.69 |  0.92 | 13912
     500 | KTLH     |   -2.32 |  1.59 | 15616
     750 | KTLH     |   -1.59 |  2.06 | 11440
    1000 | KTLH     |   -1.59 |  2.16 |  8017
    1500 | KTLH     |   -2.26 |  2.91 |  3028


-- DIFFERENCES FOR 15 VS. 18 DBZ GR THRESHOLDS

-- get a common set of samples between 15 and 18 dbz GR cutoff
drop table commontemp;
select a.percent_of_bins, a.rangecat, a.regime, a.radar_id, a.orbit, a.przcat into temp commontemp from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma18 b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.percent_of_bins=b.percent_of_bins;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.przcat, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from zdiff_stats_by_dist_time_prz_kma a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.przcat=d.przcat and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.przcat, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from zdiff_stats_by_dist_time_prz_kma b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.przcat=b.przcat and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.przcat, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from zdiff_stats_by_dist_time_prz_kma c, commontemp d where c.przcat=d.przcat and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.przcat=b.przcat and b.przcat=c.przcat;

-- "Best" bias regime (stratiform above BB), broken out by site only, dbz15 vs.dbz18:
select a.radar_id, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as meandiff15, sum(a.numpts) as n_15, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as meandiff18, sum(b.numpts) as n_18 from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma18 b, commontemp c where a.regime='S_above' and a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.przcat=c.przcat and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime and a.percent_of_bins=b.percent_of_bins and a.percent_of_bins=c.percent_of_bins and a.percent_of_bins=100 group by 1 order by 1;
 radar_id | meandiff15 | n_15  | meandiff18 | n_18
----------+------------+-------+------------+-------
 KAMX     |      -0.92 |  2125 |      -1.22 |  1176
 KBMX     |      -1.53 | 14772 |      -1.77 | 10719
 KBRO     |       -2.6 |   886 |       -2.8 |   697
 KBYX     |      -0.94 |  1078 |      -1.25 |   587
 KCLX     |      -1.93 | 10036 |      -2.18 |  7533
 KCRP     |      -1.07 |   673 |      -1.27 |   487
 KDGX     |       -1.2 |  9018 |      -1.49 |  6107
 KEVX     |      -0.92 |  5346 |      -1.29 |  3507
 KFWS     |      -1.27 |  6834 |      -1.52 |  4853
 KGRK     |      -0.21 |  3016 |      -0.48 |  1961
 KHGX     |      -1.12 |  3864 |      -1.39 |  2636
 KHTX     |      -0.97 | 16621 |      -1.36 | 11475
 KJAX     |       -2.4 |  5059 |      -2.87 |  3504
 KJGX     |      -0.87 |  7867 |      -1.18 |  5497
 KLCH     |      -1.12 |  6901 |      -1.37 |  5302
 KLIX     |      -1.05 |  7610 |      -1.65 |  5507
 KMLB     |      -0.27 |  2894 |      -0.63 |  1566
 KMOB     |      -1.16 |  8039 |      -1.49 |  5969
 KSHV     |      -2.13 |  6984 |      -2.34 |  5261
 KTBW     |      -1.53 |  2816 |      -1.81 |  1823
 KTLH     |         -2 |  5343 |      -2.24 |  4418
(21 rows)

-- as above, but Convective above BB
 radar_id | meandiff15 | n_15 | meandiff18 | n_18
----------+------------+------+------------+------
 KAMX     |      -0.54 |  955 |      -0.63 |  674
 KBMX     |      -1.64 | 5327 |      -1.87 | 4451
 KBRO     |      -2.71 |  805 |      -2.99 |  675
 KBYX     |      -0.74 |  453 |      -0.84 |  307
 KCLX     |      -1.39 | 2301 |      -1.61 | 1745
 KCRP     |      -2.23 |  378 |      -2.44 |  326
 KDGX     |      -0.97 | 3420 |      -1.32 | 2563
 KEVX     |       -0.6 | 3009 |      -1.03 | 2180
 KFWS     |      -1.59 | 3529 |       -1.9 | 2722
 KGRK     |      -0.45 | 1347 |      -0.87 |  977
 KHGX     |      -1.05 | 1626 |      -1.26 | 1287
 KHTX     |       -0.6 | 5073 |      -0.94 | 3841
 KJAX     |      -2.43 | 1972 |      -2.67 | 1615
 KJGX     |      -1.43 | 2261 |      -1.84 | 1867
 KLCH     |      -0.91 | 4843 |      -1.05 | 4030
 KLIX     |      -0.56 | 3422 |      -0.96 | 2605
 KMLB     |       0.27 | 1922 |      -0.01 | 1269
 KMOB     |       0.17 | 2552 |      -0.13 | 1954
 KSHV     |      -1.63 | 4955 |      -1.85 | 3936
 KTBW     |      -0.85 | 1140 |      -1.02 |  803
 KTLH     |      -2.15 | 1336 |      -2.28 | 1154
(21 rows)

-- as above, but all Convective rain type/levels
 radar_id | meandiff15 | n_15 | meandiff18 | n_18
----------+------------+------+------------+------
 KAMX     |      -1.11 | 2642 |      -1.23 | 2140
 KBMX     |      -1.56 | 7523 |      -1.69 | 6365
 KBRO     |       -2.7 | 1137 |      -2.93 |  964
 KBYX     |      -1.72 | 1719 |      -1.64 | 1373
 KCLX     |      -1.33 | 3749 |      -1.43 | 3039
 KCRP     |      -2.07 |  862 |      -2.13 |  737
 KDGX     |       -0.8 | 6290 |      -0.96 | 5140
 KEVX     |      -0.22 | 4940 |       -0.5 | 3905
 KFWS     |      -1.34 | 4623 |      -1.56 | 3650
 KGRK     |       0.24 | 2354 |       0.13 | 1881
 KHGX     |      -0.63 | 2349 |      -0.71 | 1942
 KHTX     |      -0.39 | 7068 |      -0.65 | 5593
 KJAX     |      -1.57 | 3434 |      -1.71 | 2898
 KJGX     |      -1.09 | 3065 |      -1.42 | 2558
 KLCH     |      -0.64 | 7326 |      -0.73 | 6253
 KLIX     |      -0.33 | 5779 |      -0.48 | 4756
 KMLB     |       0.55 | 3074 |        0.4 | 2275
 KMOB     |      -0.73 | 4690 |      -0.93 | 3805
 KSHV     |      -1.72 | 6663 |      -1.87 | 5432
 KTBW     |      -0.87 | 2540 |      -0.96 | 2043
 KTLH     |      -1.83 | 2019 |      -1.88 | 1754
(21 rows)

-- All regimes broken out by site and regime, V6 vs. Prlx:
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.przcat into temp commontemp from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total');

select a.radar_id, a.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as v6meandiff, sum(a.numpts) as n_v6, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as v7meandiff, sum(b.numpts) as n_prlx from zdiff_stats_by_dist_time_prz_kma a, zdiff_stats_by_dist_time_prz_kma b, commontemp c where  a.przcat=b.przcat and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.przcat=c.przcat and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime group by 1,2 order by 2,1;
 radar_id | regime  | v6meandiff | n_v6  | v7meandiff | n_prlx  
----------+---------+------------+-------+------------+-------
 KAMX     | C_above |      -1.37 |   705 |      -1.59 |   694
 KBMX     | C_above |      -2.16 |  2788 |      -2.55 |  2710
 KBRO     | C_above |      -2.61 |   503 |      -2.76 |   478
 KBYX     | C_above |       0.12 |   222 |      -0.19 |   215
 KCLX     | C_above |      -1.19 |  1443 |      -1.36 |  1384
 KCRP     | C_above |       0.93 |    44 |       1.11 |    42
 KDGX     | C_above |      -1.58 |  1172 |      -1.46 |  1287
 KEVX     | C_above |      -0.33 |  1911 |      -0.64 |  1863
 KFWS     | C_above |      -0.77 |  1551 |      -0.96 |  1512
 KGRK     | C_above |       -0.8 |   733 |      -1.19 |   717
 KHGX     | C_above |      -0.31 |   811 |      -0.56 |   830
 KHTX     | C_above |      -0.95 |  2943 |      -1.17 |  2924
 KJAX     | C_above |       -2.2 |  1648 |      -2.37 |  1631
 KJGX     | C_above |      -1.08 |  1286 |      -1.38 |  1278
 KLCH     | C_above |      -1.84 |  1077 |       -2.2 |  1204
 KLIX     | C_above |      -1.58 |  1278 |       -1.9 |  1267
 KMLB     | C_above |       0.67 |   898 |       0.62 |   869
 KMOB     | C_above |       2.12 |  1055 |       2.03 |  1118
 KSHV     | C_above |      -1.63 |  2525 |       -1.8 |  2483
 KTBW     | C_above |      -0.68 |   912 |       -0.8 |   880
 KTLH     | C_above |      -2.03 |   573 |      -2.16 |   547
 KAMX     | C_below |      -1.73 |   981 |      -1.41 |   849
 KBMX     | C_below |      -1.07 |   614 |      -1.28 |   582
 KBRO     | C_below |      -2.44 |   202 |      -2.46 |   187
 KBYX     | C_below |      -1.66 |   687 |      -1.79 |   599
 KCLX     | C_below |       -0.1 |   542 |      -0.53 |   392
 KCRP     | C_below |      -2.13 |   296 |      -1.89 |   243
 KDGX     | C_below |      -1.26 |  1022 |       -1.1 |   871
 KEVX     | C_below |       0.67 |  1157 |       0.75 |   974
 KFWS     | C_below |        0.6 |   464 |       0.53 |   396
 KGRK     | C_below |       1.44 |   218 |       1.27 |   219
 KHGX     | C_below |       0.42 |   533 |       0.57 |   406
 KHTX     | C_below |      -0.27 |   569 |      -0.16 |   526
 KJAX     | C_below |       0.09 |  1001 |       0.28 |   821
 KJGX     | C_below |       0.34 |   456 |       0.63 |   345
 KLCH     | C_below |      -1.38 |   484 |      -0.73 |   575
 KLIX     | C_below |       -1.4 |   902 |      -1.26 |   860
 KMLB     | C_below |       1.97 |   689 |        2.2 |   585
 KMOB     | C_below |      -0.65 |   775 |      -0.13 |   694
 KSHV     | C_below |      -1.03 |   503 |      -1.18 |   498
 KTBW     | C_below |      -0.92 |   723 |      -0.84 |   603
 KTLH     | C_below |      -1.65 |   434 |      -1.78 |   378
 KAMX     | C_in    |      -1.93 |  1653 |      -1.94 |  1597
 KBMX     | C_in    |      -1.94 |  4209 |      -2.39 |  4171
 KBRO     | C_in    |      -2.73 |   621 |      -3.17 |   625
 KBYX     | C_in    |      -1.39 |   778 |      -1.58 |   731
 KCLX     | C_in    |      -1.66 |  2447 |      -1.72 |  2160
 KCRP     | C_in    |      -0.71 |   323 |      -0.67 |   303
 KDGX     | C_in    |      -1.64 |  2645 |      -1.74 |  3025
 KEVX     | C_in    |      -0.08 |  3845 |      -0.24 |  3666
 KFWS     | C_in    |      -0.46 |  1959 |       -0.5 |  1984
 KGRK     | C_in    |       0.05 |   723 |      -0.09 |   707
 KHGX     | C_in    |      -0.54 |  1557 |      -0.55 |  1543
 KHTX     | C_in    |      -0.81 |  4265 |      -1.05 |  4359
 KJAX     | C_in    |      -1.98 |  3193 |      -2.09 |  3114
 KJGX     | C_in    |      -0.91 |  2651 |      -1.14 |  2586
 KLCH     | C_in    |      -2.63 |  1181 |       -3.3 |  1244
 KLIX     | C_in    |      -2.26 |  1648 |      -2.26 |  1598
 KMLB     | C_in    |        0.7 |  1857 |       0.69 |  1814
 KMOB     | C_in    |       0.38 |  1792 |      -0.01 |  1756
 KSHV     | C_in    |      -1.67 |  2601 |      -1.75 |  2522
 KTBW     | C_in    |      -1.38 |  1772 |      -1.25 |  1693
 KTLH     | C_in    |      -2.64 |  1437 |      -2.68 |  1374
 KAMX     | S_above |      -1.26 |   996 |      -1.28 |  1008
 KBMX     | S_above |      -1.96 |  5539 |         -2 |  5769
 KBRO     | S_above |      -2.59 |   604 |       -2.6 |   611
 KBYX     | S_above |      -0.44 |   607 |      -0.46 |   628
 KCLX     | S_above |      -1.49 |  5049 |      -1.48 |  5050
 KCRP     | S_above |      -0.95 |   471 |      -0.97 |   440
 KDGX     | S_above |      -1.26 |  4396 |      -1.33 |  4165
 KEVX     | S_above |      -0.39 |  2816 |      -0.41 |  2776
 KFWS     | S_above |      -1.04 |  2960 |      -1.06 |  3047
 KGRK     | S_above |      -0.19 |  1068 |      -0.21 |  1127
 KHGX     | S_above |      -0.99 |  2478 |      -1.09 |  2455
 KHTX     | S_above |      -1.33 |  8733 |      -1.36 |  8716
 KJAX     | S_above |      -2.24 |  3484 |      -2.22 |  3476
 KJGX     | S_above |      -0.64 |  4731 |      -0.72 |  4719
 KLCH     | S_above |      -1.91 |  1900 |         -2 |  1751
 KLIX     | S_above |      -2.19 |  4432 |      -2.27 |  4386
 KMLB     | S_above |       0.32 |  1572 |       0.32 |  1603
 KMOB     | S_above |       0.22 |  3054 |      -0.02 |  2930
 KSHV     | S_above |      -2.23 |  3123 |      -2.17 |  3106
 KTBW     | S_above |      -1.55 |  1693 |      -1.45 |  1727
 KTLH     | S_above |       -2.8 |  2571 |      -2.82 |  2590
 KAMX     | S_below |      -0.77 |  3096 |       -0.7 |  2786
 KBMX     | S_below |      -0.84 |  2050 |      -0.83 |  1786
 KBRO     | S_below |      -1.26 |  1638 |      -1.22 |  1417
 KBYX     | S_below |      -0.23 |  4150 |      -0.14 |  3701
 KCLX     | S_below |      -0.54 |  3810 |       -0.5 |  3106
 KCRP     | S_below |      -0.35 |  1312 |      -0.34 |  1250
 KDGX     | S_below |      -1.15 |  6378 |      -1.13 |  5706
 KEVX     | S_below |       1.11 |  2696 |       1.14 |  2289
 KFWS     | S_below |       0.85 |  1485 |       0.94 |  1269
 KGRK     | S_below |       1.07 |   173 |       1.19 |   164
 KHGX     | S_below |       0.96 |  2454 |       1.03 |  2286
 KHTX     | S_below |       0.32 |  3692 |       0.31 |  3555
 KJAX     | S_below |       0.24 |  3946 |       0.29 |  3120
 KJGX     | S_below |       1.02 |  3096 |       1.08 |  2731
 KLCH     | S_below |      -0.83 |  1192 |      -0.85 |  1104
 KLIX     | S_below |      -1.33 |  2065 |      -1.25 |  1711
 KMLB     | S_below |       2.47 |  1909 |       2.45 |  1708
 KMOB     | S_below |      -0.09 |  1967 |          0 |  1547
 KSHV     | S_below |       -1.4 |  1527 |      -1.36 |  1435
 KTBW     | S_below |      -0.61 |  2332 |       -0.6 |  2061
 KTLH     | S_below |      -2.21 |  2132 |      -2.15 |  1917
 KAMX     | S_in    |      -1.58 |  4193 |      -1.57 |  4232
 KBMX     | S_in    |      -2.31 | 17750 |      -2.39 | 16409
 KBRO     | S_in    |      -2.38 |  3176 |       -2.4 |  3168
 KBYX     | S_in    |       -1.2 |  4739 |      -1.18 |  4805
 KCLX     | S_in    |      -2.31 | 13401 |      -2.34 | 13327
 KCRP     | S_in    |      -1.22 |  2668 |      -1.22 |  2683
 KDGX     | S_in    |      -2.04 | 16050 |      -2.08 | 15276
 KEVX     | S_in    |      -0.22 |  9663 |      -0.25 |  9616
 KFWS     | S_in    |      -1.15 |  6845 |      -1.21 |  6737
 KGRK     | S_in    |      -1.04 |   970 |      -1.07 |   916
 KHGX     | S_in    |      -1.01 |  5072 |       -1.1 |  5020
 KHTX     | S_in    |      -1.75 | 27844 |      -1.73 | 26857
 KJAX     | S_in    |      -1.75 | 10936 |      -1.78 | 10703
 KJGX     | S_in    |      -1.29 | 17524 |      -1.38 | 16933
 KLCH     | S_in    |       -2.7 |  4805 |      -2.67 |  4553
 KLIX     | S_in    |      -2.91 |  7129 |      -3.05 |  6949
 KMLB     | S_in    |       0.43 |  3920 |       0.46 |  3928
 KMOB     | S_in    |      -1.43 |  8668 |      -1.55 |  8217
 KSHV     | S_in    |      -2.53 |  6685 |      -2.54 |  6519
 KTBW     | S_in    |      -1.99 |  5235 |      -1.97 |  5278
 KTLH     | S_in    |      -3.22 |  8156 |      -3.22 |  8068
(126 rows)

-- Case-by-case differences for GeoM
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsgeo from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>5 and gvtype='GeoM' and rangecat<2 and percent_of_bins=100 group by 1,2 order by 1,2;
          
-- Case-by-case differences for 2A55
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp stats2a55 from dbzdiff_stats_by_dist where regime='S_above' and numpts>5 and gvtype='2A55' and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences for REOR
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsreo from dbzdiff_stats_by_dist where regime='S_above' and numpts>5 and gvtype='REOR' and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences for all 3 GV sources, side-by-side
select a.radar_id, b.orbit, a.meanmeandiff as diffgeo, b.meanmeandiff as diff55, c.meanmeandiff as diffreo, a.total as numgeo, b.total as num55, c.total as numreo into temp statsall from statsgeo a, stats2a55 b, statsreo c where a.radar_id = b.radar_id and b.radar_id = c.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- Site-specific mean differences for all 3 GV sources, over all cases
select radar_id, round((sum(diffgeo*numgeo)/sum(numgeo))*100)/100 as meangeo, round((sum(diff55*num55)/sum(num55))*100)/100 as mean55, round((sum(diffreo*numreo)/sum(numreo))*100)/100 as meanreo into temp statsmeanall from statsall group by 1 order by 1; 

-- Case-by-case differences from the site's long term mean difference over all cases
select a.radar_id, b.orbit, a.meanmeandiff-meangeo as diffgeo, b.meanmeandiff-mean55 as diff55, c.meanmeandiff-meanreo as diffreo, a.total as numgeo, b.total as num55, c.total as numreo into temp statsfromltmean from statsgeo a, stats2a55 b, statsreo c, statsmeanall d where a.radar_id = b.radar_id and b.radar_id = c.radar_id and c.radar_id=d.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- total number of matching cases
select radar_id, count(*) as n_cases into temp matchups from statsfromltmean  group by 1 order by 1;

-- Number of cases whose deviation from the long-term difference exceeds 1 dbz, by source
select radar_id, count(*) as ngeo into temp geo_off from statsfromltmean where abs(diffgeo) > 1  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_off from statsfromltmean where abs(diffreo) > 1  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_off from statsfromltmean where abs(diff55) > 1  group by 1 order by 1;
select a.radar_id, ngeo, n55, nreo, n_cases from geo_off a, a55_off b, reo_off c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_off a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |    6 |   5 |    3 |      28
 KBMX     |   29 |  20 |   27 |      65
 KBRO     |    6 |   5 |    4 |      18
 KBYX     |    5 |   6 |    5 |      28
 KCLX     |    9 |   5 |    8 |      54
 KCRP     |    1 |   1 |    3 |      18
 KDGX     |   10 |   5 |   14 |      50
 KEVX     |   19 |  19 |   15 |      43
 KFWS     |   19 |  18 |   21 |      63
 KGRK     |   10 |  13 |   12 |      27
 KHGX     |   15 |  10 |   11 |      34
 KHTX     |   12 |  20 |   17 |      63
 KJAX     |   13 |  11 |   12 |      34
 KJGX     |   24 |  22 |   24 |      49
 KLCH     |   13 |  13 |   11 |      32
 KLIX     |   14 |  13 |   14 |      43
 KMLB     |    4 |   2 |    1 |      27
 KMOB     |   11 |   7 |    8 |      32
 KSHV     |   12 |  12 |   13 |      56
 KTBW     |   11 |   7 |    9 |      29
 KTLH     |   10 |  14 |   16 |      35
(21 rows)

-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30 from statsfromltmean where abs(diffgeo) > 1 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_off30 a, a55_off b, reo_off c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_off30 a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |    2 |   5 |    3 |      28
 KBMX     |   21 |  20 |   27 |      65
 KBRO     |    1 |   5 |    4 |      18
 KBYX     |      |   6 |    5 |      28
 KCLX     |    5 |   5 |    8 |      54
 KCRP     |      |   1 |    3 |      18
 KDGX     |    5 |   5 |   14 |      50
 KEVX     |   10 |  19 |   15 |      43
 KFWS     |   13 |  18 |   21 |      63
 KGRK     |    5 |  13 |   12 |      27
 KHGX     |    4 |  10 |   11 |      34
 KHTX     |    6 |  20 |   17 |      63
 KJAX     |   11 |  11 |   12 |      34
 KJGX     |   18 |  22 |   24 |      49
 KLCH     |    6 |  13 |   11 |      32
 KLIX     |    9 |  13 |   14 |      43
 KMLB     |    2 |   2 |    1 |      27
 KMOB     |    7 |   7 |    8 |      32
 KSHV     |    5 |  12 |   13 |      56
 KTBW     |    8 |   7 |    9 |      29
 KTLH     |    6 |  14 |   16 |      35
(21 rows)


-- Number of cases whose deviation from the long-term difference exceeds 2 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby2 from statsfromltmean where abs(diffgeo) > 2  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby2 from statsfromltmean where abs(diffreo) > 2  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby2 from statsfromltmean where abs(diff55) > 2  group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_offby2 a, a55_offby2 b, reo_offby2 c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_offby2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id) full outer join matchups using (radar_id);
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by2 from statsfromltmean where abs(diffgeo) > 2 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_off30by2 a, a55_offby2 b, reo_offby2 c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_off30by2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |      |     |      |      28
 KBMX     |    4 |   5 |    4 |      65
 KBRO     |      |   1 |    2 |      18
 KBYX     |      |   1 |    2 |      28
 KCLX     |      |   1 |      |      54
 KCRP     |      |     |      |      18
 KDGX     |    1 |     |      |      50
 KEVX     |    3 |   8 |    8 |      43
 KFWS     |    5 |   5 |    3 |      63
 KGRK     |    2 |   4 |    2 |      27
 KHGX     |      |     |    1 |      34
 KHTX     |    1 |   4 |    1 |      63
 KJAX     |    4 |   1 |    2 |      34
 KJGX     |    3 |   2 |    7 |      49
 KLCH     |      |   2 |    1 |      32
 KLIX     |    1 |   1 |    3 |      43
 KMLB     |    1 |   1 |      |      27
 KMOB     |    2 |   2 |    2 |      32
 KSHV     |    1 |   2 |    3 |      56
 KTBW     |    1 |     |      |      29
 KTLH     |    2 |   1 |    2 |      35
(21 rows)


-- Number of cases whose deviation from the long-term difference exceeds 3 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby3 from statsfromltmean where abs(diffgeo) > 3  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby3 from statsfromltmean where abs(diffreo) > 3  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby3 from statsfromltmean where abs(diff55) > 3  group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_offby3 a, a55_offby3 b, reo_offby3 c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_offby3 a full outer join a55_offby3 using (radar_id) full outer join reo_offby3 using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |      |     |      |      28
 KBMX     |      |     |      |      65
 KBRO     |    1 |     |      |      18
 KBYX     |      |     |      |      28
 KCLX     |      |     |      |      54
 KCRP     |      |     |      |      18
 KDGX     |    1 |     |      |      50
 KEVX     |    1 |   1 |    3 |      43
 KFWS     |    1 |     |      |      63
 KGRK     |    2 |     |    1 |      27
 KHGX     |    1 |     |      |      34
 KHTX     |      |     |      |      63
 KJAX     |    1 |     |      |      34
 KJGX     |    1 |   1 |    1 |      49
 KLCH     |    1 |     |      |      32
 KLIX     |    1 |   1 |      |      43
 KMLB     |      |     |      |      27
 KMOB     |    1 |     |    1 |      32
 KSHV     |      |     |    1 |      56
 KTBW     |      |     |      |      29
 KTLH     |    1 |     |      |      35
(21 rows)

-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by3 from statsfromltmean where abs(diffgeo) > 3 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_off30by3 a, a55_offby3 b, reo_offby3 c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_off30by3 a full outer join a55_offby3 using (radar_id) full outer join reo_offby3 using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |      |     |      |      28
 KBMX     |      |     |      |      65
 KBRO     |      |     |      |      18
 KBYX     |      |     |      |      28
 KCLX     |      |     |      |      54
 KCRP     |      |     |      |      18
 KDGX     |      |     |      |      50
 KEVX     |      |   1 |    3 |      43
 KFWS     |      |     |      |      63
 KGRK     |    1 |     |    1 |      27
 KHGX     |      |     |      |      34
 KHTX     |      |     |      |      63
 KJAX     |    1 |     |      |      34
 KJGX     |      |   1 |    1 |      49
 KLCH     |      |     |      |      32
 KLIX     |      |   1 |      |      43
 KMLB     |      |     |      |      27
 KMOB     |      |     |    1 |      32
 KSHV     |      |     |    1 |      56
 KTBW     |      |     |      |      29
 KTLH     |    1 |     |      |      35
(21 rows)


-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /tmp/event_best_diffs95pts25.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and percent_of_bins=90 group by 1,2 order by 1,2;

select radar_id, orbit, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvmax)*100)/100) as gvmax, round((max(prmax)*100)/100) as prmax, sum(numpts) as total from zdiff_stats_by_dist_time_prz_kma where regime='S_above' and numpts>25  group by 1,2 order by 1,2;
