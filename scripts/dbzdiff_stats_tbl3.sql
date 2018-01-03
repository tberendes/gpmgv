-- Table into which to load the output of stratified_stats_to_dbfile.pro

create table dbzdiff_stats (
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
   primary key (gvtype, regime, radar_id, orbit, height)
);

delete from dbzdiff_stats;
\copy dbzdiff_stats from '/data/tmp/StatsToDB.unl' with delimiter '|' 

-- "Best" bias regime (stratiform above BB), broken out by site and GV type:
select gvtype, radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff from dbzdiff_stats where regime='S_above' and numpts>5 group by 1,2 order by 2,1;

-- Non-site/regime-specific summary stats, broken out by GV type and height only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height
 into temp dbzsums from dbzdiff_stats where meandiff > -99.9
 group by 4,5 order by 4,5; 
select w/n as bias, gvtype, height from dbzsums; 

-- Full breakout: site, regime, raintype, height
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(prmean*numpts) as p, sum(gvmean*numpts) as g,
       max(prmax) as px, max(gvmax) as gx,
       sum(numpts) as n, gvtype, regime, radar_id, height
  into temp sitedbzsums from dbzdiff_stats
 where meandiff > -99.9 and diffstddev > -99.9
 group by 8,9,10,11 order by 8,9,10,11;

select a.radar_id, a.regime, a.height, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(a.s/a.n))/100 as stddev2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, round(100*(b.s/b.n))/100 as stddevREORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height order by 1,2,3;
