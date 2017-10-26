CREATE VIEW collatecols (orbit, radar_id, overpass_time, nominal) as
select orbit, radar_id, overpass_time, date_trunc('hour', overpass_time)
  from overpass_event;

grant select on collatecols to public;


create view collatedproducts as  
select a.*, b.filename as file2A54, c.filename as file2A55,
       d.filename as file1C21, e.filename as file2A23, 
       f.filename as file2A25 
  from collatecols a 
    left outer join gvradar b on a.nominal=b.nominal
      and a.radar_id=b.radar_id
      and b.product = '2A54'
    left outer join gvradar c on a.nominal=c.nominal
      and a.radar_id=c.radar_id
      and c.product = '2A55'
    left outer join orbit_subset_product d on a.orbit=d.orbit
      and d.product_type = '1C21'
    left outer join orbit_subset_product e on a.orbit=e.orbit
      and e.product_type = '2A23'
    left outer join orbit_subset_product f on a.orbit=f.orbit
      and f.product_type = '2A25';

grant select on collatedproducts to public;

       
create view collatedZproducts as 
select a.*, a.radar_id||'/'||b.filepath||'/'||b.filename as file2A55,
       c.filename as file2A25, d.filename as file1C21
  from collatecols a 
    left outer join gvradar b
      on a.nominal=b.nominal and a.radar_id=b.radar_id
      and b.product = '2A55'
    left outer join orbit_subset_product c
      on a.orbit = c.orbit
      and c.product_type = '2A25'
    left outer join orbit_subset_product d
      on a.orbit = d.orbit
      and d.product_type = '1C21';

grant select on collatedZproducts to public;


CREATE VIEW collatedmosaics as
select a.*, min(b.filename) as first, max(c.filename) as second
  from collatecols a natural join coincident_mosaic b
  left outer join coincident_mosaic c on b.orbit=c.orbit
   and b.filename!=c.filename
  group by a.orbit, overpass_time, nominal, radar_id;

grant select on collatedmosaics to public;
