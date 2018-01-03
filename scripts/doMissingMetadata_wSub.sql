select a.filename, b.filename, b.orbit, count(*), a.subset from orbit_subset_product a, orbit_subset_product b, overpass_event c, siteproductsubset d where a.orbit = b.orbit and a.product_type = '2A23' and b.orbit = c.orbit and b.product_type = '2A25' and a.subset = b.subset and a.subset = d.subset and c.radar_id = d.radar_id and a.orbit not in (53778, 53519, 54067, 55840) and 11 > (select count(*) from event_meta_numeric where event_num=c.event_num) group by a.filename, b.filename, b.orbit, a.subset order by b.orbit;

select a.filename, b.filename, b.orbit, c.radar_id from orbit_subset_product a, orbit_subset_product b, overpass_event c, siteproductsubset d where a.orbit = b.orbit and a.product_type = '2A23' and b.orbit = c.orbit and b.product_type = '2A25' and a.subset = b.subset and a.subset = d.subset and c.radar_id = d.radar_id and a.orbit not in (53778, 53519, 54067, 55840) and 11 > (select count(*) from event_meta_numeric where event_num=c.event_num) order by b.orbit;

select a.event_num, a.radar_id, b.latitude, b.longitude 
          from overpass_event a, fixed_instrument_location b, siteproductsubset d
          where a.radar_id = b.instrument_id and a.radar_id = d.radar_id
	  and a.orbit = ${orbit} and d.subset = ${subset}
          and 11 > (select count(*) from event_meta_numeric where
	  event_num=a.event_num);

select overpass_time at time zone 'UTC' from overpass_event where orbit in(52573,52673,52680,52863,52887,52902,52948,52963,52970,52985,53070,53397,56245,57656,57756,57839,57878) and radar_id='DARW';