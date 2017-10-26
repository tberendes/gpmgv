
--select *, num_gr_volumes as event_num into geo_match_product_temp from geo_match_product;
--ALTER TABLE geo_match_product_temp ADD PRIMARY KEY(radar_id, orbit, instrument_id, sat_id, scan_type, pps_version, parameter_set, geo_match_version);
--update geo_match_product_temp set event_num =-99;


-- add event_num to table geo_match_product
-- first, back the table up.  run from unix command line, not psql
-- pg_dump -t geo_match_product -f /data/tmp/geo_match_product.dump gpmgv

ALTER TABLE geo_match_product ADD COLUMN event_num INTEGER;
update geo_match_product set event_num =-99;

update geo_match_product set (event_num) = (overpass_event.event_num) from overpass_event where geo_match_product.sat_id = overpass_event.sat_id and geo_match_product.radar_id = overpass_event.radar_id and geo_match_product.orbit = overpass_event.orbit;

update geo_match_product set (event_num) = (overpass_event.event_num) from overpass_event where geo_match_product.sat_id = 'TRMM' and overpass_event.sat_id ='PR'  and geo_match_product.radar_id = overpass_event.radar_id and geo_match_product.orbit = overpass_event.orbit;

select count(*) from geo_match_product where event_num =-99;
delete from geo_match_product where event_num =-99;
ALTER TABLE geo_match_product ADD FOREIGN KEY(event_num) REFERENCES overpass_event(event_num);

ALTER TABLE geo_match_product ADD UNIQUE (event_num, instrument_id, scan_type, pps_version, parameter_set, geo_match_version);
