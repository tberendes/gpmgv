-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table dbzdiff_stats_by_dist_gpm_ku (
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


create table dbzdiff_stats_by_dist_gpm_ku_s2ku (
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


create table dbzdiff_stats_by_dist_gpm_ku_bbrel (
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


create table dbzdiff_stats_by_dist_gpm_ku_s2ku_bbrel (
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

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totalany into temp anytotal from dbzdiff_stats_by_dist_gpm_ku where regime='Total' group by 1,2,3,4,5,6;

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totaltypes into temp totalbytypes from dbzdiff_stats_by_dist_gpm_ku where regime!='Total' group by 1,2,3,4,5,6;

select a.*, b.totaltypes from anytotal a, totalbytypes b where a.percent_of_bins = b.percent_of_bins and a.rangecat = b.rangecat and a.gvtype = b.gvtype and a.radar_id = b.radar_id and a.orbit = b.orbit and a.height = b.height and a.totalany < b.totaltypes;

delete from dbzdiff_stats_by_dist_gpm_ku;
\copy dbzdiff_stats_by_dist_gpm_ku from '/data/tmp/stats_for_db/StatsByDist_DPR_GR_Pct70_StdDevMode_AllSites15dbzPct70_AltBB_DefaultS.unl' with delimiter '|' 
delete from dbzdiff_stats_by_dist_gpm_ku_s2ku;
\copy dbzdiff_stats_by_dist_gpm_ku_s2ku from '/data/tmp/stats_for_db/StatsByDist_DPR_GR_Pct70_StdDevMode_AllSites15dbzPct70_AltBB_S2Ku.unl' with delimiter '|' 
delete from dbzdiff_stats_by_dist_gpm_ku_bbrel;
\copy dbzdiff_stats_by_dist_gpm_ku_bbrel from '/data/tmp/StatsByDist_DPR_GR_Pct70_BBrel_DefaultS.unl' with delimiter '|' 
delete from dbzdiff_stats_by_dist_gpm_ku_s2ku_bbrel;
\copy dbzdiff_stats_by_dist_gpm_ku_s2ku_bbrel from '/data/tmp/StatsByDist_DPR_GR_Pct70_BBrel_S2Ku.unl' with delimiter '|' 

-- table with PR and GR sample Standard Deviations in place of Max values
create table dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd (
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
delete from dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd;
\copy dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode_BBrel_S2Ku.unl' with delimiter '|' 

-- "Best" bias regime (stratiform above BB), broken out by site and range:
select radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

-- "Best" bias regime (stratiform above BB), broken out by site only:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku where regime='S_above' and numpts>5 group by 1 order by 1;

-- As above, but output to HTML table
\o /data/tmp/BiasByDistance.html \\select radar_id, rangecat*50+25 as mean_range_km, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

-- Bias by site, height, and regime(s), for given gv source
select radar_id, height, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku where regime like 'S_%' and numpts>0 and gvtype='GeoM' group by 1,2 order by 1,2;


-- "Best" bias regime (stratiform above BB), broken out by site, GV type and range:
select gvtype, radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanpr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangv, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- Non-site/regime-specific summary stats, broken out by GV type, height and range only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height, rangecat
 into temp dbzsums from dbzdiff_stats_by_dist_gpm_ku where meandiff > -99.9
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

-- C, S, and Any AGL-based profiles for input to plot_mean_profiles.pro
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_gpm_ku a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_gpm_ku b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_gpm_ku c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- as above but S2Ku GR Z
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_gpm_ku_s2ku a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_gpm_ku_s2ku b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_gpm_ku_s2ku c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;


-- C, S, and Any  **BB-RELATIVE** profiles for input to plot_mean_profiles.pro
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_gpm_ku_bbrel a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_gpm_ku_bbrel b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_gpm_ku_bbrel c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- as above but S2Ku GR Z
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- Case-by-case differences for GeoM
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsgeo from dbzdiff_stats_by_dist_gpm_ku where regime='S_above' and numpts>5 and gvtype='GeoM' and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences from the site's long term mean difference over all cases
select a.radar_id, b.orbit, a.meanmeandiff-meangeo as diffgeo, a.total as numgeo into temp statsfromltmean from statsgeo a, stats2a55 b, statsreo c, statsmeanall d where a.radar_id = b.radar_id and b.radar_id = c.radar_id and c.radar_id=d.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /tmp/event_best_diffs_Ku_70pct_pts1_s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku_s2ku a, overpass_event b where regime='S_above' and numpts>1 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') and b.sat_id='GPM' and percent_of_bins=70 group by 1,2 order by 1 desc,2;

select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvmax)*100)/100) as gvmax, round((max(prmax)*100)/100) as prmax, sum(numpts) as total from dbzdiff_stats_by_dist_gpm_ku a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') group by 1,2 order by 1,2;


-- INPUT FOR plot_event_series_stacked_color_n_sd.pro with StdDev error bars
\t \a \f '|' \o /tmp/event_best_diffsDPRv4_Sabv_Pct70pts1origS.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total, round((sum(diffstddev*numpts)/sum(numpts))*100)/100 as meandiffstddev from dbzdiff_stats_by_dist_gpm_ku a, overpass_event b where regime='S_above' and numpts>1 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id != 'KING' and b.sat_id='GPM' and percent_of_bins=70 group by 1,2 order by 1,2;

 \f '|' \o /tmp/event_best_diffsDPRv4_Sabv_Pct70pts1s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total, round((sum(diffstddev*numpts)/sum(numpts))*100)/100 as meandiffstddev from dbzdiff_stats_by_dist_gpm_ku_s2ku a, overpass_event b where regime='S_above' and numpts>1 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id != 'KING' and b.sat_id='GPM' and percent_of_bins=70 group by 1,2 order by 1,2;

