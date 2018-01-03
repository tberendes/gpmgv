select a.event_num, a.radar_id, a.orbit,
       a.overpass_time at time zone 'UTC' as overpass_utc, a.nearest_distance, 
       COALESCE(b.filename, 'no_raw_88D') as file88D,
       d.filename as file1C21, e.filename as file2A23, f.filename as file2A25 
  from km_le_100_w_rain10 a 
  left join rawradar b on a.radar_Id = b.radar_id and (a.overpass_time-b.nominal)
       between '-20 minutes' and '20 minutes' and b.product = 'raw'
    left outer join orbit_subset_product d on (a.orbit=d.orbit)
      and d.product_type = '1C21'
    left outer join orbit_subset_product e on (a.orbit=e.orbit)
      and e.product_type = '2A23'
    left outer join orbit_subset_product f on (a.orbit=f.orbit)
      and f.product_type = '2A25';
