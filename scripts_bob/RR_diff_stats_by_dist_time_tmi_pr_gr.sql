-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table rrdiff_stats_by_dist_time_tmi_pr_v6 (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
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
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height, timediff)
);


create table rrdiff_stats_by_dist_time_tmi_pr_v6_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
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
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height, timediff)
);

delete from rrdiff_stats_by_dist_time_tmi_pr_v6;

\copy rrdiff_stats_by_dist_time_tmi_pr_v6 from '/data/gpmgv/tmp/TMI_PR_RR_StatsByDistToDB_Pct50_V6_ZRx2_DefaultS.unl' with delimiter '|'

delete from rrdiff_stats_by_dist_time_tmi_pr_v6_s2ku;

\copy rrdiff_stats_by_dist_time_tmi_pr_v6_s2ku from '/data/gpmgv/tmp/TMI_PR_RR_StatsByDistToDB_Pct50_V6_ZRx2_S2Ku.unl' with delimiter '|'

create table rrdiff_stats_by_dist_time_tmi_pr_v7 (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
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
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height, timediff)
);


create table rrdiff_stats_by_dist_time_tmi_pr_v7_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
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
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height, timediff)
);

delete from rrdiff_stats_by_dist_time_tmi_pr_v7;

\copy rrdiff_stats_by_dist_time_tmi_pr_v7 from '/data/gpmgv/tmp/TMI_PR_RR_StatsByDistToDB_Pct50_V7_ZRx2_DefaultS.unl' with delimiter '|'

delete from rrdiff_stats_by_dist_time_tmi_pr_v7_s2ku;

\copy rrdiff_stats_by_dist_time_tmi_pr_v7_s2ku from '/data/gpmgv/tmp/TMI_PR_RR_StatsByDistToDB_Pct50_V7_ZRx2_S2Ku.unl' with delimiter '|'


-- differences and profiles by height/percent:
select height, percent_of_bins, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanprv, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangr, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'C_%' and numpts>5 and radar_id='KMLB' group by 1,2 order by 1,2;
select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totalany into temp anytotal from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='Total' group by 1,2,3,4,5,6;


select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totaltypes into temp totalbytypes from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime!='Total' group by 1,2,3,4,5,6;

select a.*, b.totaltypes from anytotal a, totalbytypes b where a.percent_of_bins = b.percent_of_bins and a.rangecat = b.rangecat and a.gvtype = b.gvtype and a.radar_id = b.radar_id and a.orbit = b.orbit and a.height = b.height and a.totalany < b.totaltypes;

-- "Best" bias regime (stratiform above BB), broken out by site and range:
select radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>5 and percent_of_bins=100 group by 1,2 order by 1,2;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinmax/10)*10+5 as grmaxz, regime, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S%' and numpts>0 group by 3,2 order by 1;

select round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round(gvbinstddev/3)*3 as stddev, regime, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S%' and numpts>5 group by 3,2 order by 3,2;
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
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>5 group by 1 order by 1;

-- As above, but output to HTML table
\o /data/tmp/BiasByDistance.html \\select radar_id, rangecat*50+25 as mean_range_km, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>5 and percent_of_bins=100 group by 1,2 order by 1,2;

-- Bias by site and gv source, for given regime(s), at 1.5km GR CAPPI level

select radar_id, gvtype||'-Conv' as zr_type,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'C_%' and numpts>5 and height=1.5 group by 1,2 order by 1,2;

 radar_id |  zr_type  | rr_diff | total 
----------+-----------+---------+-------
 RGSN     | BYPR-Conv |   -4.64 |  2013
 RGSN     | CAPI-Conv |    8.64 |  2013
 RGSN     | ZOFF-Conv |    4.85 |  2013
 RJNI     | BYPR-Conv |   -0.68 |  3556
 RJNI     | CAPI-Conv |    4.84 |  3556
 RJNI     | ZOFF-Conv |    6.72 |  3556
 RPSN     | BYPR-Conv |     0.6 |  3110
 RPSN     | CAPI-Conv |    9.18 |  3110
 RPSN     | ZOFF-Conv |    8.95 |  3110
 RSSP     | BYPR-Conv |    0.04 |  1698
 RSSP     | CAPI-Conv |    7.91 |  1698
 RSSP     | ZOFF-Conv |    5.03 |  1698
(12 rows)

select radar_id, gvtype||'-Strat' as zr_type,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S_%' and numpts>5 and height=1.5 group by 1,2 order by 1,2;

 radar_id |  zr_type   | rr_diff | total 
----------+------------+---------+-------
 RGSN     | BYPR-Strat |    -0.2 | 24219
 RGSN     | CAPI-Strat |    0.77 | 24219
 RGSN     | ZOFF-Strat |    0.18 | 24219
 RJNI     | BYPR-Strat |    0.01 | 34180
 RJNI     | CAPI-Strat |    0.02 | 34180
 RJNI     | ZOFF-Strat |    0.29 | 34180
 RPSN     | BYPR-Strat |    0.47 | 26250
 RPSN     | CAPI-Strat |    0.81 | 26250
 RPSN     | ZOFF-Strat |    0.78 | 26250
 RSSP     | BYPR-Strat |     0.2 | 20365
 RSSP     | CAPI-Strat |    0.87 | 20365
 RSSP     | ZOFF-Strat |    0.42 | 20365
(12 rows)


-- Bias by site, GR offset, and time offset in minutes for Stratiform, 1.5 km CAPPI level
select radar_id, gvtype||'-Strat', round((timediff+30)/60), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S_%' and numpts>5 and height=1.5 group by 1,2,3 order by 1,2,3;
 radar_id |  ?column?  | round | meandiffavg | total 
----------+------------+-------+-------------+-------
 RGSN     | CAPI-Strat |    -1 |        0.48 |   307
 RGSN     | CAPI-Strat |     0 |        0.82 |  4343
 RGSN     | CAPI-Strat |     1 |        0.73 |  2498
 RGSN     | CAPI-Strat |     2 |         0.8 |  1254
 RGSN     | CAPI-Strat |     3 |        1.06 |  2768
 RGSN     | CAPI-Strat |     4 |        0.72 |  4543
 RGSN     | CAPI-Strat |     5 |         0.8 |  2224
 RGSN     | CAPI-Strat |     6 |        0.67 |  2612
 RGSN     | CAPI-Strat |     7 |        0.57 |  1803
 RGSN     | CAPI-Strat |     8 |        0.78 |  1847
 RGSN     | CAPI-Strat |     9 |       -0.07 |    20
 RGSN     | ZOFF-Strat |    -1 |       -0.08 |   307
 RGSN     | ZOFF-Strat |     0 |        0.26 |  4343
 RGSN     | ZOFF-Strat |     1 |        0.25 |  2498
 RGSN     | ZOFF-Strat |     2 |        0.28 |  1254
 RGSN     | ZOFF-Strat |     3 |        0.44 |  2768
 RGSN     | ZOFF-Strat |     4 |        0.09 |  4543
 RGSN     | ZOFF-Strat |     5 |         0.1 |  2224
 RGSN     | ZOFF-Strat |     6 |        0.11 |  2612
 RGSN     | ZOFF-Strat |     7 |       -0.03 |  1803
 RGSN     | ZOFF-Strat |     8 |        0.16 |  1847
 RGSN     | ZOFF-Strat |     9 |        -0.5 |    20
 RJNI     | CAPI-Strat |    -1 |       -0.06 |  3580
 RJNI     | CAPI-Strat |     0 |       -0.07 |  6351
 RJNI     | CAPI-Strat |     1 |       -0.15 |  3048
 RJNI     | CAPI-Strat |     2 |        0.04 |  3076
 RJNI     | CAPI-Strat |     3 |       -0.01 |  3442
 RJNI     | CAPI-Strat |     4 |        0.13 |  4376
 RJNI     | CAPI-Strat |     5 |       -0.49 |  2597
 RJNI     | CAPI-Strat |     6 |       -0.02 |  3142
 RJNI     | CAPI-Strat |     7 |         0.5 |  4493
 RJNI     | CAPI-Strat |     8 |        0.73 |    75
 RJNI     | ZOFF-Strat |    -1 |        0.22 |  3580
 RJNI     | ZOFF-Strat |     0 |        0.19 |  6351
 RJNI     | ZOFF-Strat |     1 |         0.1 |  3048
 RJNI     | ZOFF-Strat |     2 |        0.32 |  3076
 RJNI     | ZOFF-Strat |     3 |        0.28 |  3442
 RJNI     | ZOFF-Strat |     4 |         0.4 |  4376
 RJNI     | ZOFF-Strat |     5 |       -0.16 |  2597
 RJNI     | ZOFF-Strat |     6 |        0.27 |  3142
 RJNI     | ZOFF-Strat |     7 |        0.77 |  4493
 RJNI     | ZOFF-Strat |     8 |           1 |    75
 RPSN     | CAPI-Strat |    -4 |       -0.05 |   263
 RPSN     | CAPI-Strat |    -3 |        0.55 |  2525
 RPSN     | CAPI-Strat |    -2 |        0.09 |  2367
 RPSN     | CAPI-Strat |    -1 |        1.32 |  2064
 RPSN     | CAPI-Strat |     0 |        0.52 |  4400
 RPSN     | CAPI-Strat |     1 |        2.37 |  2700
 RPSN     | CAPI-Strat |     2 |        0.75 |  3023
 RPSN     | CAPI-Strat |     3 |        0.77 |  3600
 RPSN     | CAPI-Strat |     4 |        0.57 |  2371
 RPSN     | CAPI-Strat |     5 |        0.46 |  2479
 RPSN     | CAPI-Strat |     6 |        1.84 |   380
 RPSN     | CAPI-Strat |     7 |        0.29 |    78
 RPSN     | ZOFF-Strat |    -4 |       -0.07 |   263
 RPSN     | ZOFF-Strat |    -3 |        0.52 |  2525
 RPSN     | ZOFF-Strat |    -2 |        0.05 |  2367
 RPSN     | ZOFF-Strat |    -1 |        1.29 |  2064
 RPSN     | ZOFF-Strat |     0 |        0.49 |  4400
 RPSN     | ZOFF-Strat |     1 |        2.34 |  2700
 RPSN     | ZOFF-Strat |     2 |        0.72 |  3023
 RPSN     | ZOFF-Strat |     3 |        0.74 |  3600
 RPSN     | ZOFF-Strat |     4 |        0.54 |  2371
 RPSN     | ZOFF-Strat |     5 |        0.44 |  2479
 RPSN     | ZOFF-Strat |     6 |        1.82 |   380
 RPSN     | ZOFF-Strat |     7 |        0.27 |    78
 RSSP     | CAPI-Strat |    -1 |        0.55 |   114
 RSSP     | CAPI-Strat |     0 |        0.98 |  3717
 RSSP     | CAPI-Strat |     1 |        0.93 |  2414
 RSSP     | CAPI-Strat |     2 |        0.73 |  1106
 RSSP     | CAPI-Strat |     3 |        1.16 |  1571
 RSSP     | CAPI-Strat |     4 |        0.81 |  4298
 RSSP     | CAPI-Strat |     5 |        0.83 |  1739
 RSSP     | CAPI-Strat |     6 |         0.6 |  1968
 RSSP     | CAPI-Strat |     7 |        1.01 |  2477
 RSSP     | CAPI-Strat |     8 |         0.6 |   961
 RSSP     | ZOFF-Strat |    -1 |         0.2 |   114
 RSSP     | ZOFF-Strat |     0 |        0.55 |  3717
 RSSP     | ZOFF-Strat |     1 |        0.52 |  2414
 RSSP     | ZOFF-Strat |     2 |        0.31 |  1106
 RSSP     | ZOFF-Strat |     3 |         0.7 |  1571
 RSSP     | ZOFF-Strat |     4 |         0.3 |  4298
 RSSP     | ZOFF-Strat |     5 |        0.29 |  1739
 RSSP     | ZOFF-Strat |     6 |        0.22 |  1968
 RSSP     | ZOFF-Strat |     7 |        0.55 |  2477
 RSSP     | ZOFF-Strat |     8 |        0.17 |   961
(86 rows)
select radar_id, gvtype||'-Conv', round((timediff+30)/60), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'C_%' and numpts>5 and height=1.5 group by 1,2,3 order by 1,2,3;
 radar_id | ?column?  | round | meandiffavg | total 
----------+-----------+-------+-------------+-------
 RGSN     | CAPI-Conv |    -1 |        8.11 |    32
 RGSN     | CAPI-Conv |     0 |        11.9 |   296
 RGSN     | CAPI-Conv |     1 |        8.16 |   301
 RGSN     | CAPI-Conv |     2 |         6.2 |    61
 RGSN     | CAPI-Conv |     3 |        7.13 |   143
 RGSN     | CAPI-Conv |     4 |        7.81 |   456
 RGSN     | CAPI-Conv |     5 |        7.99 |   209
 RGSN     | CAPI-Conv |     6 |       12.96 |   256
 RGSN     | CAPI-Conv |     7 |        4.73 |   155
 RGSN     | CAPI-Conv |     8 |        4.47 |   104
 RGSN     | ZOFF-Conv |    -1 |        6.19 |    32
 RGSN     | ZOFF-Conv |     0 |        7.81 |   296
 RGSN     | ZOFF-Conv |     1 |        3.75 |   301
 RGSN     | ZOFF-Conv |     2 |        2.86 |    61
 RGSN     | ZOFF-Conv |     3 |        3.92 |   143
 RGSN     | ZOFF-Conv |     4 |        3.84 |   456
 RGSN     | ZOFF-Conv |     5 |        5.08 |   209
 RGSN     | ZOFF-Conv |     6 |        9.19 |   256
 RGSN     | ZOFF-Conv |     7 |        0.44 |   155
 RGSN     | ZOFF-Conv |     8 |        1.53 |   104
 RJNI     | CAPI-Conv |    -1 |        5.44 |   405
 RJNI     | CAPI-Conv |     0 |        3.91 |   721
 RJNI     | CAPI-Conv |     1 |        4.73 |   179
 RJNI     | CAPI-Conv |     2 |           1 |   148
 RJNI     | CAPI-Conv |     3 |        2.93 |   385
 RJNI     | CAPI-Conv |     4 |        5.46 |   526
 RJNI     | CAPI-Conv |     5 |        3.26 |   192
 RJNI     | CAPI-Conv |     6 |        5.01 |   561
 RJNI     | CAPI-Conv |     7 |        8.59 |   439
 RJNI     | ZOFF-Conv |    -1 |        7.34 |   405
 RJNI     | ZOFF-Conv |     0 |         5.8 |   721
 RJNI     | ZOFF-Conv |     1 |        6.29 |   179
 RJNI     | ZOFF-Conv |     2 |        2.86 |   148
 RJNI     | ZOFF-Conv |     3 |        5.33 |   385
 RJNI     | ZOFF-Conv |     4 |        7.19 |   526
 RJNI     | ZOFF-Conv |     5 |        5.31 |   192
 RJNI     | ZOFF-Conv |     6 |        6.99 |   561
 RJNI     | ZOFF-Conv |     7 |       10.08 |   439
 RPSN     | CAPI-Conv |    -4 |       -5.85 |    63
 RPSN     | CAPI-Conv |    -3 |        7.83 |   270
 RPSN     | CAPI-Conv |    -2 |        6.69 |   165
 RPSN     | CAPI-Conv |    -1 |        5.92 |   214
 RPSN     | CAPI-Conv |     0 |       11.09 |   547
 RPSN     | CAPI-Conv |     1 |        9.03 |   207
 RPSN     | CAPI-Conv |     2 |       10.76 |   490
 RPSN     | CAPI-Conv |     3 |        7.59 |   351
 RPSN     | CAPI-Conv |     4 |       12.44 |   470
 RPSN     | CAPI-Conv |     5 |        8.05 |   316
 RPSN     | CAPI-Conv |     6 |        9.48 |    17
 RPSN     | ZOFF-Conv |    -4 |       -6.25 |    63
 RPSN     | ZOFF-Conv |    -3 |        7.58 |   270
 RPSN     | ZOFF-Conv |    -2 |        6.47 |   165
 RPSN     | ZOFF-Conv |    -1 |        5.75 |   214
 RPSN     | ZOFF-Conv |     0 |       10.83 |   547
 RPSN     | ZOFF-Conv |     1 |        8.85 |   207
 RPSN     | ZOFF-Conv |     2 |       10.57 |   490
 RPSN     | ZOFF-Conv |     3 |        7.35 |   351
 RPSN     | ZOFF-Conv |     4 |       12.18 |   470
 RPSN     | ZOFF-Conv |     5 |        7.83 |   316
 RPSN     | ZOFF-Conv |     6 |        9.45 |    17
 RSSP     | CAPI-Conv |    -1 |        9.86 |    26
 RSSP     | CAPI-Conv |     0 |        8.06 |   379
 RSSP     | CAPI-Conv |     1 |         8.4 |   396
 RSSP     | CAPI-Conv |     2 |        4.73 |    59
 RSSP     | CAPI-Conv |     3 |        9.98 |    81
 RSSP     | CAPI-Conv |     4 |        9.69 |   218
 RSSP     | CAPI-Conv |     5 |       13.36 |    78
 RSSP     | CAPI-Conv |     6 |        5.83 |   153
 RSSP     | CAPI-Conv |     7 |        5.25 |   217
 RSSP     | CAPI-Conv |     8 |        5.69 |    91
 RSSP     | ZOFF-Conv |    -1 |        8.45 |    26
 RSSP     | ZOFF-Conv |     0 |        4.21 |   379
 RSSP     | ZOFF-Conv |     1 |        5.35 |   396
 RSSP     | ZOFF-Conv |     2 |        2.87 |    59
 RSSP     | ZOFF-Conv |     3 |        6.99 |    81
 RSSP     | ZOFF-Conv |     4 |        7.33 |   218
 RSSP     | ZOFF-Conv |     5 |        11.5 |    78
 RSSP     | ZOFF-Conv |     6 |        3.54 |   153
 RSSP     | ZOFF-Conv |     7 |        2.59 |   217
 RSSP     | ZOFF-Conv |     8 |        3.01 |    91
(80 rows)

-- "Best" bias regime (stratiform above BB), broken out by site, GV type and range:
select gvtype, radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanpr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangv, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- Non-site/regime-specific summary stats, broken out by GV type, height and range only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height, rangecat
 into temp dbzsums from rrdiff_stats_by_dist_time_tmi_pr_v6 where meandiff > -99.9
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


-- DIFFERENCES BY FRACTION OF CONVECTIVE VS. STRATIFORM RAIN

-- compute a percent stratiform and convective from the geo-match dataset
select percent_of_bins, radar_id, orbit, sum(numpts) as n_conv into temp npts_conv from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'C_%' group by 1,2,3 order by 1,2,3;
select percent_of_bins, radar_id, orbit, sum(numpts) as n_strat into temp npts_strat from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S_%' group by 1,2,3 order by 1,2,3;
select a.percent_of_bins, a.radar_id, a.orbit, round((cast(n_conv as float)/(n_conv+n_strat))*10)*10 as pct_conv into temp pct_conv_temp from npts_conv a, npts_strat b where a.percent_of_bins=b.percent_of_bins and a.radar_id=b.radar_id and a.orbit=b.orbit and (b.n_strat>0 OR a.n_conv>0);

-- compute convective and stratiform areas of rain at 3 km from the geo-match dataset
select percent_of_bins, radar_id, orbit, ((sum(numpts)/250)+1)*250 as n_conv into temp area_conv from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'C_%' and height=3 group by 1,2,3 order by 1,2,3;
select percent_of_bins, radar_id, orbit, ((sum(numpts)/250)+1)*250 as n_strat into temp area_strat from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime like 'S_%' and height=3 group by 1,2,3 order by 1,2,3;
-- compute mean bias, stdDev as function of area of precip for KMLB
select e.n_strat, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from rrdiff_stats_by_dist_time_tmi_pr_v6 c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%' and c.radar_id='KMLB' group by 1 order by 1;
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
select e.n_strat, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from rrdiff_stats_by_dist_time_tmi_pr_v6 c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%'  group by 1 order by 1;
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
 select e.n_strat, e.radar_id, round((sum(c.meandiff*c.numpts)/sum(c.numpts))*100)/100 as biasgeo,  round((sum(c.diffstddev*c.numpts)/sum(c.numpts))*100)/100 as stdev, sum(c.numpts) as ngeo from rrdiff_stats_by_dist_time_tmi_pr_v6 c, area_strat e where c.percent_of_bins=e.percent_of_bins and c.percent_of_bins=100 and c.orbit=e.orbit and c.radar_id=e.radar_id and c.regime like 'S_%' group by 1,2 order by 2,1;
 n_strat | radar_id | biasgeo | stdev | ngeo
---------+----------+---------+-------+-------
     250 | KAMX     |   -1.09 |   0.6 | 14682
     500 | KAMX     |   -0.94 |  2.04 |  5994
     750 | KAMX     |   -0.53 |  2.32 |  2476
    1000 | KAMX     |   -0.28 |  1.39 |  4580
    1250 | KAMX     |   -1.24 |   1.9 |  3495
    1750 | KAMX     |   -0.22 |  2.02 |  3783


-- Case-by-case differences for GeoM
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsgeo from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>5 and gvtype='GeoM' and rangecat<2 and percent_of_bins=100 group by 1,2 order by 1,2;
          
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

-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30 from statsfromltmean where abs(diffgeo) > 1 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo, n_cases from geo_off30 a, a55_off b, reo_off c, matchups d where a.radar_id=b.radar_id and b.radar_id = c.radar_id and c.radar_id = d.radar_id order by 1;
select * from geo_off30 a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id) full outer join matchups using (radar_id);
 radar_id | ngeo | n55 | nreo | n_cases
----------+------+-----+------+---------
 KAMX     |    2 |   5 |    3 |      28


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


-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /tmp/event_best_diffs95pts25.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and percent_of_bins=90 group by 1,2 order by 1,2;

select radar_id, orbit, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvmax)*100)/100) as gvmax, round((max(prmax)*100)/100) as prmax, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v6 where regime='S_above' and numpts>25  group by 1,2 order by 1,2;
