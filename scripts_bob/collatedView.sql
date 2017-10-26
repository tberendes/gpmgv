CREATE  VIEW collatecols (orbit, radar_id, nominal) as
select orbit, radar_id, date_trunc('hour', overpass_time)
  from overpass_event;

grant select on collatecols to public;

 select a.orbit, a.radar_id, a.nominal, b.nominal, b.filename
   from collatecols a natural join gvradar b limit 10;
   
select a.orbit, a.radar_id, a.overpass_time, b.nominal, b.filename, c.filename from overpass_event a, gvradar b, orbit_subset_product c where date_trunc('hour', a.overpass_time)=b.nominal and a.radar_id=b.radar_id and a.orbit = c.orbit limit 10;

select a.*, b.filename, c.filename from collatecols a left outer join gvradar b on a.nominal = b.nominal and a.radar_id = b.radar_id full outer join gvradar c on a.nominal = c.nominal and a.radar_id = c.radar_id where b.product='2A54' and c.product='2A55';

create view collatedproducts as 
select a.*, b.filename as file2A54, c.filename as file2A55, d.filename as file1C21,
       e.filename as file2A23, f.filename as file2A25 
  from collatecols a left outer join gvradar b using (nominal,radar_id)
                     left outer join gvradar c using (nominal,radar_id) 
		     left outer join orbit_subset_product d using (orbit) 
		     left outer join orbit_subset_product e using (orbit) 
		     left outer join orbit_subset_product f using (orbit) 
 where b.product = '2A54' and c.product = '2A55' and d.product_type = '1C21'
       and e.product_type = '2A23' and f.product_type = '2A25';

grant select on collatedproducts to public;
       
create view collatedZproducts as 
select a.*, b.filename as file2A55, c.filename as file2A25 
  from collatecols a left outer join gvradar b using (nominal,radar_id)
                     left outer join orbit_subset_product c using (orbit) 
 where b.product = '2A55' and c.product_type = '2A25';

grant select on collatedZproducts to public;



CREATE VIEW collatedmosaics as
select a.*, min(b.filename) as first, max(c.filename) as second
  from collatecols a natural join coincident_mosaic b
  left outer join coincident_mosaic c on b.orbit=c.orbit
   and b.filename!=c.filename
  group by a.orbit, nominal, radar_id;

grant select on collatedmosaics to public;

================================

select a.*, b.filename as file2A55, c.filename as file2A25 
  from collatecols a left outer join gvradar b on
   a.nominal = b.nominal and a.radar_id = b.radar_id
    and b.product = '2A55'
   left outer join orbit_subset_product c on
   a.orbit = c.orbit
 and c.product_type = '2A25'
 order by orbit desc
 limit 20;
 
 
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
      and f.product_type = '2A25'
order by orbit desc limit 20;
