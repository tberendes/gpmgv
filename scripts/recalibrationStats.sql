select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffpre, sum(numpts) as totalpre into temp pre from dbzdiff_stats_by_dist_geo_bb where regime='S_above' and numpts>5 and orbit < 65701 group by 1 order by 1;
 
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffpost, sum(numpts) as totalpost into temp post from dbzdiff_stats_by_dist_geo_bb where regime='S_above' and numpts>5 and orbit > 65701 group by 1 order by 1;

select pre.radar_id, pre.meandiffpre, pre.total as totalpre, post.meandiffpost, post.total as totalpost from pre full outer join post using (radar_id) where radar_id <'KWAJ';

select regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffpre, sum(numpts) as totalpre from dbzdiff_stats_by_dist_geo_bb where numpts>5 and radar_id<'KWAJ' and radar_id!='KGRK' and orbit < 65701 group by 1 order by 1;

 regime  | meandiffpre | totalpre 
---------+-------------+----------
 C_above |       -0.64 |    56638
 C_below |       -0.63 |    97105
 C_in    |       -0.83 |   101329
 S_above |       -0.81 |   137310
 S_below |        -0.3 |   331071
 S_in    |       -1.67 |   501943
 Total   |       -1.01 |  1255266
(7 rows)

select regime, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffpost, sum(numpts) as totalpost from dbzdiff_stats_by_dist_geo_bb where numpts>5 and radar_id<'KWAJ' and radar_id!='KGRK' and orbit > 65701 group by 1 order by 1;

 regime  | meandiffpost | totalpost 
---------+--------------+-----------
 C_above |        -0.49 |     10234
 C_below |        -1.38 |     29580
 C_in    |        -0.78 |     20440
 S_above |        -0.58 |     26753
 S_below |        -0.59 |    107571
 S_in    |        -1.66 |    118729
 Total   |        -1.09 |    320199
(7 rows)
 regime  | meandiffpre | totalpre | meandiffpost | totalpost 
---------+-------------+----------+--------------+-----------
 C_above |       -0.64 |    56638 |        -0.49 |     10234
 C_below |       -0.63 |    97105 |        -1.38 |     29580
 C_in    |       -0.83 |   101329 |        -0.78 |     20440
 S_above |       -0.81 |   137310 |        -0.58 |     26753
 S_below |        -0.3 |   331071 |        -0.59 |    107571
 S_in    |       -1.67 |   501943 |        -1.66 |    118729
 Total   |       -1.01 |  1255266 |        -1.09 |    320199
