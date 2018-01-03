\pset format html

\o ovlp25wrain25.html \\select a.radar_id, a.orbit, a.overpass_time at time zone 'UTC' as overpass_time_UTC, round(a.pct_overlap*100)/100 as pct_overlap, round(a.pct_overlap_conv*100)/100 as pct_conv, round(a.pct_overlap_strat*100)/100 as pct_strat,round(a.pct_overlap_rain_certain*100)/100 as pct_rain_certain from ovlp25_w_rain25 a, collatedZproducts b where a.radar_id = b.radar_id and a.orbit=b.orbit and b.file2a55 is not null order by a.overpass_time;
