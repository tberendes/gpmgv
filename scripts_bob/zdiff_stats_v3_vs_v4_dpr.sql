-- IDL> stats_by_dist_to_dbfile_dpr_pr_geo_match, pct=70, NAME_ADD='Block10_V03B', NCSITE='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_21/', out='/tmp', alt_BB='/data/tmp/GPM_rain_event_bb_km_Uniq.txt', VERSION2MATCH='V4ITE', MAX_BLOCKAGE=0.1, s2ku=0

-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table zdiff_stats_dpr_v4 (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prstddev float,
   gvstddev float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

delete from zdiff_stats_dpr_v4;
\copy zdiff_stats_dpr_v4 from '/tmp/StatsByDist_DPR_GR_Pct70_Block10_V4ITE_AltBB_DefaultS.unl' with delimiter '|' 

create table zdiff_stats_dpr_v4_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prstddev float,
   gvstddev float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

delete from zdiff_stats_dpr_v4_s2ku;
\copy zdiff_stats_dpr_v4_s2ku from '/tmp/StatsByDist_DPR_GR_Pct70_Block10_V4ITE_AltBB_S2Ku.unl' with delimiter '|'

-- CREATE TABLES FOR THE DPR V03B DATA

create table zdiff_stats_dpr_v3 (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prstddev float,
   gvstddev float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

delete from zdiff_stats_dpr_v3;
\copy zdiff_stats_dpr_v3 from '/tmp/StatsByDist_DPR_GR_Pct70_Block10_V03B_AltBB_DefaultS.unl' with delimiter '|' 

create table zdiff_stats_dpr_v3_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prstddev float,
   gvstddev float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

delete from zdiff_stats_dpr_v3_s2ku;
\copy zdiff_stats_dpr_v3_s2ku from '/tmp/StatsByDist_DPR_GR_Pct70_Block10_V03B_AltBB_S2Ku.unl' with delimiter '|'

-- merge the unadjusted GR diffs in the two versions into a single temp table,
-- matched one-to-one by primary key attributes

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.meandiff as meandiffv4, b.meandiff as meandiffv3, a.numpts as numptsv4, b.numpts as numptsv3 into temp merged_diffs from zdiff_stats_dpr_v4 a join zdiff_stats_dpr_v3 b USING (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height);

select count(*) from merged_diffs;

-- ditto for Ku-adjusted statistics

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.meandiff as meandiffv4, b.meandiff as meandiffv3, a.numpts as numptsv4, b.numpts as numptsv3 into temp merged_diffs_s2ku from zdiff_stats_dpr_v4_s2ku a join zdiff_stats_dpr_v3_s2ku b USING (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height);

select count(*) from merged_diffs_s2ku;

-- "Best" bias regime (stratiform above BB), broken out by site only, for V4 vs V3, 
-- with differences reversed to GR-DPR:

select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv3) as total_v3, sum(numptsv4) as total_v4 from merged_diffs where regime='S_above' and numptsv3>5 and numptsv4>5 group by 1 order by 1;

-- output above info to delimited table, with lat/lon information, in order needed to plot on map

\t \a \o /tmp/GR_DPR_Bias_unadj_LL_Pct70.unl \\
select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, sum(numptsv3) as total_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs a, fixed_instrument_location f where regime='S_above' and numptsv3>5 and numptsv4>5 and a.radar_id=f.instrument_id and a.radar_id between 'KAAA' and 'KWAI' group by radar_id, latitude,longitude order by radar_id;

-- as above, but S-to-KU adjustments

\t \a 
\o /tmp/GR_DPR_Bias_KuAdj_LL_Pct70.unl \\
select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, sum(numptsv3) as total_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs_s2ku a, fixed_instrument_location f where regime='S_above' and numptsv3>5 and numptsv4>5 and a.radar_id=f.instrument_id and a.radar_id between 'KAAA' and 'KWAI' group by radar_id, latitude,longitude order by radar_id;

-- CONVECTIVE near-surface biases

select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv3) as total_v3, sum(numptsv4) as total_v4 from merged_diffs where regime='C_below' and numptsv3>5 and numptsv4>5 group by 1 order by 1;

-- output above info to delimited table, with lat/lon information, in order needed to plot on map

\t \a \o /tmp/GR_DPR_ConvBias_unadj_LL_Pct70_Block10.unl \\
select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, sum(numptsv3) as total_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs a, fixed_instrument_location f where regime='C_below' and numptsv3>5 and numptsv4>5 and a.radar_id=f.instrument_id and a.radar_id between 'KAAA' and 'KWAI' and a.radar_id != 'KING' group by radar_id, latitude,longitude order by radar_id;

-- as above, but S-to-KU adjustments

\t \a 
\o /tmp/GR_DPR_ConvBias_KuAdj_LL_Pct70_Block10.unl \\
select radar_id, round((sum(meandiffv3*numptsv3)/sum(numptsv3))*100)/100*(-1) as meandiff_v3, sum(numptsv3) as total_v3, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs_s2ku a, fixed_instrument_location f where regime='C_below' and numptsv3>5 and numptsv4>5 and a.radar_id=f.instrument_id and a.radar_id between 'KAAA' and 'KWAI' and a.radar_id != 'KING' group by radar_id, latitude,longitude order by radar_id;


------------------------------------ OLD WAY -----------------------------------------------

-- "Best" bias regime (stratiform above BB), broken out by site only, for V4 vs V3:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_pr, sum(numpts) as total_pr into temp diffsV4 from zdiff_stats_dpr_v4 where regime='S_above' and numpts>5 group by 1 order by 1;

select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsV3 from zdiff_stats_dpr_v3 a where regime='S_above' and numpts>5 group by 1 order by 1;

-- \H \o /tmp/GR_V3_V4_Bias_unadj.html \\select a.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr from diffsV4 a, diffsV3 b where a.radar_id=b.radar_id;

-- matched sites, original GR, no lat/lon columns to trigger SE US plot for all sources and diff
\t \a \o /tmp/GR_DPR_Bias_unadj_LL.unl \\select b.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from diffsV4 a, diffsV3 b, fixed_instrument_location f where a.radar_id=b.radar_id and a.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';

-- all GPM CONUS with fill for V4 values
\o /tmp/GR_V3_V4_Bias_unadj_LL_AllConus.unl \\select b.radar_id, COALESCE(a.meandiff_pr*(-1), 0.0) as gr_pr_diff_pr, COALESCE(a.total_pr,0), b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from fixed_instrument_location f, diffsV3 b left outer join diffsV4 a on a.radar_id=b.radar_id where b.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';

-- as above, but S-to-KU adjustements
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_pr, sum(numpts) as total_pr into temp diffsV4s2ku from zdiff_stats_dpr_v4_s2ku where regime='S_above' and numpts>5 group by 1 order by 1;



-- as in the above queries, but with DPR values only, and with another column for percent_of_bins
drop table diffsV3Pct;
select radar_id, percent_of_bins, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsV3Pct from zdiff_stats_dpr_v3 a where regime='S_above' and numpts>5 group by 1,2 order by 1,2;

drop table diffsV3s2kuPct;
select radar_id, percent_of_bins, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsV3s2kuPct from zdiff_stats_dpr_v3_s2ku where regime='S_above' and numpts>5 group by 1,2 order by 1,2;

-- all GPM CONUS, by Pct, with no V4 values
\o /tmp/GR_DPR_Bias_KUadj_LL_AllConus_Pct.unl \\select b.radar_id, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude, b.percent_of_bins from fixed_instrument_location f, diffsV3s2kuPct b where b.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI' order by 6,1;

-- all GPM non-CONUS, by Pct, with no V4 values
\o /tmp/GR_DPR_Bias_KUadj_LL_OffConus_Pct.unl \\select b.radar_id, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude, b.percent_of_bins from fixed_instrument_location f, diffsV3s2kuPct b where b.radar_id=f.instrument_id and b.radar_id NOT between 'KAAA' and 'KWAI' order by 6,1;



select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_pr, sum(numpts) as total_pr into temp diffsV4s2ku from zdiff_stats_dpr_v4_s2ku where regime='S_above' and numpts>5 and orbit >92951 group by 1 order by 1;

select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsV3s2ku from zdiff_stats_dpr_v3_s2ku where regime='S_above' and numpts>5 group by 1 order by 1;

-- matched sites, Ku-adjusted GR, no lat/lon columns to trigger SE US plot for all sources and diff
\o /tmp/GR_V3_V4_Bias_KUadj.unl \\select a.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr from diffsV4s2ku a, diffsV3s2ku b where a.radar_id=b.radar_id and b.radar_id between 'KAAA' and 'KWAI';

-- all GPM CONUS with fill for V4 values
\o /tmp/GR_DPR_Bias_KUadj_LL_AllConus.unl \\select b.radar_id, COALESCE(a.meandiff_pr*(-1), 0.0) as gr_pr_diff_pr, COALESCE(a.total_pr,0), b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from fixed_instrument_location f, diffsV3s2ku b left outer join diffsV4s2ku a on a.radar_id=b.radar_id where b.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';



-- INPUT FOR PLOT_EVENT_SERIES.PRO

\t \a \f '|' \o /data/tmp/stats_for_db/event_best_diffsV4Pct70s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC') aS event_date, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zbias, sum(numpts) as total, round((sum(diffstddev*numpts)/sum(numpts))*100)/100 as bias_stddev from zdiff_stats_dpr_v4_s2ku a, overpass_event b where regime='S_above' and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id in ('KDDC','KEAX','KFWS','KGRK','KHGX','KSHV','KDOX','KWAJ','PAIH') and b.sat_id='GPM' and percent_of_bins=70 group by 1,2 order by 1,2;




\t \a \f '|' \o /tmp/event_best_diffsV4Pct100pts5origS.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_dpr_v4 a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and b.sat_id='PR' and percent_of_bins=100 group by 1,2 order by 1,2;

 \f '|' \o /tmp/event_best_diffsV4Pct100pts5s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_dpr_v4_s2ku a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and b.sat_id='PR' and percent_of_bins=100 group by 1,2 order by 1,2;

\f '|' \o /tmp/event_best_diffsV3Pct100pts5origS.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_dpr_v3 a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and b.sat_id='GPM' and percent_of_bins=100 group by 1,2 order by 1,2;

 \f '|' \o /tmp/event_best_diffsV3Pct100pts5s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_dpr_v3_s2ku a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and b.sat_id='GPM' and percent_of_bins=100 group by 1,2 order by 1,2;

select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvstddev)*100)/100) as gvstddev, round((max(prstddev)*100)/100) as prstddev, sum(numpts) as total from zdiff_stats_by_dist_time_geo a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') group by 1,2 order by 1,2;
