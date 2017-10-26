-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table dbzdiff_stats_by_dist_geo_V6BBrel (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);


create table dbzdiff_stats_by_dist_geo_s2ku_V6BBrel (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totalany into temp anytotal from dbzdiff_stats_by_dist_geo_V6BBrel where regime='Total' group by 1,2,3,4,5,6;

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totaltypes into temp totalbytypes from dbzdiff_stats_by_dist_geo_V6BBrel where regime!='Total' group by 1,2,3,4,5,6;

select a.*, b.totaltypes from anytotal a, totalbytypes b where a.percent_of_bins = b.percent_of_bins and a.rangecat = b.rangecat and a.gvtype = b.gvtype and a.radar_id = b.radar_id and a.orbit = b.orbit and a.height = b.height and a.totalany < b.totaltypes;

delete from dbzdiff_stats_by_dist_geo_V6BBrel;
\copy dbzdiff_stats_by_dist_geo_V6BBrel from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct100_BBrelV6_2008_DefaultS.unl' with delimiter '|' 
delete from dbzdiff_stats_by_dist_geo_s2ku_V6BBrel;
\copy dbzdiff_stats_by_dist_geo_s2ku_V6BBrel from '/data/gpmgv/tmp/StatsByDistToDBGeo_Pct100_BBrelV6_2008_S2Ku.unl' with delimiter '|' 

-- "Best" bias regime (stratiform above BB), broken out by site and range:
select radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinmax/10)*10+5 as grmaxz, regime, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime like 'S%' and numpts>0 group by 3,2 order by 1;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinstddev/3)*3 as stddev, regime, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime like 'S%' and numpts>5 group by 3,2 order by 3,2;
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
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 group by 1 order by 1;

-- As above, but output to HTML table
\o /data/tmp/BiasByDistance.html \\select radar_id, rangecat*50+25 as mean_range_km, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

-- Bias by site, height, and regime(s), for given gv source
select radar_id, height, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime like 'S_%' and numpts>0 and gvtype='GeoM' group by 1,2 order by 1,2;


-- "Best" bias regime (stratiform above BB), broken out by site, GV type and range:
select gvtype, radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanpr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangv, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- Non-site/regime-specific summary stats, broken out by GV type, height and range only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height, rangecat
 into temp dbzsums from dbzdiff_stats_by_dist_geo_V6BBrel where meandiff > -99.9
 group by 4,5,6 order by 4,5,6; 
select round(100.*w/n)/100. as bias, gvtype, height, rangecat from dbzsums; 

-- Full breakout: site, regime, raintype, height and range
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(prmean*numpts) as p, sum(gvmean*numpts) as g,
       max(prmax) as px, max(gvmax) as gx,
       sum(numpts) as n, gvtype, regime, radar_id, height, rangecat
  into temp sitedbzsums from dbzdiff_stats_by_dist
 where meandiff > -99.9 and diffstddev > -99.9
 group by 8,9,10,11,12 order by 8,9,10,11,12;

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(a.s/a.n))/100 as stddev2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, round(100*(b.s/b.n))/100 as stddevREORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat order by 1,2,4,3;

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddev2A55, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_2A55, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_REOR, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddevREOR, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_REOR, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, round(100*SUM(a.w)/SUM(a.n))/100 as bias_vs_GRID, round(100*SUM(b.w)/SUM(b.n))/100 as bias_vs_GEOM, round(100*SUM(a.s)/SUM(a.n))/100 as stddevGRID, round(100*SUM(b.s)/SUM(b.n))/100 as stddevGEOM, SUM(a.n) as num_GRID, SUM(b.n) as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' group by 1,2 order by 1,2;

-- "Best" bias regime (stratiform above BB), broken out by site and month, for 2A55:
select a.radar_id, date_trunc('month',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel a, overpass_event b where regime='S_above' and numpts>5 and percent_of_bins=95 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id ='KAMX' group by 1,2 order by 1,2;

-- Vertical profiles of PR and GV mean Z:
select radar_id, height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo_V6BBrel where rangecat<2 and regime like 'S_%' and numpts > 0 group by 1,2 order by 1,2;

select gvtype, radar_id, height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo_V6BBrel where rangecat<2 group by 1,2,3 order by 2,1,3;

--Strat profile for V7, non-BB
select height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo_V6BBrel where rangecat<2 and regime in ('S_above','S_below') and numpts > 0 and radar_id < 'KWAJ' group by 1 order by 1;
 height |  pr   |  gv   |   n   
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
--Conv profile for V7, non-BB
select height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo_V6BBrel where rangecat<2 and regime in ('C_above','C_below') and numpts > 0 and radar_id < 'KWAJ' group by 1 order by 1;
 height |  pr   |  gv   |   n   
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
select height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo where rangecat<2 and regime in ('S_above','S_below') and numpts > 0 and radar_id < 'KWAJ' and orbit between 57821 and 63364 group by 1 order by 1;
 height |  pr   |  gv   |   n   
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
select height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_geo where rangecat<2 and regime in  ('C_above','C_below') and numpts > 0 and radar_id < 'KWAJ' and orbit between 57821 and 63364 group by 1 order by 1;
 height |  pr   |  gv   |   n   
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

-- Both profiles for V7 for input to plot_mean_profiles.pro
select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_V6BBrel b, dbzdiff_stats_by_dist_geo_V6BBrel c where a.rangecat<2 and a.regime in ('C_above','C_below') and a.numpts > 4 and b.numpts>4 and c.numpts > 4 and a.radar_id < 'KWAJ' and b.regime in ('S_above','S_below') and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat group by 1 order by 1;
 height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
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
select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo b, dbzdiff_stats_by_dist_geo c where a.rangecat<2 and a.regime in ('C_above','C_below') and a.numpts > 4 and b.numpts>4 and c.numpts > 4 and a.radar_id < 'KWAJ' and b.regime in ('S_above','S_below') and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.orbit between 57821 and 63364 group by 1 order by 1;
 height |  prc  |  gvc  |  nc   |  prs  |  gvs  |  ns   |  pr   |  gv   |   n   
--------+-------+-------+-------+-------+-------+-------+-------+-------+-------
    1.5 | 40.42 | 40.58 | 31223 | 28.05 | 28.13 | 47491 | 33.44 | 33.59 | 73076
      3 | 37.69 | 38.69 | 15472 | 27.13 | 27.71 | 31624 | 31.49 | 32.28 | 61355
    4.5 | 31.62 | 32.63 | 25103 |  24.1 | 25.59 | 25327 | 28.27 | 29.78 | 50955
      6 | 30.21 |  31.4 | 26672 | 23.35 | 24.77 | 32293 | 26.13 | 27.48 | 46792
    7.5 | 29.05 | 30.36 | 12409 | 22.56 | 23.77 | 10877 | 25.63 | 26.95 | 17613
      9 |  29.4 | 30.83 |  2526 | 21.99 | 23.05 |  1140 | 26.78 | 28.14 |  2603
   10.5 | 27.59 | 29.55 |    48 | 24.51 | 25.72 |    27 | 26.39 | 28.07 |    51
(7 rows)

-- get a common set of samples between v6 and v7
drop table commontemp;
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('C_in', 'S_in', 'Total') and a.orbit between 65701 and 69085;
drop table convtemp;
drop table strattemp;
drop table alltemp;

select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, sum(a.numpts) as nc into temp convtemp from dbzdiff_stats_by_dist_geo_V6BBrel a, commontemp d where a.regime in ('C_above','C_below')  and a.numpts > 4 and a.height=d.height and a.orbit=d.orbit and a.radar_id=d.radar_id and a.rangecat = d.rangecat and a.regime = d.regime group by 1 order by 1;

select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, sum(b.numpts) as ns into temp strattemp from dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp d where b.regime in ('S_above','S_below') and b.numpts > 4 and d.height=b.height and d.orbit=b.orbit and d.radar_id=b.radar_id and d.rangecat = b.rangecat and d.regime = b.regime group by 1 order by 1;

select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, sum(c.numpts) as n into temp alltemp from dbzdiff_stats_by_dist_geo_V6BBrel c, commontemp d where c.height=d.height and c.orbit=d.orbit and c.radar_id=d.radar_id and c.rangecat = d.rangecat and c.regime = d.regime and c.numpts > 4 group by 1 order by 1;

select a.*, prs, gvs, ns, pr, gv, n from convtemp a, strattemp b, alltemp c where a.height=b.height and b.height=c.height;

-- "Best" bias regime (stratiform above BB), broken out by site only, V6 vs. V7:
select a.radar_id, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as v6meandiff, sum(a.numpts) as n_v6, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as v7meandiff, sum(b.numpts) as n_v7 from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp c where a.regime='S_above' and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime group by 1 order by 1;

-- All regimes broken out by site and regime, V6 vs. V7:
select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total');

select a.radar_id, a.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as v6meandiff, sum(a.numpts) as n_v6, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as v7meandiff, sum(b.numpts) as n_v7 from dbzdiff_stats_by_dist_geo a, dbzdiff_stats_by_dist_geo_V6BBrel b, commontemp c where  a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime group by 1,2 order by 2,1;
 radar_id | regime  | v6meandiff | n_v6  | v7meandiff | n_v7  
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
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsgeo from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 and gvtype='GeoM' and rangecat<2 group by 1,2 order by 1,2;
          
-- Case-by-case differences for 2A55
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp stats2a55 from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 and percent_of_bins=95 and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences for REOR
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsreo from dbzdiff_stats_by_dist_geo_V6BBrel where regime='S_above' and numpts>5 and gvtype='REOR' and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences for all 3 GV sources, side-by-side
select a.radar_id, b.orbit, a.meanmeandiff as diffgeo, b.meanmeandiff as diff55, c.meanmeandiff as diffreo, a.total as numgeo, b.total as num55, c.total as numreo into temp statsall from statsgeo a, stats2a55 b, statsreo c where a.radar_id = b.radar_id and b.radar_id = c.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- Site-specific mean differences for all 3 GV sources, over all cases
select radar_id, round((sum(diffgeo*numgeo)/sum(numgeo))*100)/100 as meangeo, round((sum(diff55*num55)/sum(num55))*100)/100 as mean55, round((sum(diffreo*numreo)/sum(numreo))*100)/100 as meanreo into temp statsmeanall from statsall group by 1 order by 1; 

-- Case-by-case differences from the site's long term mean difference over all cases
select a.radar_id, b.orbit, a.meanmeandiff-meangeo as diffgeo, b.meanmeandiff-mean55 as diff55, c.meanmeandiff-meanreo as diffreo, a.total as numgeo, b.total as num55, c.total as numreo into temp statsfromltmean from statsgeo a, stats2a55 b, statsreo c, statsmeanall d where a.radar_id = b.radar_id and b.radar_id = c.radar_id and c.radar_id=d.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- Number of cases whose deviation from the long-term difference exceeds 1 dbz, by source
select radar_id, count(*) as ngeo into temp geo_off from statsfromltmean where abs(diffgeo) > 1  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_off from statsfromltmean where abs(diffreo) > 1  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_off from statsfromltmean where abs(diff55) > 1  group by 1 order by 1;
select a.radar_id, ngeo, n55, nreo from geo_off a, a55_off b, reo_off c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id);
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30 from statsfromltmean where abs(diffgeo) > 1 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30 a, a55_off b, reo_off c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30 a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id);

-- Number of cases whose deviation from the long-term difference exceeds 2 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby2 from statsfromltmean where abs(diffgeo) > 2  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby2 from statsfromltmean where abs(diffreo) > 2  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby2 from statsfromltmean where abs(diff55) > 2  group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_offby2 a, a55_offby2 b, reo_offby2 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_offby2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id);
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by2 from statsfromltmean where abs(diffgeo) > 2 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30by2 a, a55_offby2 b, reo_offby2 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30by2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id);

-- Number of cases whose deviation from the long-term difference exceeds 3 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby3 from statsfromltmean where abs(diffgeo) > 3  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby3 from statsfromltmean where abs(diffreo) > 3  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby3 from statsfromltmean where abs(diff55) > 3  group by 1 order by 1;
select a.radar_id, ngeo, n55, nreo from geo_offby3 a, a55_offby3 b, reo_offby3 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by3 from statsfromltmean where abs(diffgeo) > 3 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30by3 a, a55_offby3 b, reo_offby3 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30by3 a full outer join a55_offby3 using (radar_id) full outer join reo_offby3 using (radar_id);

-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /tmp/event_best_diffs95pts25.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW','KWAJ') and percent_of_bins=95 group by 1,2 order by 1,2;

select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvmax)*100)/100) as gvmax, round((max(prmax)*100)/100) as prmax, sum(numpts) as total from dbzdiff_stats_by_dist_geo_V6BBrel a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') group by 1,2 order by 1,2;
