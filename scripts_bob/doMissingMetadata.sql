select * from overpass_event where event_num not in (select event_num from event_meta_numeric where metadata_id = 250999);

select distinct orbit from overpass_event where event_num not in (select event_num from event_meta_numeric where metadata_id = 250999);


     select a.filename, b.filename, b.orbit, count(*)
     from orbit_subset_product a, orbit_subset_product b, overpass_event c
     where a.orbit = b.orbit and a.product_type = '2A23'
       and b.orbit = c.orbit and b.product_type = '2A25'
       and a.orbit in (select distinct orbit from overpass_event 
       where event_num not in (select distinct event_num from event_meta_numeric)) 
       group by a.filename, b.filename, b.orbit 
     order by b.orbit;
     
   select a.event_num, a.radar_id, b.latitude, b.longitude 
          from overpass_event a, fixed_instrument_location b 
          where a.radar_id = b.instrument_id and 
          a.orbit = 52541 and 1 > (select count(*)
	  from event_meta_numeric where event_num=a.event_num);  

     select a.filename, b.filename, b.orbit, count(*)
     from orbit_subset_product a, orbit_subset_product b, overpass_event c
     where a.orbit = b.orbit and a.product_type = '2A23'
       and b.orbit = c.orbit and b.product_type = '2A25'
       and 0 = (select count(*) from event_meta_numeric
       where event_num=c.event_num) group by a.filename, b.filename, b.orbit 
     order by b.orbit;
