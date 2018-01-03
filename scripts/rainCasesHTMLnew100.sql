\pset format html

\o ARMOR_100rainPtsIn100km.html \\select radar_id, orbit, overpass_time at time zone 'UTC' as overpass_time_UTC, round(pct_overlap*100)/100 as pct_overlap, round(pct_overlap_conv*100)/100 as pct_conv, round(pct_overlap_strat*100)/100 as pct_strat, num_overlap_rain_certain as points_rain_certain from rainy100inside100 where not exists (select * from ovlp25_w_rain25 where radar_id = rainy100inside100.radar_id and orbit = rainy100inside100.orbit)  and radar_id = 'RMOR'order by overpass_time;
