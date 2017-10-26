\o AU_2_64_66_72_GPM_rain_events.txt \\select radar_id, orbit, date_trunc('second', overpass_time) at time zone 'UTC' as overpass_time_UTC, round(pct_overlap*100)/100 as pct_overlap, round(pct_overlap_conv*100)/100 as pct_conv, round(pct_overlap_strat*100)/100 as pct_strat, round( (num_overlap_rain_certain/56.25)*100)/100 as pct_rain_certain from rainy100inside100 where radar_id like 'AU-%' order by 1,2;
