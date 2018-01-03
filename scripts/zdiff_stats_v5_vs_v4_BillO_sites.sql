select radar_id, round((sum(meandiffv5*numptsv5)/sum(numptsv5))*100)/100*(-1) as meandiff_v5, sum(numptsv5) as total_v5, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs_s2ku a, fixed_instrument_location f where regime='S_above' and numptsv5>5 and numptsv4>5 and percent_of_bins=70 and a.radar_id=f.instrument_id and a.radar_id in ('KDDC','KDOX','KEAX','KHGX','KWAJ','PAIH') AND ORBIT > 2885 group by radar_id, latitude,longitude order by radar_id;

100% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KDDC     |       -1.85 |      440 |        0.05 |      483 |  37.7608 |  -99.9689
 KDOX     |       -1.86 |      881 |       -0.05 |      965 |  38.8256 |  -75.4397
 KEAX     |        -1.9 |      201 |       -0.04 |      237 |  38.8103 |  -94.2644
 KHGX     |       -2.33 |      137 |       -0.28 |      115 |  29.4719 |  -95.0792
 KWAJ     |       -2.22 |      411 |       -0.49 |      509 |  8.71796 |   167.733
 PAIH     |       -0.04 |      602 |        1.74 |      575 |  59.4614 |  -146.303
(6 rows)

70% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KDDC     |       -1.77 |     2872 |        0.07 |     2952 |  37.7608 |  -99.9689
 KDOX     |        -1.9 |     3827 |       -0.14 |     3846 |  38.8256 |  -75.4397
 KEAX     |       -1.93 |     2365 |       -0.25 |     2392 |  38.8103 |  -94.2644
 KHGX     |        -1.8 |     3634 |       -0.05 |     3659 |  29.4719 |  -95.0792
 KWAJ     |       -1.93 |     4026 |       -0.25 |     4602 |  8.71796 |   167.733
 PAIH     |       -0.87 |     6716 |        0.83 |     6240 |  59.4614 |  -146.303


select radar_id, round((sum(meandiffv5*numptsv5)/sum(numptsv5))*100)/100*(-1) as meandiff_v5, sum(numptsv5) as total_v5, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs_s2ku a, fixed_instrument_location f where regime='S_above' and numptsv5>5 and numptsv4>5 and percent_of_bins=70 and a.radar_id=f.instrument_id and a.radar_id in ('KFWS') AND ORBIT > 2885 and orbit < 7598 group by radar_id, latitude,longitude order by radar_id;

100% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KFWS     |        -1.5 |       41 |       -0.07 |       48 |  32.5731 |  -97.3031
(1 row)

70% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KFWS     |       -1.81 |      881 |       -0.08 |      893 |  32.5731 |  -97.3031
(1 row)


select radar_id, round((sum(meandiffv5*numptsv5)/sum(numptsv5))*100)/100*(-1) as meandiff_v5, sum(numptsv5) as total_v5, round((sum(meandiffv4*numptsv4)/sum(numptsv4))*100)/100*(-1) as meandiff_v4, sum(numptsv4) as total_v4, f.latitude, f.longitude from merged_diffs_s2ku a, fixed_instrument_location f where regime='S_above' and numptsv5>5 and numptsv4>5 and percent_of_bins=100 and a.radar_id=f.instrument_id and a.radar_id in ('KGRK') AND ORBIT > 7598 group by radar_id, latitude,longitude order by radar_id;

100% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KGRK     |       -3.47 |       31 |       -1.72 |       28 |  30.7219 |  -97.3831
(1 row)

70% results:

 radar_id | meandiff_v5 | total_v5 | meandiff_v4 | total_v4 | latitude | longitude 
----------+-------------+----------+-------------+----------+----------+-----------
 KGRK     |       -2.35 |      895 |       -0.56 |      855 |  30.7219 |  -97.3831
(1 row)

