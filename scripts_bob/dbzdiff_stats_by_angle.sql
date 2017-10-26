-- Table into which to load the output of stratified_by_angle_stats_to_dbfile.pro

create table dbzdiff_stats_by_angle (
   anglecat int,
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
   primary key (anglecat, gvtype, regime, radar_id, orbit, height)
);
create table pr_angle_cat_text (
   anglecat int,
   angletext character varying(10),
   primary key (anglecat)
);
insert into pr_angle_cat_text values (0, 'Near Nadir');
insert into pr_angle_cat_text values (1, 'Mid Angles');
insert into pr_angle_cat_text values (2, 'Far Angles');

delete from dbzdiff_stats_by_angle;
\copy dbzdiff_stats_by_angle from '/data/tmp/StatsByAngleToDB.unl' with delimiter '|' 

-- "Best" bias regime (stratiform above BB), broken out by site and angle, for 2A55:
select radar_id, angletext, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_angle, pr_angle_cat_text where dbzdiff_stats_by_angle.anglecat = pr_angle_cat_text.anglecat and regime='S_above' and numpts>5 and gvtype='2A55' group by 1,2 order by 1,2;
-- As above, but output to HTML table
\o /data/tmp/BiasByRayAngle_StratAboveBB.html \\select radar_id, angletext as ray_set, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total,
regime from dbzdiff_stats_by_angle, pr_angle_cat_text where dbzdiff_stats_by_angle.anglecat = pr_angle_cat_text.anglecat and regime='S_above' and numpts>5 and gvtype='2A55' group by 1,2,5 order by 1 asc, 2 desc;
-- As above, but for below BB
\o /data/tmp/BiasByRayAngle_StratBelowBB.html \\select radar_id, angletext as ray_set, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total,
regime from dbzdiff_stats_by_angle, pr_angle_cat_text where dbzdiff_stats_by_angle.anglecat = pr_angle_cat_text.anglecat and regime='S_below' and numpts>5 and gvtype='2A55' group by 1,2,5 order by 1 asc, 2 desc;

-- "Best" bias regime (stratiform above BB), broken out by site, GV type and angle:
select gvtype, radar_id, anglecat, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_angle where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- Non-site/regime-specific summary stats, broken out by GV type, height and angle only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height, anglecat
 into temp dbzsums from dbzdiff_stats_by_angle where meandiff > -99.9
 group by 4,5,6 order by 4,5,6; 
select round(100.*w/n)/100. as bias, gvtype, height, anglecat from dbzsums; 

-- Full breakout: site, regime, raintype, height and angle
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(prmean*numpts) as p, sum(gvmean*numpts) as g,
       max(prmax) as px, max(gvmax) as gx,
       sum(numpts) as n, gvtype, regime, radar_id, height, anglecat
  into temp sitedbzsums from dbzdiff_stats_by_angle
 where meandiff > -99.9 and diffstddev > -99.9
 group by 8,9,10,11,12 order by 8,9,10,11,12;

select a.radar_id, a.regime, a.height, a.anglecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(a.s/a.n))/100 as stddev2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, round(100*(b.s/b.n))/100 as stddevREORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.anglecat = b.anglecat order by 1,2,4,3;
