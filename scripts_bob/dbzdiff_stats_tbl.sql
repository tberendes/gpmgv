create table dbzdiff_stats (
   gvtype char(4),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   prmax float,
   gvmax float,
   numpts int,
   primary key (gvtype, radar_id, orbit, height)
);

\copy dbzdiff_stats from '/data/tmp/StatsToDB.unl' with delimiter '|' 

select sum(meandiff*numpts) as w, sum(numpts) as n, gvtype, height
 into temp dbzsums from dbzdiff_stats where meandiff > -99.9
 group by 3,4 order by 3,4; 
select w/n as bias, gvtype, height from dbzsums; 

select sum(meandiff*numpts) as w, sum(numpts) as n, gvtype, radar_id, height
 into temp sitedbzsums from dbzdiff_stats where meandiff > -99.9
 group by 3,4,5 order by 3,4,5;
 
select a.radar_id, a.height, round(100*(a.w/a.n))/100 as bias_vs_2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.height = b.height;
