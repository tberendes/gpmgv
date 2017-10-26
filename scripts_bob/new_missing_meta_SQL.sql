select a.filename, b.filename, b.orbit, count(*), a.subset, a.version
     from orbit_subset_product a, orbit_subset_product b,
          overpass_event c, siteproductsubset d
     where a.orbit = b.orbit and a.product_type = '2A23'
       and b.orbit = c.orbit and b.product_type = '2A25'
and a.version=b.version and a.version=7
       and a.subset = b.subset and a.subset = d.subset and d.sat_id='PR' 
       and c.radar_id = d.radar_id  and a.subset='KWAJ' and c.radar_id='KWAJ' 
       and 18 > (select count(*) from event_meta_numeric 
       where event_num=c.event_num) 
       group by a.filename, b.filename, b.orbit, a.subset , a.version
     order by b.orbit limit 10;

select b.orbit, count(distinct(event_num)), a.subset, min(a.version) as version
     into temp metaorbitstemp
     from orbit_subset_product a, orbit_subset_product b,
          overpass_event c, siteproductsubset d
     where a.orbit = b.orbit and a.product_type = '2A23'
       and b.orbit = c.orbit and b.product_type = '2A25'
and a.version=b.version
       and a.subset = b.subset and a.subset = d.subset
       and c.radar_id = d.radar_id  and a.orbit > 64643 and d.sat_id='PR'
       and 18 > (select count(*) from event_meta_numeric 
       where event_num=c.event_num) 
       group by b.orbit, a.subset
     order by b.orbit limit 20;

select a.filename, b.filename, c.* from orbit_subset_product a, orbit_subset_product b, metaorbitstemp c where a.orbit = b.orbit and a.product_type = '2A23' and b.orbit = c.orbit and b.product_type = '2A25' and a.version=b.version and b.version=c.version and a.subset = b.subset and a.subset = c.subset order by c.orbit;
