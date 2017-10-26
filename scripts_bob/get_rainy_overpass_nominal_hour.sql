-- changed sort order to orbit then site, and added NPOL_WA to the exclusion list. 6/10/16
-- added Brazil radars "XX1" and radars from A to J to the exclude list
-- 2/21/17 - Excluded KWAJ from the first SELECT that rounds to the hour, and added a
--           second SELECT for KWAJ-only that rounds to the day (to 00:00:00 UTC).
--           NOW IT IS NECESSARY TO EDIT THE STARTING ORBIT NUMBER IN TWO PLACES.

\t \a \o /data/tmp/rain_event_nominalAPP.txt \\select o.radar_id, o.orbit, date_trunc('hour', o.overpass_time at time zone 'UTC' + interval '30 minutes') from overpass_event o, rainy100inside100 r where o.sat_id='GPM' and o.event_num=r.event_num and o.radar_id > 'KAAA' and o.radar_id < 'QQQQ' and o.radar_id not in ('CHILL','NPOL','NPOL_MD','NPOL_WA','KWAJ') and o.radar_id not like '%1' and o.orbit > 15837 
UNION
select o.radar_id, o.orbit, date_trunc('day', o.overpass_time at time zone 'UTC' + interval '12 hours') from overpass_event o, rainy100inside100 r where o.sat_id='GPM' and o.event_num=r.event_num and o.radar_id = 'KWAJ' and o.orbit > 15837 order by 2, 1;
