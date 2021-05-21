-- set up temp tables with same format as geo_match_product

select * into temp geo_match_product_temp from geo_match_product limit 1;
delete from geo_match_product_temp;

-- load the 'new' rows from loadfile into temp table, excluding event_num column
\copy geo_match_product_temp  (radar_id, orbit, pathname, pps_version, parameter_set, geo_match_version, num_gr_volumes, instrument_id, sat_id, scan_type) FROM '/data/tmp/catalogGeoMatchProducts.unl' WITH DELIMITER '|'

-- look for duplicate entries between temp table and permanent table based on unique key attributes
select b.* into temp geo_match_product_dups from geo_match_product a join geo_match_product_temp b USING (radar_id, orbit, instrument_id, sat_id, scan_type, pps_version, parameter_set, geo_match_version);

select 'Key Dups', * from geo_match_product_dups;

delete from geo_match_product_temp where pathname in (select pathname from geo_match_product_dups);

-- look for duplicate entries between temp table and permanent table based on file pathnames

select b.* into temp geo_match_product_dups2 from geo_match_product a, geo_match_product_temp b where a.pathname=b.pathname;

select 'File pathname Dups', * from geo_match_product_dups2;

delete from geo_match_product_temp where pathname in (select pathname from geo_match_product_dups2);

-- get the associated event_num from the overpass_event table, first tagging all as missing

update geo_match_product_temp set event_num =-99;

-- update to psql 10 required "row" be added
update geo_match_product_temp set (event_num) = row(overpass_event.event_num) from overpass_event where geo_match_product_temp.sat_id = overpass_event.sat_id and geo_match_product_temp.radar_id = overpass_event.radar_id and geo_match_product_temp.orbit = overpass_event.orbit;

select 'No matching event_num', * from geo_match_product_temp where event_num = -99;

select * from geo_match_product_temp;
-- dump the rows to be inserted into a scratch file
\copy geo_match_product_temp TO '/data/tmp/catalogGeoMatchProducts2insert.unl' WITH DELIMITER '|'

-- insert remaining non-duplicate rows into permanent table
insert into geo_match_product select * from geo_match_product_temp where event_num != -99;

