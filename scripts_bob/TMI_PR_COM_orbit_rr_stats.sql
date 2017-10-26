-- Tables into which to load the output of orbit_tmi_pr_com_rr_stats4db.pro

-- table to hold output with either/both samples above threshold at a point,
-- by source pairing (i.e., numpts may differ for each 'sources' pair,
-- for a given regime, version, orbit), for the nearest-neighbor matchups

create table rrdiff_by_sources_rntype_sfc_Loose_nn (
   sources char(4),
   region character varying(10),
   regime character varying(10),
   version integer,
   orbit integer,
   meandiff float,
   diffstddev float,
   src1max float,
   src2max float,
   src1mean float,
   src2mean float,
   numpts int,
   primary key (sources, region, regime, version, orbit)
);

delete from rrdiff_by_sources_rntype_sfc_Loose_nn;

\copy rrdiff_by_sources_rntype_sfc_Loose_nn from '/data/gpmgv/tmp/TMI_PR_COM_Orbit_StatsToDB_v6_Ja-Jn2010_Loose.unl' with delimiter '|'

\copy rrdiff_by_sources_rntype_sfc_Loose_nn from '/data/gpmgv/tmp/TMI_PR_COM_Orbit_StatsToDB_v7_Ja-Jn2010_Loose.unl' with delimiter '|'


-- table to hold output with PR, TMI, and COM samples above threshold at each point,
-- by source pairing (i.e., numpts may differ for each 'sources' pair,
-- for a given regime, version, orbit), for the nearest-neighbor matchups

create table rrdiff_by_sources_rntype_sfc_paired_nn (
   sources char(4),
   region character varying(10),
   regime character varying(10),
   version integer,
   orbit integer,
   meandiff float,
   diffstddev float,
   src1max float,
   src2max float,
   src1mean float,
   src2mean float,
   numpts int,
   primary key (sources, region, regime, version, orbit)
);

delete from rrdiff_by_sources_rntype_sfc_paired_nn;

\copy rrdiff_by_sources_rntype_sfc_paired_nn from '/data/gpmgv/tmp/TMI_PR_COM_Orbit_StatsToDB_v6_Ja-Jn2010_Paired.unl' with delimiter '|'

\copy rrdiff_by_sources_rntype_sfc_paired_nn from '/data/gpmgv/tmp/TMI_PR_COM_Orbit_StatsToDB_v7_Ja-Jn2010_Paired.unl' with delimiter '|'

-- table to hold output with PR, TMI, and COM samples all above threshold at each point,
-- in common for all three sources (numpts is the same for each 'sources' pair,
-- for a given regime, version, orbit), for the nearest-neighbor matchups

create table rrdiff_by_sources_rntype_sfc_strict_nn (
   sources char(4),
   region character varying(10),
   regime character varying(10),
   version integer,
   orbit integer,
   meandiff float,
   diffstddev float,
   src1max float,
   src2max float,
   src1mean float,
   src2mean float,
   numpts int,
   primary key (sources, regime, version, orbit)
);

delete from rrdiff_by_sources_rntype_sfc_strict_nn;

\copy rrdiff_by_sources_rntype_sfc_strict_nn from '/data/gpmgv/tmp/TMI_PR_COM_Orbit_StatsToDBNN_Strict.unl' with delimiter '|'

\o /tmp/Query1out.txt(sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_by_sources_rntype_sfc_paired_nn group by 1,2,3,4 order by 1,3,4,2;


\o /tmp/Query2out.txt \\select region, 'V'||version as version, substring(sources from 1 for 2)||'-'||substring(sources from 3 for 2) as sources, substring(regime from 1 for 2) as regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_by_sources_rntype_sfc_Loose_nn group by 1,2,3,4 order by 1,3,4,2;


\o /tmp/Query3out.txt \\select region, 'V'||version as version, substring(sources from 1 for 2)||'-'||substring(sources from 3 for 2) as sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_by_sources_rntype_sfc_paired_nn group by 1,2,3,4 order by 1,3,4,2;


\o /tmp/Query4out.txt \\select 'V'||version||' NN' as version, substring(sources from 1 for 2)||'-'||substring(sources from 3 for 2) as sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_by_sources_rntype_sfc_paired_nn where region in ('N_Hem','S_Hem') group by 1,2,3 order by 2,3,1;




\o /tmp/Query5out.txt \\select substring(a.sources from 1 for 2)||'-'||substring(a.sources from 3 for 2) as sources, a.regime, 
round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as rr_diff6, 
round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as rr_diff7,
round((sum(a.src1mean*a.numpts)/sum(a.src2mean*a.numpts))*100)/100 as bias6, 
round((sum(b.src1mean*b.numpts)/sum(b.src2mean*b.numpts))*100)/100 as bias7,
round((sum(a.src1mean*a.numpts)/sum(a.numpts))*100)/100 as rra6, 
round((sum(b.src1mean*b.numpts)/sum(b.numpts))*100)/100 as rra7,
round((sum(a.src2mean*a.numpts)/sum(a.numpts))*100)/100 as rrb6, 
round((sum(b.src2mean*b.numpts)/sum(b.numpts))*100)/100 as rrb7,
sum(a.numpts) as total6, sum(b.numpts) as total7
from rrdiff_by_sources_rntype_sfc_paired_nn a, rrdiff_by_sources_rntype_sfc_paired_nn b where a.region=b.region and a.region in ('N_Hem','S_Hem') and a.orbit=b.orbit and a.regime=b.regime and a.sources=b.sources and a.version=6 and b.version=7 group by 1,2 order by 1,2;




\o /tmp/Query6out.txt \\select substring(a.sources from 1 for 2)||'-'||substring(a.sources from 3 for 2) as sources, a.regime, 
round((sum(a.src1mean*a.numpts)-sum(a.src2mean*a.numpts))*100)/100 as voldiff6, 
round((sum(b.src1mean*b.numpts)-sum(b.src2mean*b.numpts))*100)/100 as voldiff7,
round((sum(a.src1mean*a.numpts)/sum(a.src2mean*a.numpts))*100)/100 as volbias6, 
round((sum(b.src1mean*b.numpts)/sum(b.src2mean*b.numpts))*100)/100 as volbias7,
sum(a.numpts) as total6, sum(b.numpts) as total7
from rrdiff_by_sources_rntype_sfc_paired_nn a, rrdiff_by_sources_rntype_sfc_paired_nn b where a.region=b.region and a.region in ('N_Hem','S_Hem') and a.orbit=b.orbit and a.regime=b.regime and a.sources=b.sources and a.version=6 and b.version=7 and a.regime not like '_\\_%' group by 1,2 order by 1,2;



\o /tmp/Query7out.txt \\select substring(a.sources from 1 for 2)||'-'||substring(a.sources from 3 for 2) as sources, substring(a.regime from 3 for 4), 
round((sum(a.src1mean*a.numpts)-sum(a.src2mean*a.numpts))*100)/100 as voldiff6, 
round((sum(b.src1mean*b.numpts)-sum(b.src2mean*b.numpts))*100)/100 as voldiff7,
round((sum(a.src1mean*a.numpts)/sum(a.src2mean*a.numpts))*100)/100 as volbias6, 
round((sum(b.src1mean*b.numpts)/sum(b.src2mean*b.numpts))*100)/100 as volbias7,
sum(a.numpts) as total6, sum(b.numpts) as total7
from rrdiff_by_sources_rntype_sfc_paired_nn a, rrdiff_by_sources_rntype_sfc_paired_nn b where a.region=b.region and a.region in ('N_Hem','S_Hem') and a.orbit=b.orbit and a.regime=b.regime and a.sources=b.sources and a.version=6 and b.version=7 and a.regime like '_\\_%' group by 1,2 order by 1,2;





select radar_id, 'V7 '||substring(sources from 1 for 2)||'-'||substring(sources from 3 for 2) as sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_stats_by_dist_time_tmi_pr_v7 group by 1,2,3 order by 1,2,3;


gpmgv=# select radar_id, sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff,round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total into temp v6diffs  from rrdiff_by_sources_rntype_sfc_paired_nn group by 1,2,3 order by 1,2,3;
SELECT
gpmgv=# select radar_id, sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff,round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total into temp v7diffs from rrdiff_stats_by_dist_time_tmi_pr_v7 group by 1,2,3 order by 1,2,3;
SELECT

gpmgv=# select a.radar_id, 'v6 '||a.regime as subset,a.rr_diff as pr_gr_diff, b.rr_diff as tmi_gr_diff, c.rr_diff as tmi_pr_diff, a.total from v6diffs a, v6diffs b, v6diffs c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime=b.regime and a.regime=c.regime and a.sources='PRGR' and b.sources='TMGR' and c.sources='TMPR';


select a.radar_id, 'v7 '||a.regime as subset,a.rr_diff as pr_gr_diff, b.rr_diff as tmi_gr_diff, c.rr_diff as tmi_pr_diff, a.total from v7diffs a, v7diffs b, v7diffs c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime=b.regime and a.regime=c.regime and a.sources='PRGR' and b.sources='TMGR' and c.sources='TMPR';


select radar_id, 'V6 '||substring(sources from 1 for 2)||'-'||substring(sources from 3 for 2) as sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as prgr_bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total from rrdiff_by_sources_rntype_sfc_paired_nn group by 1,2,3 order by 1,2,3;

select radar_id, sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total into temp v6diffs from rrdiff_by_sources_rntype_sfc_paired_nn group by 1,2,3 order by 1,2,3;

select radar_id, sources, regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as rr_diff, round((sum(src1mean*numpts)/sum(src2mean*numpts))*100)/100 as bias, round((sum(src1mean*numpts)/sum(numpts))*100)/100 as rr1, round((sum(src2mean*numpts)/sum(numpts))*100)/100 as rr2, sum(numpts) as total into temp v7diffs from rrdiff_stats_by_dist_time_tmi_pr_v7 group by 1,2,3 order by 1,2,3;

select a.radar_id, 'v6 '||a.regime as subset,a.rr_diff as pr_gr_diff, a.bias as pr_gr_bias, b.rr_diff as tmi_gr_diff, b.bias as tmi_gr_bias, c.rr_diff as tmi_pr_diff, c.bias as tmi_pr_bias, a.total from v6diffs a, v6diffs b, v6diffs c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime=b.regime and a.regime=c.regime and a.sources='PRGR' and b.sources='TMGR' and c.sources='TMPR';

 radar_id |   subset   | pr_gr_diff | pr_gr_bias | tmi_gr_diff | tmi_gr_bias | tmi_pr_diff | tmi_pr_bias | total
----------+------------+------------+------------+-------------+-------------+-------------+-------------+-------
 KMLB     | v6 C_coast |       4.68 |        1.6 |        2.61 |        1.34 |       -2.07 |        0.83 |   231
 KMLB     | v6 C_land  |       4.66 |       1.68 |        8.85 |        2.29 |         4.2 |        1.36 |   219
 KMLB     | v6 C_ocean |       3.58 |       1.37 |        1.65 |        1.17 |       -1.93 |        0.86 |   118
 KMLB     | v6 S_coast |       1.08 |       1.53 |        2.05 |        2.01 |        0.97 |        1.31 |  1027
 KMLB     | v6 S_land  |        0.8 |       1.37 |        0.98 |        1.46 |        0.18 |        1.06 |   555
 KMLB     | v6 S_ocean |       1.21 |       1.49 |        1.44 |        1.59 |        0.23 |        1.06 |   521
 KMLB     | v6 Total   |       2.01 |       1.58 |        2.61 |        1.76 |         0.6 |        1.11 |  3169
 KWAJ     | v6 C_ocean |       4.69 |       1.82 |         2.6 |        1.46 |        -2.1 |         0.8 |   110
 KWAJ     | v6 S_ocean |       0.53 |       1.22 |         2.2 |        1.89 |        1.67 |        1.56 |  1017
 KWAJ     | v6 Total   |        1.3 |       1.42 |        2.42 |        1.78 |        1.12 |        1.25 |  1361
(10 rows)

select a.radar_id, 'v7 '||a.regime as subset,a.rr_diff as pr_gr_diff, a.bias as pr_gr_bias, b.rr_diff as tmi_gr_diff, b.bias as tmi_gr_bias, c.rr_diff as tmi_pr_diff, c.bias as tmi_pr_bias, a.total from v7diffs a, v7diffs b, v7diffs c where a.radar_id=b.radar_id and a.radar_id=c.radar_id and a.regime=b.regime and a.regime=c.regime and a.sources='PRGR' and b.sources='TMGR' and c.sources='TMPR';


 radar_id |   subset   | pr_gr_diff | pr_gr_bias | tmi_gr_diff | tmi_gr_bias | tmi_pr_diff | tmi_pr_bias | total
----------+------------+------------+------------+-------------+-------------+-------------+-------------+-------
 KMLB     | v7 C_coast |       6.91 |       1.85 |        3.65 |        1.45 |       -3.25 |        0.78 |   283
 KMLB     | v7 C_land  |       7.71 |       2.33 |        6.78 |        2.17 |       -0.93 |        0.93 |   155
 KMLB     | v7 C_ocean |       4.85 |       1.56 |       -3.96 |        0.54 |       -8.81 |        0.34 |    43
 KMLB     | v7 S_coast |       1.28 |       1.59 |        2.23 |        2.03 |        0.95 |        1.28 |  1076
 KMLB     | v7 S_land  |       0.86 |       1.38 |       -0.01 |        0.99 |       -0.87 |        0.72 |   540
 KMLB     | v7 S_ocean |       1.36 |       1.57 |        0.81 |        1.34 |       -0.55 |        0.85 |   150
 KMLB     | v7 Total   |       2.68 |       1.79 |        2.18 |        1.64 |        -0.5 |        0.92 |  2658
 KWAJ     | v7 C_ocean |       5.61 |       1.89 |       -1.37 |        0.78 |       -6.98 |        0.41 |    95
 KWAJ     | v7 S_ocean |       0.86 |       1.32 |        1.71 |        1.63 |        0.85 |        1.24 |   688
 KWAJ     | v7 Total   |       1.89 |       1.56 |        1.24 |        1.37 |       -0.65 |        0.88 |   949
(10 rows)


