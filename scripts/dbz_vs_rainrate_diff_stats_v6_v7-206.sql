create table dbzdiff_stats_s2kuAGL (
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
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

\copy dbzdiff_stats_s2kuAGL from '/data/tmp/StatsByDistToDBGeo_s2ku_v7.unl' with delimiter '|' 

create table dbzdiff_stats_defaultAGL (
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
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

\copy dbzdiff_stats_defaultAGL from '/data/tmp/StatsByDistToDBGeo_MELB_v7_pct90.unl' with delimiter '|' 

-- TABLE FOR RAW VS CORRECTED PR REFLECTIVITY (1C21 VS 2A25)
create table dbzdiff_stats_prrawcorAGL (
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
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

\copy dbzdiff_stats_prrawcorAGL from '/data/tmp/StatsByDistToDBbyGeo_PRx2v7.unl' with delimiter '|' 

-- VIEW TO MERGE DATA FROM THE DBZDIFF STATS TABLES

CREATE VIEW dbzdiff_stats_mergedAGL AS select a.*, s.meandiff as meandiffku, s.gvmax as gvmaxku, s.gvmean as gvmeanku, b.meandiff as meandiffcorraw, b.prmax as prmaxcor, b.gvmax as prmaxraw, b.prmean as prmeancor, b.gvmean as prmeanraw, b.numpts as numptscorraw from dbzdiff_stats_defaultAGL a join dbzdiff_stats_s2kuAGL s using (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)  join dbzdiff_stats_prrawcorAGL b using (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height);

-- Z-R RELATIONSHIPS CODED AS POSTGRESQL USER FUNCTIONS

CREATE FUNCTION zrtrop(float) RETURNS float AS ' SELECT ((10.^(0.1*$1))/250.)^(1.0/1.2); ' LANGUAGE SQL;
CREATE FUNCTION zrnex(float) RETURNS float AS ' SELECT ((10.^(0.1*$1))/300.)^(1.0/1.4); ' LANGUAGE SQL;
CREATE FUNCTION zrpr(float) RETURNS float AS ' SELECT ((10.^(0.1*$1))/372.)^(1.0/1.54); ' LANGUAGE SQL;


-- profiles of means and diffs of convective PR and GR Z, and Z converted to rainrate, using original and s2ku GR Zs, Rosenfeld tropical Z-R
select height, round((sum((zrtrop(prmean)-zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rdifcororg, round((sum((zrtrop(prmeanraw)-zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rdifraworg, round((sum((zrtrop(prmean)-zrtrop(gvmeanku))*numpts)/sum(numpts))*100)/100 as rdifcoradj, round((sum((zrtrop(prmeanraw)-zrtrop(gvmeanku))*numpts)/sum(numpts))*100)/100 as rdifrawadj, round((sum((zrtrop(prmean)-zrtrop(prmeanraw))*numpts)/sum(numpts))*100)/100 as rdifcorraw, round((sum((zrtrop(prmean))*numpts)/sum(numpts))*100)/100 as rrcor, round((sum((zrtrop(prmeanraw))*numpts)/sum(numpts))*100)/100 as rrraw, round((sum((zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rrorg,round((sum((zrtrop(gvmeanku))*numpts)/sum(numpts))*100)/100 as rradj, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zdifcororg, round((sum(meandiffku*numpts)/sum(numpts))*100)/100 as zdifcoradj, round((sum((prmeanraw-gvmean)*numpts)/sum(numpts))*100)/100 as zdifraworg, round((sum((prmeanraw-gvmeanku)*numpts)/sum(numpts))*100)/100 as zdifrawadj, round((sum(meandiffcorraw*numpts)/sum(numpts))*100)/100 as zdifcorraw, round((sum(prmean*numpts)/sum(numpts))*100)/100 as zcor, round((sum(prmeanraw*numpts)/sum(numpts))*100)/100 as zraw, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as zorg, round((sum(gvmeanku*numpts)/sum(numpts))*100)/100 as zadj, sum(numpts) as n from dbzdiff_stats_mergedAGL where rangecat<2 and numpts>5 and regime in ('C_above','C_below') and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- profiles of means and diffs of convective PR and GR Z, and Z converted to rainrate, using original and s2ku GR Zs, Kozu et al PR Z-R
select height, percent_of_bins, round((sum((zrpr(prmean)-zrpr(gvmean))*numpts)/sum(numpts))*100)/100 as rdifcororg, round((sum((zrpr(prmeanraw)-zrpr(gvmean))*numpts)/sum(numpts))*100)/100 as rdifraworg, round((sum((zrpr(prmean)-zrpr(gvmeanku))*numpts)/sum(numpts))*100)/100 as rdifcoradj, round((sum((zrpr(prmeanraw)-zrpr(gvmeanku))*numpts)/sum(numpts))*100)/100 as rdifrawadj, round((sum((zrpr(prmean)-zrpr(prmeanraw))*numpts)/sum(numpts))*100)/100 as rdifcorraw, round((sum((zrpr(prmean))*numpts)/sum(numpts))*100)/100 as rrcor, round((sum((zrpr(prmeanraw))*numpts)/sum(numpts))*100)/100 as rrraw, round((sum((zrpr(gvmean))*numpts)/sum(numpts))*100)/100 as rrorg,round((sum((zrpr(gvmeanku))*numpts)/sum(numpts))*100)/100 as rradj, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zdifcororg, round((sum(meandiffku*numpts)/sum(numpts))*100)/100 as zdifcoradj, round((sum((prmeanraw-gvmean)*numpts)/sum(numpts))*100)/100 as zdifraworg, round((sum((prmeanraw-gvmeanku)*numpts)/sum(numpts))*100)/100 as zdifrawadj, round((sum(meandiffcorraw*numpts)/sum(numpts))*100)/100 as zdifcorraw, round((sum(prmean*numpts)/sum(numpts))*100)/100 as zcor, round((sum(prmeanraw*numpts)/sum(numpts))*100)/100 as zraw, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as zorg, round((sum(gvmeanku*numpts)/sum(numpts))*100)/100 as zadj, sum(numpts) as n from dbzdiff_stats_mergedAGL where rangecat<2 and numpts>5 and regime like ('S_%') and percent_of_bins in (6,7) group by 1,2 order by 1,2;

-- MEAN SITE REFLECTIVITY BIASES FOR ORIGINAL AND KU-ADJUSTED GR Zs:
-- "Best" bias regime (stratiform above BB), broken out by site, for unadjusted GR dBZ:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp grzbias_unadj from dbzdiff_stats_defaultAGL where regime='S_above' and numpts>5 and orbit<64708 group by 1 order by 1;
-- "Best" bias regime (stratiform above BB), broken out by site, for adjusted GR dBZ:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp grzbias_adj from dbzdiff_stats_s2kuAGL where regime='S_above' and numpts>5 and orbit<64708 group by 1 order by 1;

-- Merge PR rainrate with GR mean reflectivity, both unadjusted and adjusted

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.prmean as prmeanrr, a.numpts as numrr, b.gvmean as gvzunadj, b.numpts as numzunadj, c.gvmean as gvzadj, c.numpts as numzadj into temp pr_rr_gv_z2 from rrdiff_stats_defaultAGL a JOIN dbzdiff_stats_defaultAGL b USING (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height) JOIN dbzdiff_stats_s2kuAGL c USING (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height) where a.numpts > 4;

-- Merge above with the mean site biases

select a.*, b.meanmeandiff as unadjbias, c.meanmeandiff as adjbias into temp pr_rr_gv_z2_bias2 from pr_rr_gv_z2 a, grzbias_unadj b, grzbias_adj c where a.radar_id = b.radar_id and a.radar_id = c.radar_id;

-- Select with bias-corrected mean dBZs

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.prmeanrr, a.numrr, zrtrop((a.gvzunadj+a.unadjbias)) as gr_rr_unadj, zrtrop((a.gvzadj+a.adjbias)) as gr_rr_adj from pr_rr_gv_z2_bias2 a where orbit=49749;

-- select with mean-bias-corrected GR Zs converted to rainrate, save in perm. table

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.prmeanrr, a.numrr, zrtrop((a.gvzunadj+a.unadjbias)) as gr_rr_unadj, zrtrop((a.gvzadj+a.adjbias)) as gr_rr_adj into rr_pr_grbyzr2waysAGL from pr_rr_gv_z2_bias2 a;

-- select with original GR Zs converted to rainrate, save in perm. table

select a.percent_of_bins, a.rangecat, a.gvtype, a.regime, a.radar_id, a.orbit, a.height, a.prmeanrr, a.numrr, zrtrop((a.gvzunadj)) as gr_rr_unadj, zrtrop((a.gvzadj)) as gr_rr_adj into rr_pr_grbyzr2waysorigAGL from pr_rr_gv_z2_bias2 a;

----------------------- the scores

select radar_id, regime, round((sum(meandiff*numrr)/sum(numrr))*100)/100 as meanmeandiff, sum(numrr) as total from dbzdiff_rrstats_by_dist_geo_bb where numrr>5 and orbit<64708 group by 1,2 order by 1,2;

select 'S_adjusted', regime, round((sum((prmeanrr-gr_rr_adj)*numrr)/sum(numrr))*100)/100 as meanmeandiff, round((sum(prmeanrr*numrr)/sum(numrr))*100)/100 as mean_pr_rr, round((sum(gr_rr_adj*numrr)/sum(numrr))*100)/100 as mean_gr_rr, sum(numrr) as total from rr_pr_grbyzr2waysAGL where numrr>5 and orbit<64708 group by 1,2 order by 2,1;

-- regime-specific mean rr diffs using GV rr with Z bias removed
select regime, round((sum((prmeanrr-gr_rr_adj)*numrr)/sum(numrr))*100)/100 as meandiff_adj, round((sum((prmeanrr-gr_rr_unadj)*numrr)/sum(numrr))*100)/100 as meandiff_unadj, round((sum(prmeanrr*numrr)/sum(numrr))*100)/100 as mean_pr_rr, round((sum(gr_rr_adj*numrr)/sum(numrr))*100)/100 as mean_gr_adj, round((sum(gr_rr_unadj*numrr)/sum(numrr))*100)/100 as mean_gr_unadj, sum(numrr) as total from rr_pr_grbyzr2waysAGL where numrr>5 and orbit<64708 group by 1 order by 1;

-- profiles of convective rainrate biases using original and Ku-adjusted Z for GV Z-R rainrate
select height, round((sum((prmeanrr-gr_rr_adj)*numrr)/sum(numrr))*100)/100 as meandiff_adj, round((sum((prmeanrr-gr_rr_unadj)*numrr)/sum(numrr))*100)/100 as meandiff_unadj, round((sum(prmeanrr*numrr)/sum(numrr))*100)/100 as mean_pr_rr, round((sum(gr_rr_adj*numrr)/sum(numrr))*100)/100 as mean_gr_adj, round((sum(gr_rr_unadj*numrr)/sum(numrr))*100)/100 as mean_gr_unadj, sum(numrr) as total from rr_pr_grbyzr2waysorigAGL where numrr>5 and regime like 'C_%' and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- profiles of convective rainrate biases using using original and Ku-adjusted Z for GV Z-R rainrate with Z bias removed
select height, round((sum((prmeanrr-gr_rr_adj)*numrr)/sum(numrr))*100)/100 as meandiff_adj, round((sum((prmeanrr-gr_rr_unadj)*numrr)/sum(numrr))*100)/100 as meandiff_unadj, round((sum(prmeanrr*numrr)/sum(numrr))*100)/100 as mean_pr_rr, round((sum(gr_rr_adj*numrr)/sum(numrr))*100)/100 as mean_gr_adj, round((sum(gr_rr_unadj*numrr)/sum(numrr))*100)/100 as mean_gr_unadj, sum(numrr) as total from rr_pr_grbyzr2waysAGL where numrr>5 and regime like 'C_%' and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- regime-specific mean rr diffs using GV rr from original Zs
select regime, round((sum((prmeanrr-gr_rr_adj)*numrr)/sum(numrr))*100)/100 as meandiff_adj, round((sum((prmeanrr-gr_rr_unadj)*numrr)/sum(numrr))*100)/100 as meandiff_unadj, round((sum(prmeanrr*numrr)/sum(numrr))*100)/100 as mean_pr_rr, round((sum(gr_rr_adj*numrr)/sum(numrr))*100)/100 as mean_gr_adj, round((sum(gr_rr_unadj*numrr)/sum(numrr))*100)/100 as mean_gr_unadj, sum(numrr) as total from rr_pr_grbyzr2waysorigAGL where numrr>5 and orbit<64708 group by 1 order by 1;

-- SANITY CHECKS ON RAINRATE DIFFERENCES BETWEEN PR 3D RAINRATE AND GR Z-R DERIVED RAINRATE:

-- profiles of means and diffs of convective PR and GR Z, and Z converted to rainrate, using original GR Zs
select height, round((sum((zrtrop(prmean)-zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rrmeandiff, round((sum((zrtrop(prmean))*numpts)/sum(numpts))*100)/100 as pr_rr, round((sum((zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as gv_rr, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr_z, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv_z_orig, sum(numpts) as n from dbzdiff_stats_defaultAGL where rangecat<2 and numpts>5 and regime like 'C_%' and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- profiles of means and diffs of convective PR and GR Z, and Z converted to rainrate, using Ku-adjusted GR Zs
select height, round((sum((zrtrop(prmean)-zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rrmeandiff, round((sum((zrtrop(prmean))*numpts)/sum(numpts))*100)/100 as pr_rr, round((sum((zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as gv_rr, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr_z, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv_z_s2ku, sum(numpts) as n from dbzdiff_stats_s2kuAGL where rangecat<2 and numpts>5 and regime like 'C_%' and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- profiles of means and diffs of convective PR 2A25 and 1C21 Z's, and Z converted to rainrate
select height, round((sum((zrtrop(prmean)-zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rrmeandiff, round((sum((zrtrop(prmean))*numpts)/sum(numpts))*100)/100 as rr_by_zcor, round((sum((zrtrop(gvmean))*numpts)/sum(numpts))*100)/100 as rr_by_zraw, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as zcor_mean, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as zraw_mean, sum(numpts) as n from dbzdiff_stats_prrawcorAGL where rangecat<2 and numpts>5 and regime like 'C_%' and radar_id NOT IN ('KGRK','KWAJ','RGSN','RMOR') and orbit<64708 group by 1 order by 1;

-- SOME OUTPUT SYNTAX.  IF NO OUTPUT FILENAME IS SPECIFIED AGAIN, OUTPUT OF
-- SUBSEQUENT QUERIES WILL APPEND TO THE LAST HTML FILE SPECIFIED
\pset format html
\o /data/tmp/StratRainrateProfiles.html \\select 'PR-GR rainrate (mm/h) and Reflectivity (dBZ), stratiform only. PR from 2A25 profile, GR from Z-R:'; 
