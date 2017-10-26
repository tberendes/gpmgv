CREATE VIEW collatecolswsub (orbit, radar_id, overpass_time, nominal, subset) as
select a.orbit, a.radar_id, a.overpass_time, date_trunc('hour', a.overpass_time), b.subset
  from overpass_event a, siteproductsubset b
 where a.radar_id = b.radar_id and a.sat_id = b.sat_id;

grant select on collatecolswsub to public;


create view collatedproductswsub as  
select a.*, b.filename as file2A54, c.filename as file2A55,
       d.filename as file1C21, e.filename as file2A23, 
       f.filename as file2A25 
  from collatecolswsub a 
    left outer join gvradar b on (a.nominal=b.nominal
      and a.radar_id=b.radar_id)
      and b.product = '2A54'
    left outer join gvradar c on (a.nominal=c.nominal
      and a.radar_id=c.radar_id)
      and c.product = '2A55'
    left outer join orbit_subset_product d on (a.orbit=d.orbit
      and a.subset = d.subset)
      and d.product_type = '1C21'
    left outer join orbit_subset_product e on (a.orbit=e.orbit
      and a.subset = e.subset)
      and e.product_type = '2A23'
    left outer join orbit_subset_product f on (a.orbit=f.orbit
      and a.subset = f.subset)
      and f.product_type = '2A25';

grant select on collatedproductswsub to public;

       
create view collatedZproductswsub as 
select a.*, a.radar_id||'/'||b.filepath||'/'||b.filename as file2A55,
       c.filename as file2A25, d.filename as file1C21
  from collatecolswsub a 
    left outer join gvradar b
      on a.nominal=b.nominal and a.radar_id=b.radar_id
      and b.product = '2A55'
    left outer join orbit_subset_product c
      on (a.orbit = c.orbit
      and a.subset = c.subset)
      and c.product_type = '2A25'
    left outer join orbit_subset_product d
      on (a.orbit = d.orbit
      and a.subset = d.subset)
      and d.product_type = '1C21';

grant select on collatedZproductswsub to public;


CREATE VIEW collatedmosaicswsub as
select a.*, min(b.filename) as first, max(c.filename) as second
  from collatecolswsub a natural join coincident_mosaic b
  left outer join coincident_mosaic c on (b.orbit=c.orbit
   and b.filename!=c.filename)
  group by a.orbit, overpass_time, nominal, radar_id, subset;

grant select on collatedmosaicswsub to public;

CREATE VIEW gvradar_fullpath as
select product, radar_id, nominal,
       '/data/gv_radar/finalQC_in/'||radar_id||'/'||filepath||'/'||filename as fullpath
  from gvradar;

grant select on gvradar_fullpath to public;

create view collatedGVproducts as 
select a.*, a.radar_id||'/'||b.filepath||'/'||b.filename as file2A55,
       a.radar_id||'/'||c.filepath||'/'||c.filename as file2A54,
       a.radar_id||'/'||d.filepath||'/'||d.filename as file1CUF,
       a.radar_id||'/'||e.filepath||'/'||e.filename as file1C51
  from collatecolswsub a 
    left outer join gvradar b
      on a.nominal=b.nominal and a.radar_id=b.radar_id
      and b.product = '2A55'
    left outer join gvradar c
      on a.nominal=c.nominal and a.radar_id=c.radar_id
      and c.product = '2A54'
    left outer join gvradar d
      on a.nominal=d.nominal and a.radar_id=d.radar_id
      and d.product = '1CUF'
    left outer join gvradar e
      on a.nominal=e.nominal and a.radar_id=e.radar_id
      and e.product = '1C51';

grant select on collatedGVproducts to public;
