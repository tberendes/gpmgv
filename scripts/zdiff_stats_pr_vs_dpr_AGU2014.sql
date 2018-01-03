-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table zdiff_stats_pr (
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

delete from zdiff_stats_pr;
--\copy zdiff_stats_pr from '/data/tmp/StatsByDist_PR_GR_Pct70_StdDevMode__DefaultS.unl' with delimiter '|' 
\copy zdiff_stats_pr from '/data/tmp/StatsByDist_PR_GR_Pct70_StdDevMode_allYrs_150427_DefaultS.unl' with delimiter '|' 

create table zdiff_stats_pr_s2ku (
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

delete from zdiff_stats_pr_s2ku;
--\copy zdiff_stats_pr_s2ku from '/data/tmp/StatsByDist_PR_GR_Pct70_StdDevMode__S2Ku.unl' with delimiter '|' 
\copy zdiff_stats_pr_s2ku from '/data/tmp/StatsByDist_PR_GR_Pct70_StdDevMode_allYrs_150427_S2Ku.unl' with delimiter '|'

-- CREATE TABLES FOR THE DPR DATA

create table zdiff_stats_dpr (
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

delete from zdiff_stats_dpr;
--\copy zdiff_stats_dpr from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode__DefaultS.unl' with delimiter '|' 
\copy zdiff_stats_dpr from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode_allYrs_150427_AltBB_DefaultS.unl' with delimiter '|' 

create table zdiff_stats_dpr_s2ku (
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

delete from zdiff_stats_dpr_s2ku;
--\copy zdiff_stats_dpr_s2ku from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode__S2Ku.unl' with delimiter '|' 
\copy zdiff_stats_dpr_s2ku from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode_allYrs_150427_AltBB_S2Ku.unl' with delimiter '|'

-- "Best" bias regime (stratiform above BB), broken out by site only, for PR vs DPR:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_pr, sum(numpts) as total_pr into temp diffsPR from zdiff_stats_pr where regime='S_above' and numpts>5 and orbit >92951 group by 1 order by 1;

select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsGPM from zdiff_stats_dpr a where regime='S_above' and numpts>5 and orbit<6198 group by 1 order by 1;

-- \H \o /data/tmp/GR_PR_DPR_Bias_unadj.html \\select a.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr from diffsPR a, diffsGPM b,  where a.radar_id=b.radar_id;

-- matched sites, original GR, no lat/lon columns to trigger SE US plot for all sources and diff
\t \a \o /data/tmp/GR_DPR_Bias_unadj_LL.unl \\select b.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from diffsPR a, diffsGPM b, fixed_instrument_location f where a.radar_id=b.radar_id and a.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';

-- all GPM CONUS with fill for PR values
\o /data/tmp/GR_PR_DPR_Bias_unadj_LL_AllConus.unl \\select b.radar_id, COALESCE(a.meandiff_pr*(-1), 0.0) as gr_pr_diff_pr, COALESCE(a.total_pr,0), b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from fixed_instrument_location f, diffsGPM b left outer join diffsPR a on a.radar_id=b.radar_id where b.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';

-- as above, but S-to-KU adjustements
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_pr, sum(numpts) as total_pr into temp diffsPRs2ku from zdiff_stats_PR_s2ku where regime='S_above' and numpts>5 and orbit >92951 and percent_of_bins=100 group by 1 order by 1;

select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff_dpr, sum(numpts) as total_dpr into temp diffsGPMs2ku from zdiff_stats_DPR_s2ku where regime='S_above' and numpts>5 and orbit<6198 and percent_of_bins=100 group by 1 order by 1;

-- matched sites, Ku-adjusted GR, no lat/lon columns to trigger SE US plot for all sources and diff
\o /data/tmp/GR_PR_DPR_Bias_KUadj.unl \\select a.radar_id, a.meandiff_pr*(-1) as gr_pr_diff_pr, a.total_pr, b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr from diffsPRs2ku a, diffsGPMs2ku b where a.radar_id=b.radar_id and b.radar_id between 'KAAA' and 'KWAI';

-- all GPM CONUS with fill for PR values
\o /data/tmp/GR_DPR_Bias_KUadj_LL_AllConus.unl \\select b.radar_id, COALESCE(a.meandiff_pr*(-1), 0.0) as gr_pr_diff_pr, COALESCE(a.total_pr,0), b.meandiff_dpr*(-1) as gr_pr_diff_dpr, b.total_dpr, f.latitude, f.longitude from fixed_instrument_location f, diffsGPMs2ku b left outer join diffsPRs2ku a on a.radar_id=b.radar_id where b.radar_id=f.instrument_id and b.radar_id between 'KAAA' and 'KWAI';



-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /data/tmp/event_best_diffsPRpct70pts5origS.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_pr a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and percent_of_bins=70 group by 1,2 order by 1,2;

\t \a \f '|' \o /data/tmp/event_best_diffsPRpct70pts5s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from zdiff_stats_pr_s2ku a, overpass_event b where regime='S_above' and numpts>5 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id between 'KAAA' and 'KWAI' and percent_of_bins=70 group by 1,2 order by 1,2;

select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvstddev)*100)/100) as gvstddev, round((max(prstddev)*100)/100) as prstddev, sum(numpts) as total from zdiff_stats_by_dist_time_geo a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') group by 1,2 order by 1,2;
