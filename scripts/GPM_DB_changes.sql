drop view collated_orb_subset_prods;
drop view collatedprproductswsub;
drop view collate_2a12_1cuf ;

ALTER TABLE orbit_subset_product ALTER COLUMN version TYPE varchar(5) USING version::CHARACTER VARYING(5);

ALTER TABLE geo_match_product ALTER COLUMN pps_version TYPE varchar(5) USING pps_version::CHARACTER VARYING(5);
ALTER TABLE geo_match_product ADD COLUMN sat_id varchar(15) default 'PR';
alter table geo_match_product drop constraint geo_match_product_pkey;
ALTER TABLE geo_match_product ADD PRIMARY KEY (radar_id, orbit, instrument_id, sat_id, pps_version, parameter_set, geo_match_version);
ALTER TABLE geo_match_product ALTER COLUMN sat_id DROP DEFAULT;
ALTER TABLE geo_match_product ALTER COLUMN pps_version DROP DEFAULT;
update geo_match_product set sat_id = 'TRMM' where instrument_id='PR';
update geo_match_product set sat_id = 'TRMM' where instrument_id='TMI';

drop view collatedproductswsub2;
drop view collatedproductswsub;
drop view collatedproducts;
drop view collatedzproductswsub;
drop view collatedzproducts;

ALTER TABLE orbit_subset_product ALTER COLUMN product_type TYPE varchar(15);
ALTER TABLE orbit_subset_product ALTER COLUMN filename TYPE varchar(120);


CREATE VIEW collate_2a12_1cuf AS
 SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, t.version, t.filename AS file2a12, COALESCE((((a.radar_id::text || '/'::text) || g.filepath::text) || '/'::text) || g.filename::text, 'no_1CUF_file'::text) AS file1cuf
   FROM collatecolswsub a
   LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset::text = t.subset::text AND t.product_type = '2A12'::bpchar
   LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id::text = g.radar_id::text AND g.product::text ~~ '1CUF%'::text;

CREATE VIEW collatedprproductswsub AS
SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM collatecolswsub a
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset::text = d.subset::text AND d.product_type = '1C21'::bpchar
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset::text = e.subset::text AND d.version = e.version AND e.product_type = '2A23'::bpchar
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset::text = f.subset::text AND d.version = f.version AND f.product_type = '2A25'::bpchar
   LEFT JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset::text = h.subset::text AND d.version = h.version AND h.product_type = '2B31'::bpchar;

CREATE VIEW collated_orb_subset_prods AS
 SELECT a.sat_id, a.orbit, a.filedate, a.subset, a.version, a.filename AS file1c21, b.filename AS file2a23, c.filename AS file2a25, d.filename AS file2b31
   FROM orbit_subset_product a
   FULL JOIN orbit_subset_product b ON a.sat_id::text = b.sat_id::text AND a.orbit = b.orbit AND a.subset::text = b.subset::text AND a.version = b.version AND b.product_type = '2A23'::bpchar
   FULL JOIN orbit_subset_product c ON a.sat_id::text = c.sat_id::text AND a.orbit = c.orbit AND a.subset::text = c.subset::text AND a.version = c.version AND c.product_type = '2A25'::bpchar
   FULL JOIN orbit_subset_product d ON a.sat_id::text = d.sat_id::text AND a.orbit = d.orbit AND a.subset::text = d.subset::text AND a.version = d.version AND d.product_type = '2B31'::bpchar
  WHERE a.product_type = '1C21'::bpchar;

CREATE VIEW collatedproductswsub2 AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, g.filename AS file2a53, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM collatecolswsub2 a
   LEFT JOIN gvradar g ON a.nominal = g.nominal AND a.radar_id::text = g.radar_id::text AND g.product::text = '2A53'::text
   LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id::text = b.radar_id::text AND b.product::text = '2A54'::text
   LEFT JOIN gvradar c ON a.nominal = c.nominal AND a.radar_id::text = c.radar_id::text AND c.product::text = '2A55'::text
   LEFT JOIN orbit_subset_product d ON a.sat_id::text = d.sat_id::text AND a.orbit = d.orbit AND a.subset::text = d.subset::text AND d.product_type = '1C21'::bpchar
   LEFT JOIN orbit_subset_product e ON a.sat_id::text = e.sat_id::text AND a.orbit = e.orbit AND a.subset::text = e.subset::text AND e.product_type = '2A23'::bpchar
   LEFT JOIN orbit_subset_product f ON a.sat_id::text = f.sat_id::text AND a.orbit = f.orbit AND a.subset::text = f.subset::text AND f.product_type = '2A25'::bpchar
   LEFT JOIN orbit_subset_product h ON a.sat_id::text = h.sat_id::text AND a.orbit = h.orbit AND a.subset::text = h.subset::text AND h.product_type = '2B31'::bpchar;

CREATE VIEW collatedproductswsub AS
 SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, g.filename AS file2a53, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM collatecolswsub a
   LEFT JOIN gvradar g ON a.nominal = g.nominal AND a.radar_id::text = g.radar_id::text AND g.product::text = '2A53'::text
   LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id::text = b.radar_id::text AND b.product::text = '2A54'::text
   LEFT JOIN gvradar c ON a.nominal = c.nominal AND a.radar_id::text = c.radar_id::text AND c.product::text = '2A55'::text
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset::text = d.subset::text AND d.product_type = '1C21'::bpchar
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset::text = e.subset::text AND e.product_type = '2A23'::bpchar
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset::text = f.subset::text AND f.product_type = '2A25'::bpchar
   LEFT JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset::text = h.subset::text AND h.product_type = '2B31'::bpchar;

CREATE VIEW collatedzproductswsub AS
 SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, (((a.radar_id::text || '/'::text) || b.filepath::text) || '/'::text) || b.filename::text AS file2a55, c.filename AS file2a25, d.filename AS file1c21
   FROM collatecolswsub a
   LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id::text = b.radar_id::text AND b.product::text = '2A55'::text
   LEFT JOIN orbit_subset_product c ON a.orbit = c.orbit AND a.subset::text = c.subset::text AND c.product_type = '2A25'::bpchar
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset::text = d.subset::text AND d.product_type = '1C21'::bpchar;

CREATE VIEW collatedzproducts AS
 SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, (((a.radar_id::text || '/'::text) || b.filepath::text) || '/'::text) || b.filename::text AS file2a55, c.filename AS file2a25, d.filename AS file1c21
   FROM collatecols a
   LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id::text = b.radar_id::text AND b.product::text = '2A55'::text
   LEFT JOIN orbit_subset_product c ON a.orbit = c.orbit AND c.product_type = '2A25'::bpchar
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND d.product_type = '1C21'::bpchar;

CREATE VIEW collatedproducts AS
 SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, b.filename AS file2a54, c.filename AS file2a55, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25
   FROM collatecols a
   LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id::text = b.radar_id::text AND b.product::text = '2A54'::text
   LEFT JOIN gvradar c ON a.nominal = c.nominal AND a.radar_id::text = c.radar_id::text AND c.product::text = '2A55'::text
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND d.product_type = '1C21'::bpchar
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND e.product_type = '2A23'::bpchar
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND f.product_type = '2A25'::bpchar;


-- define new satellite/subset combos
\copy productsubset from /home/morris/swdev/scripts/new_productsubset.unl with delimiter '|'
select * into temp pstemp from productsubset where sat_id='PR';
update pstemp set sat_id='TRMM';
insert into productsubset select * from pstemp where subset not in('KWAJ','DARW');

-- define new table as lookup for instrument subdirectory
CREATE TABLE sat_instrument_algorithm(
   satellite VARCHAR(15),
   instrument VARCHAR(15),
   algorithm VARCHAR(15),
   PRIMARY KEY (satellite, instrument, algorithm)
);
\copy sat_instrument_algorithm from /home/morris/swdev/scripts/sat_instrument_algorithm.unl with delimiter '|'

   
insert into siteproductsubset select 'GMI','CONUS', instrument_id from fixed_instrument_location where latitude>24. and latitude<55. and longitude>-140. and longitude<-65.;

update siteproductsubset set sat_id='GPM' where sat_id='GMI';
   
insert into siteproductsubset select 'TRMM','CONUS', instrument_id from fixed_instrument_location where latitude>24. and latitude<37. and longitude>-140. and longitude<-65.;

select * into temp t1 from productsubset where sat_id='GPM';
update t1 set sat_id='GMI';
insert into productsubset select * from t1;

insert into productsubset values ('PR','CONUS');
select * into temp spstemp from siteproductsubset where subset='CONUS' and sat_id='TRMM';
update spstemp set sat_id ='PR';
insert into siteproductsubset select * from spstemp;
insert into productsubset values ('PR','KORA');
select * into temp spstemp from siteproductsubset where subset='GPM_KMA';
update spstemp set subset='KORA';
insert into siteproductsubset select * from spstemp;


-- Define new VIEWs taking sat_id into account
CREATE VIEW collatecolswsubsat AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, date_trunc('hour'::text, a.overpass_time) AS nominal, b.subset
   FROM overpass_event a, siteproductsubset b
  WHERE a.radar_id = b.radar_id AND a.sat_id = b.sat_id;

CREATE VIEW collatedprproductswsub AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM collatecolswsubsat a
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset = d.subset AND a.sat_id = d.sat_id AND d.product_type = '1C21'
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset = e.subset AND a.sat_id = e.sat_id AND d.version = e.version AND e.product_type = '2A23'
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset = f.subset AND a.sat_id = f.sat_id AND d.version = f.version AND f.product_type = '2A25'
   LEFT JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset = h.subset AND a.sat_id = h.sat_id AND d.version = h.version AND h.product_type = '2B31';

-- This VIEW adds a field for the time difference between the overpass time and the beginning
-- of the volume scan, to support finding the correct volume for a given radar when there is
-- more than one volume within +/-5 minutes of the overpass time.
CREATE VIEW collate_satsubprod_1cuf AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, t.version, t.product_type, t.filename, COALESCE((((a.radar_id || '/') || g.filepath) || '/') || g.filename, 'no_1CUF_file') AS file1cuf, COALESCE(g.nominal-a.overpass_time, INTERVAL '0 second') as tdiff FROM collatecolswsubsat a  LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND a.sat_id = t.sat_id  LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id = g.radar_id AND g.product like '1CUF%';

insert into metadata_parameter values (770199, 'INTEGER', 'GR 4km grid: Num Gridpoints inside 100km');
insert into metadata_parameter values (771105, 'INTEGER', 'GR 4km grid: Num Rain Certain inside 100km');
insert into metadata_parameter values (770101, 'INTEGER', 'GR 4km grid: Num Rain Type Stratiform inside 100km');
insert into metadata_parameter values (770102, 'INTEGER', 'GR 4km grid: Num Rain Type Convective inside 100km');
insert into metadata_parameter values (770103, 'INTEGER', 'GR 4km grid: Num Rain Type Other inside 100km');

-- redefine VIEWS with event_num and nearest_distance added, rename collatecolswsubsat to eventsatsubrad_vw
drop view collatedprproductswsub;
drop view collate_satsubprod_1cuf;
drop view collatecolswsubsat;
CREATE VIEW eventsatsubrad_vw AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, date_trunc('hour'::text, a.overpass_time) AS nominal, b.subset, a.event_num, a.nearest_distance
   FROM overpass_event a, siteproductsubset b
  WHERE a.radar_id = b.radar_id AND a.sat_id = b.sat_id;

CREATE VIEW collatedprproductswsub AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset = d.subset AND a.sat_id = d.sat_id AND d.product_type = '1C21'
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset = e.subset AND a.sat_id = e.sat_id AND d.version = e.version AND e.product_type = '2A23'
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset = f.subset AND a.sat_id = f.sat_id AND d.version = f.version AND f.product_type = '2A25'
   LEFT JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset = h.subset AND a.sat_id = h.sat_id AND d.version = h.version AND h.product_type = '2B31';

CREATE VIEW collate_satsubprod_1cuf AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((a.radar_id || '/') || g.filepath) || '/') || g.filename, 'no_1CUF_file') AS file1cuf, COALESCE(g.nominal-a.overpass_time, INTERVAL '0 second') as tdiff FROM eventsatsubrad_vw a  LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND a.sat_id = t.sat_id  LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id = g.radar_id AND g.product like '1CUF%';

-- add sat_id and event_num to table rainy100inside100,
--  - PROBABLY NEED THE SAME FOR rainy100by2a53
-- first, back the table up.  run from unix command line, not psql
;pg_dump -t rainy100inside100 -f /data/gpmgv/tmp/rainy100inside100.dump gpmgv

-- drop the dependent VIEW
drop view rainy100merged_vw;

- drop and recreate table
drop table rainy100inside100;
CREATE TABLE rainy100inside100 (
    sat_id character varying(15) NOT NULL,
    radar_id character varying(15) NOT NULL,
    orbit integer NOT NULL,
    event_num integer REFERENCES overpass_event(event_num),
    overpass_time timestamp with time zone,
    pct_overlap double precision,
    pct_overlap_conv double precision,
    pct_overlap_strat double precision,
    num_overlap_rain_certain double precision,
    PRIMARY KEY (sat_id, radar_id, orbit)
);
grant insert, select, update on rainy100inside100 to PUBLIC;

-- populate rainy100inside100
INSERT INTO rainy100inside100
select a.sat_id, a.radar_id, a.orbit, a.event_num, a.overpass_time, b.value/19.61 as pct_overlap, (c.value/b.value)*100 as pct_overlap_conv, (d.value/b.value)*100 as pct_overlap_strat, e.value as num_overlap_Rain_certain
from overpass_event a
    JOIN event_meta_numeric b ON a.event_num = b.event_num AND b.metadata_id = 250199
    JOIN event_meta_numeric c ON a.event_num = c.event_num AND c.metadata_id = 230102
    JOIN event_meta_numeric d ON a.event_num = d.event_num AND d.metadata_id = 230101
    JOIN event_meta_numeric e ON a.event_num = e.event_num AND e.metadata_id = 251105 and e.value >= 100 order by 4;

-- recreate the view, probably need sat_id added, check scripts
CREATE VIEW rainy100merged_vw as
 SELECT rainy100by2a53.radar_id, rainy100by2a53.orbit, rainy100by2a53.overpass_time
   FROM rainy100by2a53
UNION 
 SELECT rainy100inside100.radar_id, rainy100inside100.orbit, rainy100inside100.overpass_time
   FROM rainy100inside100;
-- getMissingNAMANLgrids.sh:# update the list of rainy overpasses in database table 'rainy100by2a53'
-- getMissingNAMANLgrids.sh: UNION select a.orbit, min(overpass_time at time zone 'UTC') from rainy100by2a53 a,\
-- getNAMANLgrids4RainCases.sh:# update the list of rainy overpasses in database table 'rainy100by2a53'
-- getNAMANLgrids4RainCases.sh: UNION select a.orbit, min(overpass_time at time zone 'UTC') from rainy100by2a53 a,\

-- add radar ID "NPOL" for NC field campaign in Apr-May 2014
select * from instemp;
 instrument_id | instrument_type | instrument_name | owner | parent_child | produces_data | fixed_or_moving |  coverage_type  | replaced_by_id 
---------------+-----------------+-----------------+-------+--------------+---------------+-----------------+-----------------+----------------
 NPOL          | NPOL            | NPOL            | NASA  | N            | Y             | F               | radial scan PPI | NA
(1 row)
insert into instrument select * from instemp;
insert into fixed_instrument_location values ('NPOL','2014-03-01','NC','US',35.196203, -81.963758,300);

-- load overpass events for non-CT radars for orbit 1327
insert into overpass_event(sat_id,orbit,radar_id,overpass_time,nearest_distance) values ('GPM',1327,'NPOL','2014-05-23 19:16:48-04',20);
insert into overpass_event(sat_id,orbit,radar_id,overpass_time,nearest_distance) values ('GPM',1327,'KGSP','2014-05-23 19:16:09-04',28);
insert into overpass_event(sat_id,orbit,radar_id,overpass_time,nearest_distance) values ('GPM',1327,'KCAE','2014-05-23 19:16:36-04',114);

-- handle issue where sat_id is 'PR' in overpass_event and 'TRMM' in orbit_subset_product
-- for new GPM-era PR filenames

create view collatedPRtoTRMMproducts as
 SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset::text = d.subset::text AND a.sat_id::text = 'PR' and d.sat_id::text = 'TRMM' AND d.product_type::text = '1C21'::text
   LEFT JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset::text = e.subset::text AND a.sat_id::text = 'PR' and e.sat_id::text = 'TRMM' AND d.version::text = e.version::text AND e.product_type::text = '2A23'::text
   LEFT JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset::text = f.subset::text AND a.sat_id::text = 'PR' and f.sat_id::text = 'TRMM' AND d.version::text = f.version::text AND f.product_type::text = '2A25'::text
   LEFT JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset::text = h.subset::text AND a.sat_id::text = 'PR' and h.sat_id::text = 'TRMM' AND d.version::text = h.version::text AND h.product_type::text = '2B31'::text;

CREATE VIEW collate_satsubprod_1cuf_TMIGPROF AS
SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((a.radar_id || '/') || g.filepath) || '/') || g.filename, 'no_1CUF_file') AS file1cuf, COALESCE(g.nominal-a.overpass_time, INTERVAL '0 second') as tdiff FROM eventsatsubrad_vw a  LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND a.sat_id='PR' and t.sat_id='TRMM'  LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id = g.radar_id AND g.product like '1CUF%';

-- altered on 29 Jan 2015
ALTER TABLE geo_match_product ADD COLUMN scan_type varchar(5) default 'NA';
update geo_match_product set scan_type = 'NS' where instrument_id='PR';
update geo_match_product set scan_type = 'NS' where sat_id = 'GPM' and instrument_id='Ku';
update geo_match_product set scan_type = 'HS' where sat_id = 'GPM' and instrument_id='Ka' and pathname like '%.HS.%';
update geo_match_product set scan_type = 'MS' where sat_id = 'GPM' and instrument_id='Ka' and pathname like '%.MS.%';
update geo_match_product set scan_type = 'HS' where sat_id = 'GPM' and instrument_id='DPR' and pathname like '%.HS.%';
update geo_match_product set scan_type = 'MS' where sat_id = 'GPM' and instrument_id='DPR' and pathname like '%.MS.%';
update geo_match_product set scan_type = 'NS' where sat_id = 'GPM' and instrument_id='DPR' and pathname like '%.NS.%';
alter table geo_match_product drop constraint geo_match_product_pkey;
ALTER TABLE geo_match_product ADD PRIMARY KEY (radar_id, orbit, instrument_id, sat_id, scan_type, pps_version, parameter_set, geo_match_version);

-- altered on 9 Feb 2015
insert into siteproductsubset values ('TRMM','KWAJ','KWAJ');

-- inserted on 9 March 2015
select * into temp t1 from productsubset where sat_id in ('GPM','GMI') and subset='KORA';
update t1 set subset='Guam';
 select * from t1;
 sat_id | subset 
--------+--------
 GPM    | Guam
 GMI    | Guam
(2 rows)
insert into productsubset select * from t1;

update t1 set subset='Hawaii';
select * from t1;
 sat_id | subset 
--------+--------
 GPM    | Hawaii
 GMI    | Hawaii
(2 rows)
insert into productsubset select * from t1;

update t1 set subset='SanJuanPR';
select * from t1;
 sat_id |  subset   
--------+-----------
 GPM    | SanJuanPR
 GMI    | SanJuanPR
(2 rows)
insert into productsubset select * from t1;

select * from productsubset where sat_id in ('GPM','GMI') order by 1,2;
 sat_id |  subset   
--------+-----------
 GMI    | AKradars
 GMI    | CONUS
 GMI    | DARW
 GMI    | Guam
 GMI    | Hawaii
 GMI    | KORA
 GMI    | KOREA
 GMI    | KWAJ
 GMI    | SanJuanPR
 GPM    | AKradars
 GPM    | CONUS
 GPM    | DARW
 GPM    | Guam
 GPM    | Hawaii
 GPM    | KORA
 GPM    | KOREA
 GPM    | KWAJ
 GPM    | SanJuanPR
(18 rows)

insert into siteproductsubset values ('GPM','Guam','PGUA');
insert into siteproductsubset values ('GPM','SanJuanPR','TJUA');
insert into siteproductsubset values ('GPM','Hawaii','PHMO');
insert into siteproductsubset values ('GPM','Hawaii','PHKI');
insert into siteproductsubset values ('GPM','Hawaii','PHWA');
insert into siteproductsubset values ('GPM','Hawaii','PHKM');
insert into siteproductsubset values ('GPM','AKradars','PAEC');

-- 4/20/15 additions
-- new view to just collate overpass events with their matching. non-missing, 1CUF file
-- no information on presence of the GPM subset product(s) for the orbit
CREATE VIEW collate_sat_radar_overpass_1cuf AS select a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, (((a.radar_id::text || '/'::text) || g.filepath::text) || '/'::text) || g.filename::text AS file1cuf, fileidnum from  eventsatsubrad_vw a JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id::text = g.radar_id::text AND g.product::text ~~ '1CUF%'::text;

-- new table to hold mapping of overpass_event to time-matched 1CUF file(s)
select event_num, fileidnum into eventnum_fileidnum from collate_sat_radar_overpass_1cuf where sat_id='GPM';
alter table eventnum_fileidnum add primary key(event_num,fileidnum);

-- find overpass events with more than one 1CUF file mapped to them
select a.*, b.filename from eventnum_fileidnum a, gvradar b where 1 < (select count(*) from eventnum_fileidnum c where a.event_num=c.event_num) and a.fileidnum=b.fileidnum;

-- set up subset for CP2 radar
insert into productsubset values ('GPM','Brisbane');
insert into siteproductsubset values( 'GPM','Brisbane','CP2');
insert into productsubset values( 'TRMM','Brisbane');
insert into siteproductsubset values( 'TRMM','Brisbane','CP2');
insert into productsubset values( 'PR','Brisbane');
insert into siteproductsubset values( 'PR','Brisbane','CP2');

-- set up for Brazil radars
\copy instrument from /home/morris/Brazil_Instrument.unl with delimiter '|'

select * from instrument where owner='CEMADEN-Brazil';
NT1|SELEX SPOL|Natal|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
TM1|SELEX SPOL|Tres Marias|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
SV1|SELEX SPOL|Salvador|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
ST1|SELEX SPOL|Santa Teresa|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
AL1|SELEX SPOL|Almenara|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
MC1|SELEX SPOL|Maceio|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
JG1|SELEX SPOL|Jaraguari|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
SF1|SELEX SPOL|Sao Francisco|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA
PE1|SELEX SPOL|Petrolina|CEMADEN-Brazil|N|Y|F|radial scan PPI|NA

\copy fixed_instrument_location from /home/morris/Brazil_FixedInstrLoc.unl with delimiter '|'

select * from fixed_instrument_location where country='BR';
NT1|2014-01-01|RN|BR|-5.90444|-35.254|99
TM1|2014-01-01|MG|BR|-18.2072|-45.4606|99
SV1|2014-01-01|BA|BR|-12.9025|-38.3267|99
ST1|2014-01-01|RJ|BR|-19.9888|-40.5794|99
AL1|2014-01-01|MG|BR|-16.2019|-40.6742|99
MC1|2014-01-01|AL|BR|-9.55139|-35.7708|99
JG1|2014-01-01|MS|BR|-20.2915|-54.4658|99
SF1|2014-01-01|SC|BR|-16.0173|-44.6953|99
PE1|2014-01-01|PE|BR|-9.36722|-40.5728|99


-- view to match NPOL_MD overpasses to NPOL radar files
create view collate_npol_md_1cuf as SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((g.radar_id || '/') || g.filepath) || '/') || g.filename, 'no_1CUF_file') AS file1cuf, COALESCE(g.nominal - a.overpass_time, '00:00:00'::interval) AS tdiff
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND a.sat_id = t.sat_id
   LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id = 'NPOL_MD' AND g.radar_id = 'NPOL' AND g.product ~~ '1CUF%'
WHERE a.radar_id = 'NPOL_MD';

-----------------------------------------------------------------------------
---ALL THESE CHANGES GOT LOST WHEN THE DATABASE WAS 'LOST' IN THE DS1
---UPGRADE ON 9/8/15, SO DATABASE WAS RECREATED FROM /data/db_backup/gpmgvDBdump.21Jul15.gz

--- moved all these table definitions and their data to the new 'vnstats' database
--- before deleting the tables from 'gpmgv', e.g.:

[morris@ds1-gpmgv scripts]$ pg_dump -t dbzdiff_stats_by_angle gpmgv | psql vnstats

--- last gpmgv backup before this happened: /data/db_backup/gpmgvDBdump.21Jul15.gz

drop table dbzdiff_stats_by_angle;
drop table dbzdiff_stats_by_dist;
drop table dbzdiff_stats_by_dist_geo;
drop table dbzdiff_stats_by_dist_geo_225;
drop table dbzdiff_stats_by_dist_geo_bb;
drop table dbzdiff_stats_by_dist_geo_s2ku;
drop table dbzdiff_stats_by_dist_geo_s2ku_225;
drop table dbzdiff_stats_by_dist_geo_s2ku_v6_18dbzgr;
drop table dbzdiff_stats_by_dist_geo_s2ku_v6_prlx;
drop table dbzdiff_stats_by_dist_geo_s2ku_v6bbrel;
drop table dbzdiff_stats_by_dist_geo_s2ku_v7bbrel;
drop table dbzdiff_stats_by_dist_geo_v6_18dbzgr;
drop table dbzdiff_stats_by_dist_geo_v6_prlx;
drop table dbzdiff_stats_by_dist_geo_v6bbrel;
drop table dbzdiff_stats_by_dist_geo_v7bbrel;
drop table dbzdiff_stats_by_dist_gpm_ku;
drop table dbzdiff_stats_by_dist_gpm_ku_bbrel;
drop table dbzdiff_stats_by_dist_gpm_ku_s2ku;
drop table dbzdiff_stats_by_dist_gpm_ku_s2ku_bbrel;
drop table dbzdiff_stats_by_dist_ku_s2ku_bbrel_sd;
drop table dbzdiff_stats_by_dist_pr_v7_s2ku;
drop table dbzdiff_stats_by_sfc_geo;
drop table dbzdiff_stats_default;
drop table dbzdiff_stats_defaultnewbb;
drop view dbzdiff_stats_merged;                
drop view dbzdiff_stats_mergednewbb;                 
drop table dbzdiff_stats_prrawcor;
drop table dbzdiff_stats_prrawcornewbb;
drop table dbzdiff_stats_s2ku;
drop table dbzdiff_stats_s2kunewbb;
drop table rr_pr_grbyzr2waysorig;
drop table rr_pr_grbyzr2ways;
drop table rrdiff_by_sources_rntype_sfc_loose_nn;
drop table rrdiff_by_sources_rntype_sfc_paired_nn;
drop table rrdiff_stats_by_dist_time_geo_kma;
drop table rrdiff_stats_default;
drop table rrdiff_stats_defaultnewbb;
drop table rrdiff_stats_s2ku;
drop table rrdiff_stats_s2kunewbb;
drop table stratstats;
drop table stratstats_bb;
drop table stratstats_bb2;
drop table stratstats_bb_byorb;
drop table stratstatsfc;
drop table zdiff_stats_by_dist_time_geo;
drop table zdiff_stats_by_dist_time_geo18;
drop table zdiff_stats_by_dist_time_geo_kma;
drop table zdiff_stats_by_dist_time_geo_kma_bbrel;
drop table zdiff_stats_by_dist_time_geo_kma_s2ku;
drop table zdiff_stats_by_dist_time_geo_kma_s2ku_bbrel;
drop table zdiff_stats_by_dist_time_geo_s2ku;
drop table zdiff_stats_by_dist_time_geo_s2ku18;
drop table zdiff_stats_by_dist_time_geo_s2kuv7;
drop table zdiff_stats_by_dist_time_geov7;
drop table zdiff_stats_by_dist_time_prz_kma;
drop table zdiff_stats_by_dist_time_prz_kma_s2ku;
drop table zdiff_stats_dpr;
drop table zdiff_stats_dpr_s2ku;
drop table zdiff_stats_pr;
drop table zdiff_stats_pr_s2ku;

-- copied these tables over to vnstats database on 10 Aug 2015 - DON'T DELETE FROM gpmgv!!!!
pg_dump -t lineage gpmgv | psql vnstats
pg_dump -t instrument gpmgv | psql vnstats
pg_dump -t fixed_instrument_location gpmgv | psql vnstats
pg_dump -t productsubset gpmgv | psql vnstats
pg_dump -t siteproductsubset gpmgv | psql vnstats

--- END OF 'LOST' CHANGES ON 9/8/15
-----------------------------------------------------------------------------

-- 10/19/15 additions
-- define CONUS siteproductsubset for constellation

gpmgv=> select * into temp spstemp from siteproductsubset where sat_id='GPM' and subset='CONUS';
SELECT
gpmgv=> update spstemp set sat_id='F16';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='F17';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='F18';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='GCOMW1';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='METOPA';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='METOPB';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='NOAA18';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149
gpmgv=> update spstemp set sat_id='NOAA19';
UPDATE 149
gpmgv=> insert into siteproductsubset select * from spstemp;
INSERT 0 149

-- define observing instruments for constellation

select * into temp insadd from instrument where instrument_id='TMI';
update insadd set instrument_name='satellite Microwave Imager';
update insadd set instrument_id='AMSR2';
update insadd set owner='GCOMW1';
insert into instrument select * from insadd;
update insadd set owner='DoD';
 update insadd set instrument_id='SSMIS';
insert into instrument select * from insadd;
update insadd set owner='NOAA';  -- ignore METOP that has same MHS id
update insadd set instrument_id='MHS';
insert into instrument select * from insadd;

-- 11/16/15 create BrazilRadars orbit subset, already have the radars defined.
--  create productsubset entries first, use KOREA subset as starting point, skip TRMM, PR
 
gpmgv=> select * into temp brzladd from productsubset where subset='KOREA' and sat_id not in ('TRMM','PR');
SELECT

gpmgv=> update brzladd set subset='BrazilRadars';
UPDATE 11
gpmgv=> select * from brzladd;
 sat_id |    subset    
--------+--------------
 GPM    | BrazilRadars
 GCOMW1 | BrazilRadars
 F15    | BrazilRadars
 F16    | BrazilRadars
 F17    | BrazilRadars
 F18    | BrazilRadars
 METOPA | BrazilRadars
 NOAA18 | BrazilRadars
 NOAA19 | BrazilRadars
 GMI    | BrazilRadars
 METOPB | BrazilRadars
(11 rows)

gpmgv=> insert into productsubset select * from brzladd;
INSERT 0 11

-- now join temp table entries with Brazil radar IDs to define siteproductsubset additions
--   - check result first
gpmgv=> select a.*, b.instrument_id from brzladd a join fixed_instrument_location b on b.country='BR';
          ((99 rows not shown))
(99 rows)

-- looked OK, insert values into siteproductsubset table
gpmgv=> insert into siteproductsubset select a.*, b.instrument_id from brzladd a join fixed_instrument_location b on b.country='BR';
INSERT 0 99


-- view to match NPOL_WA overpasses to NPOL radar files
create view collate_npol_wa_1cuf as SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((g.radar_id || '/') || g.filepath) || '/') || g.filename, 'no_1CUF_file') AS file1cuf, COALESCE(g.nominal - a.overpass_time, '00:00:00'::interval) AS tdiff
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND a.sat_id = t.sat_id
   LEFT JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id = 'NPOL_WA' AND g.radar_id = 'NPOL' AND g.product ~~ '1CUF%'
WHERE a.radar_id = 'NPOL_WA';


-- Increase the char size of the version column to handle the likes of 'ITE049' etc.
-- - Need to drop the PK and VIEWs that use this table/column and re-create them after the type alterations
-- IMPORTANT: Did a pg_dump -s to get the current schema for these views before dropping them

ALTER TABLE orbit_subset_product drop constraint orbit_subset_product_pkey;
alter table geo_match_product drop constraint geo_match_product_pkey;
drop view collate_npol_wa_1cuf;
drop view collate_2a12_1cuf;
drop view collate_npol_md_1cuf;
drop view collate_satsubprod_1cuf;
drop view collate_satsubprod_1cuf_tmigprof;
drop view collatedprproductswsub;
drop view collatedprtotrmmproducts;
ALTER TABLE orbit_subset_product ALTER COLUMN version TYPE varchar(8);
ALTER TABLE geo_match_product ALTER COLUMN pps_version TYPE varchar(8);
ALTER TABLE geo_match_product_dups ALTER COLUMN pps_version TYPE varchar(8);
ALTER TABLE temp_n_geo ALTER COLUMN version TYPE varchar(8);
ALTER TABLE ONLY orbit_subset_product ADD CONSTRAINT orbit_subset_product_pkey PRIMARY KEY (sat_id, subset, orbit, product_type, version);
ALTER TABLE geo_match_product ADD PRIMARY KEY (radar_id, orbit, instrument_id, sat_id, scan_type, pps_version, parameter_set, geo_match_version);
CREATE VIEW collate_2a12_1cuf AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, t.version, t.filename AS file2a12, COALESCE((((((a.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf FROM ((collatecolswsub a LEFT JOIN orbit_subset_product t ON ((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((t.product_type)::bpchar = '2A12'::bpchar)))) LEFT JOIN gvradar g ON (((((a.overpass_time >= (g.nominal - '00:05:00'::interval)) AND (a.overpass_time <= (g.nominal + '00:05:00'::interval))) AND ((a.radar_id)::text = (g.radar_id)::text)) AND ((g.product)::text ~~ '1CUF%'::text))));
CREATE VIEW collate_npol_md_1cuf AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((((g.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf, COALESCE((g.nominal - a.overpass_time), '00:00:00'::interval) AS tdiff FROM ((eventsatsubrad_vw a LEFT JOIN orbit_subset_product t ON ((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((a.sat_id)::text = (t.sat_id)::text)))) LEFT JOIN gvradar g ON ((((((a.overpass_time >= (g.nominal - '00:05:00'::interval)) AND (a.overpass_time <= (g.nominal + '00:05:00'::interval))) AND ((a.radar_id)::text = 'NPOL_MD'::text)) AND ((g.radar_id)::text = 'NPOL'::text)) AND ((g.product)::text ~~ '1CUF%'::text)))) WHERE ((a.radar_id)::text = 'NPOL_MD'::text);
CREATE VIEW collate_npol_wa_1cuf AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((((g.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf, COALESCE((g.nominal - a.overpass_time), '00:00:00'::interval) AS tdiff FROM ((eventsatsubrad_vw a LEFT JOIN orbit_subset_product t ON ((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((a.sat_id)::text = (t.sat_id)::text)))) LEFT JOIN gvradar g ON ((((((a.overpass_time >= (g.nominal - '00:05:00'::interval)) AND (a.overpass_time <= (g.nominal + '00:05:00'::interval))) AND ((a.radar_id)::text = 'NPOL_WA'::text)) AND ((g.radar_id)::text = 'NPOL'::text)) AND ((g.product)::text ~~ '1CUF%'::text)))) WHERE ((a.radar_id)::text = 'NPOL_WA'::text);
CREATE VIEW collate_satsubprod_1cuf AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((((a.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf, COALESCE((g.nominal - a.overpass_time), '00:00:00'::interval) AS tdiff FROM ((eventsatsubrad_vw a LEFT JOIN orbit_subset_product t ON ((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((a.sat_id)::text = (t.sat_id)::text)))) LEFT JOIN gvradar g ON (((((a.overpass_time >= (g.nominal - '00:05:00'::interval)) AND (a.overpass_time <= (g.nominal + '00:05:00'::interval))) AND ((a.radar_id)::text = (g.radar_id)::text)) AND ((g.product)::text ~~ '1CUF%'::text))));
CREATE VIEW collate_satsubprod_1cuf_tmigprof AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((((a.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf, COALESCE((g.nominal - a.overpass_time), '00:00:00'::interval) AS tdiff FROM ((eventsatsubrad_vw a LEFT JOIN orbit_subset_product t ON (((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((a.sat_id)::text = 'PR'::text)) AND ((t.sat_id)::text = 'TRMM'::text)))) LEFT JOIN gvradar g ON (((((a.overpass_time >= (g.nominal - '00:05:00'::interval)) AND (a.overpass_time <= (g.nominal + '00:05:00'::interval))) AND ((a.radar_id)::text = (g.radar_id)::text)) AND ((g.product)::text ~~ '1CUF%'::text))));
CREATE VIEW collatedprproductswsub AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM ((((eventsatsubrad_vw a LEFT JOIN orbit_subset_product d ON (((((a.orbit = d.orbit) AND ((a.subset)::text = (d.subset)::text)) AND ((a.sat_id)::text = (d.sat_id)::text)) AND ((d.product_type)::text = '1C21'::text)))) LEFT JOIN orbit_subset_product e ON ((((((a.orbit = e.orbit) AND ((a.subset)::text = (e.subset)::text)) AND ((a.sat_id)::text = (e.sat_id)::text)) AND ((d.version)::text = (e.version)::text)) AND ((e.product_type)::text = '2A23'::text)))) LEFT JOIN orbit_subset_product f ON ((((((a.orbit = f.orbit) AND ((a.subset)::text = (f.subset)::text)) AND ((a.sat_id)::text = (f.sat_id)::text)) AND ((d.version)::text = (f.version)::text)) AND ((f.product_type)::text = '2A25'::text)))) LEFT JOIN orbit_subset_product h ON ((((((a.orbit = h.orbit) AND ((a.subset)::text = (h.subset)::text)) AND ((a.sat_id)::text = (h.sat_id)::text)) AND ((d.version)::text = (h.version)::text)) AND ((h.product_type)::text = '2B31'::text))));
CREATE VIEW collatedprtotrmmproducts AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM ((((eventsatsubrad_vw a LEFT JOIN orbit_subset_product d ON ((((((a.orbit = d.orbit) AND ((a.subset)::text = (d.subset)::text)) AND ((a.sat_id)::text = 'PR'::text)) AND ((d.sat_id)::text = 'TRMM'::text)) AND ((d.product_type)::text = '1C21'::text)))) LEFT JOIN orbit_subset_product e ON (((((((a.orbit = e.orbit) AND ((a.subset)::text = (e.subset)::text)) AND ((a.sat_id)::text = 'PR'::text)) AND ((e.sat_id)::text = 'TRMM'::text)) AND ((d.version)::text = (e.version)::text)) AND ((e.product_type)::text = '2A23'::text)))) LEFT JOIN orbit_subset_product f ON (((((((a.orbit = f.orbit) AND ((a.subset)::text = (f.subset)::text)) AND ((a.sat_id)::text = 'PR'::text)) AND ((f.sat_id)::text = 'TRMM'::text)) AND ((d.version)::text = (f.version)::text)) AND ((f.product_type)::text = '2A25'::text)))) LEFT JOIN orbit_subset_product h ON (((((((a.orbit = h.orbit) AND ((a.subset)::text = (h.subset)::text)) AND ((a.sat_id)::text = 'PR'::text)) AND ((h.sat_id)::text = 'TRMM'::text)) AND ((d.version)::text = (h.version)::text)) AND ((h.product_type)::text = '2B31'::text))));


-- 2/12/16 create Finland orbit subset and IKAALINEN radar ID

select * into temp fininstr from instrument where instrument_id ='NPOL';
update fininstr set instrument_id='IKA';
update fininstr set instrument_type='IKA';
update fininstr set instrument_name='Ikaalinen';
update fininstr set owner='FMI';
insert into instrument select * from fininstr;

select * into temp fininstr from fixed_instrument_location  where instrument_id ='NPOL';
update fininstr set instrument_id='IKA';
update fininstr set state_province='PI';
update fininstr set country='FI';
update fininstr set latitude=61.767;
update fininstr set longitude=23.076;
update fininstr set elevation=153;
select * from fininstr;
 instrument_id | install_date | state_province | country | latitude | longitude | elevation 
---------------+--------------+----------------+---------+----------+-----------+-----------
 IKA           | 2014-03-01   | PI             | FI      |   61.767 |    23.076 |       153
(1 row)

insert into fixed_instrument_location select * from fininstr;
gpmgv=> select * from fixed_instrument_location where instrument_id='IKA';
 instrument_id | install_date | state_province | country | latitude | longitude | elevation 
---------------+--------------+----------------+---------+----------+-----------+-----------
 IKA           | 2014-03-01   | PI             | FI      |   61.767 |    23.076 |       153
(1 row)


--  create productsubset entries first, use KOREA subset for all satellites,
--  excluding TRMM and PR, as the starting point
 
select * into temp finladd from productsubset where subset='KOREA' and sat_id not in ('TRMM','PR');

-- change the subset from 'KOREA' to 'Finland' in temp table, and check result
update finladd set subset='Finland';
select * from finladd;

insert into productsubset select * from finladd;

-- now join temp table entries with Finland radar IDs to define siteproductsubset additions
--   - check result first
select a.*, b.instrument_id from finladd a join fixed_instrument_location b on b.country='FI';
 sat_id | subset  | instrument_id 
--------+---------+---------------
 GPM    | Finland | IKA
 GCOMW1 | Finland | IKA
 F15    | Finland | IKA
 F16    | Finland | IKA
 F17    | Finland | IKA
 F18    | Finland | IKA
 METOPA | Finland | IKA
 NOAA18 | Finland | IKA
 NOAA19 | Finland | IKA
 GMI    | Finland | IKA
 METOPB | Finland | IKA
(11 rows)

-- looked OK, insert values into siteproductsubset table
insert into siteproductsubset select a.*, b.instrument_id from finladd a join fixed_instrument_location b on b.country='FI';


-- increase time offset to search for matching NPOL_WA volume scans, let queries in matchup script
-- handle finding the nearest-in-time volume

drop view collate_npol_wa_1cuf;
CREATE VIEW collate_npol_wa_1cuf AS
    SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, t.version, t.product_type, t.filename, COALESCE((((((g.radar_id)::text || '/'::text) || (g.filepath)::text) || '/'::text) || (g.filename)::text), 'no_1CUF_file'::text) AS file1cuf, COALESCE((g.nominal - a.overpass_time), '00:00:00'::interval) AS tdiff FROM ((eventsatsubrad_vw a LEFT JOIN orbit_subset_product t ON ((((a.orbit = t.orbit) AND ((a.subset)::text = (t.subset)::text)) AND ((a.sat_id)::text = (t.sat_id)::text)))) LEFT JOIN gvradar g ON ((((((a.overpass_time >= (g.nominal - '00:09:59'::interval)) AND (a.overpass_time <= (g.nominal + '00:09:59'::interval))) AND ((a.radar_id)::text = 'NPOL_WA'::text)) AND ((g.radar_id)::text = 'NPOL'::text)) AND ((g.product)::text ~~ '1CUF%'::text)))) WHERE ((a.radar_id)::text = 'NPOL_WA'::text);

-- 4/5/16, fixing Brazil radar elevations
update fixed_instrument_location set elevation=814 where instrument_id='AL1';
update fixed_instrument_location set elevation=102 where instrument_id='MC1';
update fixed_instrument_location set elevation=753 where instrument_id='JG1';
update fixed_instrument_location set elevation=78 where instrument_id='NT1';
update fixed_instrument_location set elevation=394 where instrument_id='PE1';
update fixed_instrument_location set elevation=730 where instrument_id='SF1';
update fixed_instrument_location set elevation=1009 where instrument_id='ST1';
update fixed_instrument_location set elevation=30 where instrument_id='SV1';
update fixed_instrument_location set elevation=936 where instrument_id='TM1';


-- 5/9/16 first set of Argentina radars
insert into instrument(instrument_id, instrument_type, instrument_name, owner, coverage_type, replaced_by_id) values ('INTA_Anguil','CPOL','Anguil','Argentina','radial scan PPI','NA');
insert into instrument(instrument_id, instrument_type, instrument_name, owner, coverage_type, replaced_by_id) values ('INTA_Parana','CPOL','Parana','Argentina','radial scan PPI','NA');
insert into instrument(instrument_id, instrument_type, instrument_name, owner, coverage_type, replaced_by_id) values ('INTA_Pergamino','CPOL','Pergamino','Argentina','radial scan PPI','NA');
insert into instrument(instrument_id, instrument_type, instrument_name, owner, coverage_type, replaced_by_id) values ('INTA_Cordoba','CPOL','Cordoba','Argentina','radial scan PPI','NA');
insert into instrument(instrument_id, instrument_type, instrument_name, owner, coverage_type, replaced_by_id) values ('INTA_Bariloche','CPOL','Bariloche','Argentina','radial scan PPI','NA');
insert into fixed_instrument_location values ('INTA_Anguil','2014-01-01','na','AR',-36.539722,-63.99,190)
insert into fixed_instrument_location values ('INTA_Parana','2014-01-01','na','AR',-31.8483,-60.5372,122);
insert into fixed_instrument_location values ('INTA_Cordoba','2014-01-01','na','AR',-31.4414,-64.1919,476);
insert into fixed_instrument_location values ('INTA_Pergamino','2014-01-01','na','AR',-33.9461,-60.5625,100);
insert into fixed_instrument_location values ('INTA_Bariloche','2014-01-01','na','AR',-41.1397,-71.1499,862);

-- 7/26/16, add productsubset and siteproductsubset entries for F19 and NPP satellites
-- by cloning GPM CONUS entries.  Only defines CONUS subset for these satellites.
select * into temp pstemp from productsubset where sat_id='GPM' and subset='CONUS';
update pstemp set sat_id='F19';
insert into productsubset select * from pstemp;
update pstemp set sat_id='NPP';
insert into productsubset select * from pstemp;
select * into temp spstemp from siteproductsubset where sat_id='GPM' and subset='CONUS';
update spstemp set sat_id='F19';
insert into siteproductsubset select * from spstemp;
update spstemp set sat_id='NPP';
insert into siteproductsubset select * from spstemp;

-- 08/05/16, new Australia subsets, already loaded radar IDs/locations
insert into productsubset values ('GPM', 'AUS-East');
insert into productsubset values ('GPM', 'AUS-West');
insert into productsubset values ('GPM', 'Tasmania');
insert into siteproductsubset select 'GPM', 'AUS-East', instrument_id from fixed_instrument_location where instrument_id like 'AU-%' and state_province not in ('WA','TA');
INSERT 0 42
insert into siteproductsubset select 'GPM', 'AUS-West', instrument_id from fixed_instrument_location where instrument_id like 'AU-%' and state_province  in ('WA');
INSERT 0 11
insert into siteproductsubset select 'GPM', 'Tasmania', instrument_id from fixed_instrument_location where instrument_id like 'AU-%' and state_province  in ('TA');
INSERT 0 3

-- DEFINE A NEW TABLE TO HOLD GPM ORBIT NUMBER AND START AND END DATETIMES
-- for script wget_orbdef_GPM.sh to populate.  8/19/16 addition
create table gpm_orbits(
  orbit INTEGER,
  starttime timestamp with time zone NOT NULL,
  endtime timestamp with time zone NOT NULL,
  PRIMARY KEY (orbit)
 );
GRANT SELECT, UPDATE, INSERT, DELETE on gpm_orbits to gvoper;


-- 8/29/2016 changes

-- change primary key of table rainy100inside100 from (sat_id, radar_id, orbit)
-- to event_num, as that is the attribute the table is always joined against,
-- and changel old PK constraint to a UNIQUE constraint
ALTER TABLE rainy100inside100 drop constraint rainy100inside100_pkey;
ALTER TABLE rainy100inside100 ADD PRIMARY KEY (event_num);
ALTER TABLE rainy100inside100 ADD UNIQUE(sat_id, radar_id, orbit);


-- add event_num to table geo_match_product
-- first, back the table up.  run from unix command line, not psql
-- pg_dump -t geo_match_product -f /data/tmp/geo_match_product.dump gpmgv

ALTER TABLE geo_match_product ADD COLUMN event_num INTEGER;
update geo_match_product set event_num =-99;

update geo_match_product set (event_num) = (overpass_event.event_num) from overpass_event where geo_match_product.sat_id = overpass_event.sat_id and geo_match_product.radar_id = overpass_event.radar_id and geo_match_product.orbit = overpass_event.orbit;

update geo_match_product set (event_num) = (overpass_event.event_num) from overpass_event where geo_match_product.sat_id = 'TRMM' and overpass_event.sat_id ='PR'  and geo_match_product.radar_id = overpass_event.radar_id and geo_match_product.orbit = overpass_event.orbit;

select count(*) from geo_match_product where event_num =-99;
delete from geo_match_product where event_num =-99;  -- a few CP2 matchups w/o overpass_event entries
ALTER TABLE geo_match_product ADD FOREIGN KEY(event_num) REFERENCES overpass_event(event_num);

ALTER TABLE geo_match_product ADD UNIQUE (event_num, instrument_id, scan_type, pps_version, parameter_set, geo_match_version);

---------------------------------------------------------------------------------------

-- 1/18/17 modifications to give user 'gvoper' privileges to administer baseline tables.
-- Backed up database and database schema to files /data/db_backup/gpmgvDBdump.18Jan17.gz
-- and /data/db_backup/dbschema.18Jan17.preChanges.dump before these modifications were
-- made.  Backed up database schema to /data/db_backup/dbschema.18Jan17.postChanges.dump
-- after modifying the permissions.

GRANT ALL ON TABLE appstatus TO gvoper;
GRANT ALL ON TABLE coincident_mosaic TO gvoper;
GRANT ALL ON TABLE overpass_event TO gvoper;
GRANT ALL ON TABLE siteproductsubset TO gvoper;
GRANT ALL ON TABLE collatecolswsub TO gvoper;
GRANT ALL ON SEQUENCE gvradar_fileidnum_seq TO gvoper;
GRANT ALL ON TABLE gvradar TO gvoper;
GRANT ALL ON TABLE orbit_subset_product TO gvoper;
GRANT ALL ON TABLE eventsatsubrad_vw TO gvoper;
GRANT ALL ON TABLE collatecols TO gvoper;
GRANT ALL ON TABLE collatedgvproducts TO gvoper;
GRANT ALL ON TABLE collatedmosaics TO gvoper;
GRANT ALL ON TABLE collatedmosaicswsub TO gvoper;
GRANT ALL ON TABLE ct_temp TO gvoper;
GRANT ALL ON TABLE ctstatus TO gvoper;
GRANT ALL ON TABLE dbzdiff_stats_by_angle TO gvoper;
GRANT ALL ON TABLE event_meta_numeric TO gvoper;
GRANT ALL ON TABLE event_meta_2a23_vw TO gvoper;
GRANT ALL ON TABLE event_meta_2a25_vw TO gvoper;
GRANT ALL ON TABLE fixed_instrument_location TO gvoper;
GRANT ALL ON TABLE geo_match_criteria TO gvoper;
GRANT ALL ON TABLE geo_match_parameters TO gvoper;
GRANT ALL ON TABLE geo_match_product TO gvoper;
GRANT ALL ON TABLE gpm_orbits TO gvoper;
GRANT ALL ON TABLE gvradar_fullpath TO gvoper;
GRANT ALL ON TABLE sweep_elev_list TO gvoper;
GRANT ALL ON TABLE volume_sweep_elev TO gvoper;
GRANT ALL ON TABLE gvradar_sweeps TO gvoper;
GRANT ALL ON TABLE gvradartemp TO gvoper;
GRANT ALL ON TABLE gvradarvolume TO gvoper;
GRANT ALL ON SEQUENCE gvradarvolume_volume_id_seq TO gvoper;
GRANT ALL ON TABLE gvradvol_temp TO gvoper;
GRANT ALL ON TABLE heldmosaic TO gvoper;
GRANT ALL ON TABLE instrument TO gvoper;
GRANT ALL ON TABLE instrument_hierarchy TO gvoper;
GRANT ALL ON TABLE lineage TO gvoper;
GRANT ALL ON TABLE maxmodelorbit TO gvoper;
GRANT ALL ON TABLE metadata_parameter TO gvoper;
GRANT ALL ON TABLE metadata_temp TO gvoper;
GRANT ALL ON TABLE missingmodelgrids TO gvoper;
GRANT ALL ON TABLE modelgrids TO gvoper;
GRANT ALL ON TABLE modelsoundings TO gvoper;
GRANT ALL ON SEQUENCE overpass_event_event_num_seq TO gvoper;
GRANT ALL ON TABLE ovlp25_w_rain25 TO gvoper;
GRANT ALL ON TABLE pr_angle_cat_text TO gvoper;
GRANT ALL ON TABLE productsubset TO gvoper;
GRANT ALL ON TABLE rainy100by2a53 TO gvoper;
GRANT ALL ON TABLE rainy100inside100 TO gvoper;
GRANT ALL ON TABLE rawradar TO gvoper;
GRANT ALL ON TABLE sat_instrument_algorithm TO gvoper;
GRANT ALL ON TABLE sitedbzsums TO gvoper;
GRANT ALL ON TABLE sweep_elevs TO gvoper;


-- 2/15/17 - remove foreign key constraint on geo_match_parameters(parameter_set)
--           from geo_match_product table

alter table geo_match_product drop constraint geo_match_product_parameter_set_fkey;


-- 2/16/17 modifications to give user 'gvoper' privileges to administer baseline VIEWs.

GRANT ALL ON TABLE collate_satsubprod_1cuf to gvoper;
GRANT ALL ON TABLE eventsatsubrad_vw to gvoper;
GRANT ALL ON TABLE collate_2a12_1cuf TO gvoper;
GRANT ALL ON TABLE collate_npol_md_1cuf TO gvoper;
GRANT ALL ON TABLE collate_npol_wa_1cuf TO gvoper;
GRANT ALL ON TABLE collate_sat_radar_overpass_1cuf TO gvoper;
GRANT ALL ON TABLE collate_satsubprod_1cuf TO gvoper;
GRANT ALL ON TABLE collate_satsubprod_1cuf_tmigprof TO gvoper;
GRANT ALL ON TABLE collatecols TO gvoper;
GRANT ALL ON TABLE collatecolswsub TO gvoper;
GRANT ALL ON TABLE collatecolswsub2 TO gvoper;
GRANT ALL ON TABLE collatedgvproducts TO gvoper;
GRANT ALL ON TABLE collatedgvproducts_kwajcal TO gvoper;
GRANT ALL ON TABLE collatedgvproducts_kwajcal1 TO gvoper;
GRANT ALL ON TABLE collatedgvproducts_kwajcal2 TO gvoper;
GRANT ALL ON TABLE collatedgvproducttype TO gvoper;
GRANT ALL ON TABLE collatedmosaics TO gvoper;
GRANT ALL ON TABLE collatedmosaicswsub TO gvoper;
GRANT ALL ON TABLE collatedprproductswsub TO gvoper;
GRANT ALL ON TABLE collatedprtotrmmproducts TO gvoper;
GRANT ALL ON TABLE dbzdiff_stats_merged TO gvoper;
GRANT ALL ON TABLE dbzdiff_stats_mergednewbb TO gvoper;
GRANT ALL ON TABLE event_meta_2a23_vw TO gvoper;
GRANT ALL ON TABLE event_meta_2a25_vw TO gvoper;
GRANT ALL ON TABLE eventsatsubrad_vw TO gvoper;
GRANT ALL ON TABLE gvradar_fullpath TO gvoper;
GRANT ALL ON TABLE gvradar_sweeps TO gvoper;
GRANT ALL ON TABLE rainy100by2a53 TO gvoper;


-- 2/28/17, Set up Role for 'wolff' on ds1-gpmgv

[morris@ds1-gpmgv tmp]$ createuser wolff
Shall the new role be a superuser? (y/n) n
Shall the new role be allowed to create databases? (y/n) n
Shall the new role be allowed to create more new roles? (y/n) n
[morris@ds1-gpmgv tmp]$ psql gpmgv

-- 2/28/17 modifications to give user 'public' privileges to query baseline VIEWs.

GRANT SELECT ON TABLE collate_satsubprod_1cuf to public;
GRANT SELECT ON TABLE eventsatsubrad_vw to public;
GRANT SELECT ON TABLE collate_2a12_1cuf TO public;
GRANT SELECT ON TABLE collate_npol_md_1cuf TO public;
GRANT SELECT ON TABLE collate_npol_wa_1cuf TO public;
GRANT SELECT ON TABLE collate_sat_radar_overpass_1cuf TO public;
GRANT SELECT ON TABLE collate_satsubprod_1cuf TO public;
GRANT SELECT ON TABLE collate_satsubprod_1cuf_tmigprof TO public;
GRANT SELECT ON TABLE collatecols TO public;
GRANT SELECT ON TABLE collatecolswsub TO public;
GRANT SELECT ON TABLE collatecolswsub2 TO public;
GRANT SELECT ON TABLE collatedgvproducts TO public;
GRANT SELECT ON TABLE collatedgvproducts_kwajcal TO public;
GRANT SELECT ON TABLE collatedgvproducts_kwajcal1 TO public;
GRANT SELECT ON TABLE collatedgvproducts_kwajcal2 TO public;
GRANT SELECT ON TABLE collatedgvproducttype TO public;
GRANT SELECT ON TABLE collatedmosaics TO public;
GRANT SELECT ON TABLE collatedmosaicswsub TO public;
GRANT SELECT ON TABLE collatedprproductswsub TO public;
GRANT SELECT ON TABLE collatedprtotrmmproducts TO public;
GRANT SELECT ON TABLE dbzdiff_stats_merged TO public;
GRANT SELECT ON TABLE dbzdiff_stats_mergednewbb TO public;
GRANT SELECT ON TABLE event_meta_2a23_vw TO public;
GRANT SELECT ON TABLE event_meta_2a25_vw TO public;
GRANT SELECT ON TABLE eventsatsubrad_vw TO public;
GRANT SELECT ON TABLE gvradar_fullpath TO public;
GRANT SELECT ON TABLE gvradar_sweeps TO public;
GRANT SELECT ON TABLE rainy100by2a53 TO public;

-- 5/8/17 additions to productsubset table to add all defined GPM subsets to constellation

select * into temp allprodsub from productsubset where sat_id='GPM';
select * from allprodsub;
 sat_id |    subset    
--------+--------------
 GPM    | AKradars
 GPM    | CONUS
 GPM    | DARW
 GPM    | KORA
 GPM    | KWAJ
 GPM    | KOREA
 GPM    | Guam
 GPM    | Hawaii
 GPM    | SanJuanPR
 GPM    | Brisbane
 GPM    | BrazilRadars
 GPM    | Finland
 GPM    | AUS-East
 GPM    | AUS-West
 GPM    | Tasmania
(15 rows)

-- query to find the GPM subsets not defined for another satellite
select 'F15' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F15' where b.subset is null;
 sat_id |  subset   
--------+-----------
 F15    | AKradars
 F15    | DARW
 F15    | Guam
 F15    | Hawaii
 F15    | SanJuanPR
 F15    | Brisbane
 F15    | AUS-East
 F15    | AUS-West
 F15    | Tasmania
(9 rows)

-- using above query, load undefined subsets into the productsubset table for each constellation satellite except TRMM
insert into productsubset select 'F15' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F15' where b.subset is null;
INSERT 0 9
insert into productsubset select 'F16' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F16' where b.subset is null;
INSERT 0 9
insert into productsubset select 'F17' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F17' where b.subset is null;
INSERT 0 9
insert into productsubset select 'F18' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F18' where b.subset is null;
INSERT 0 9
insert into productsubset select 'F19' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='F19' where b.subset is null;
INSERT 0 14
insert into productsubset select 'GCOMW1' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='GCOMW1' where b.subset is null;
INSERT 0 8
insert into productsubset select 'METOPA' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='METOPA' where b.subset is null;
INSERT 0 9
insert into productsubset select 'METOPB' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='METOPB' where b.subset is null;
INSERT 0 9
insert into productsubset select 'NOAA18' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='NOAA18' where b.subset is null;
INSERT 0 9
insert into productsubset select 'NOAA19' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='NOAA19' where b.subset is null;
INSERT 0 9
insert into productsubset select 'NPP' as sat_id, a.subset from allprodsub a left join productsubset b on a.subset=b.subset and b.sat_id='NPP' where b.subset is null;
INSERT 0 10


-- 10/10/17 - adding Aus-East/West TRMM subsets to configuration for v8 data
--            Overkill, do both 'TRMM' and 'PR' sat_id values
gpmgv=> insert into productsubset values ('TRMM','AUS-East');
INSERT 0 1
gpmgv=> insert into productsubset values ('TRMM','AUS-West');
INSERT 0 1
gpmgv=> insert into productsubset values ('PR','AUS-East');
INSERT 0 1
gpmgv=> insert into productsubset values ('PR','AUS-West');
INSERT 0 1

gpmgv=> select * into temp aueast from siteproductsubset where sat_id='GPM' and subset='AUS-East';
SELECT
gpmgv=> update aueast set sat_id = 'TRMM';
UPDATE 42
gpmgv=> insert into siteproductsubset select * from aueast;
INSERT 0 42
gpmgv=> select * into temp auwest from siteproductsubset where sat_id='GPM' and subset='AUS-West';
SELECT
gpmgv=> update auwest set sat_id = 'TRMM';
UPDATE 11
gpmgv=> insert into siteproductsubset select * from auwest;
INSERT 0 11
gpmgv=> update aueast set sat_id = 'PR';
UPDATE 42
gpmgv=> insert into siteproductsubset select * from aueast;
INSERT 0 42
gpmgv=> update auwest set sat_id = 'PR';
UPDATE 11
gpmgv=> insert into siteproductsubset select * from auwest;
INSERT 0 11

-- 10/19/17 - adding the VIEW collatedPRv8products to collate TRMM version 8 2APR products
-- stored under sat_id 'TRMM' to overpass events cataloged under sat_id 'PR'

create view collatedPRv8products as
 SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, i.version, i.filename as file2apr
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product i ON a.orbit = i.orbit AND a.subset = i.subset AND a.sat_id = 'PR' AND i.sat_id = 'TRMM' AND i.product_type = '2APR';

GRANT ALL ON TABLE collatedPRv8products TO gvoper;
GRANT SELECT ON TABLE collatedPRv8products TO public;


-- 11/8/2017, Morris
-- Add the Reunion subset for the Reunion radar, for all satellites.  Todd already
-- defined 'Reunion' in the instrument and fixed_instrument_location tables.

-- First, populate the productsubset table.  Just clone from CONUS subset. 
-- Exclude PR and GMI entries, which are not actual satellite IDs

gpmgv=> select * into temp reunion_temp1 from productsubset where subset='CONUS' and sat_id not in ('PR','GMI');
SELECT
gpmgv=> update reunion_temp1 set subset='Reunion';
UPDATE 13
gpmgv=> select * from reunion_temp1;
 sat_id | subset  
--------+---------
 TRMM   | Reunion
 GPM    | Reunion
 GCOMW1 | Reunion
 F15    | Reunion
 F16    | Reunion
 F17    | Reunion
 F18    | Reunion
 METOPA | Reunion
 NOAA18 | Reunion
 NOAA19 | Reunion
 METOPB | Reunion
 F19    | Reunion
 NPP    | Reunion
(13 rows)

-- Now do siteproductsubset entries.  Note that both the subset and the radar_id
-- values should be 'Reunion', so grab the subset column a 2nd time as the radar_id

gpmgv=> select *, subset as radar_id into temp reunion_temp2 from productsubset where subset='Reunion';
SELECT
gpmgv=> select * from reunion_temp2;
 sat_id | subset  | radar_id 
--------+---------+----------
 TRMM   | Reunion | Reunion
 GPM    | Reunion | Reunion
 GCOMW1 | Reunion | Reunion
 F15    | Reunion | Reunion
 F16    | Reunion | Reunion
 F17    | Reunion | Reunion
 F18    | Reunion | Reunion
 METOPA | Reunion | Reunion
 NOAA18 | Reunion | Reunion
 NOAA19 | Reunion | Reunion
 METOPB | Reunion | Reunion
 F19    | Reunion | Reunion
 NPP    | Reunion | Reunion
(13 rows)

gpmgv=> insert into siteproductsubset select * from reunion_temp2;
INSERT 0 13

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

-- 01/11/18, Morris
-- get rid of duplicate TRMM products in orbit_subset_product table
-- having both legacy and GPM-era filenames/subsets

-- first, get rid of all products with the unused KORA subset - check the orbit ranges
-- of KORA and KOREA to make sure KOREA covers the orbits where we had KORA

gpmgv=> select sat_id, product_type, subset, min(orbit), max(orbit) from orbit_subset_product where subset in ('KORA','KOREA') group by 1,2,3 order by 1, 2,3;
 sat_id | product_type | subset |  min  |  max  
--------+--------------+--------+-------+-------
 F16    | 2AGPROF      | KORA   | 53468 | 54358
 F16    | 2AGPROF      | KOREA  | 48771 | 73419
 F17    | 2AGPROF      | KORA   | 37750 | 38704
 F17    | 2AGPROF      | KOREA  | 33052 | 57703
 F18    | 2AGPROF      | KORA   | 22532 | 23372
 F18    | 2AGPROF      | KOREA  | 17802 | 42437
 F19    | 2AGPROF      | KOREA  |  3665 |  9593
 GCOMW1 | 2AGPROF      | KORA   |  9497 | 10458
 GCOMW1 | 2AGPROF      | KOREA  |  4648 | 30045
 GPM    | 1CRXCAL      | KOREA  |    79 | 21991
 GPM    | 2ADPR        | KORA   |   165 |  1078
 GPM    | 2ADPR        | KOREA  |   150 | 21981
 GPM    | 2AGPROF      | KORA   |    88 |  1057
 GPM    | 2AGPROF      | KOREA  |    79 | 21966
 GPM    | 2AKa         | KORA   |   165 |  1078
 GPM    | 2AKa         | KOREA  |   150 | 21981
 GPM    | 2AKu         | KORA   |   165 |  1078
 GPM    | 2AKu         | KOREA  |   150 | 21981
 GPM    | 2BDPRGMI     | KORA   |   165 |  1072
 GPM    | 2BDPRGMI     | KOREA  |   150 | 21981
 METOPA | 2AGPROF      | KOREA  | 33461 | 58245
 METOPB | 2AGPROF      | KOREA  |  3101 | 27559
 NOAA18 | 2AGPROF      | KOREA  | 40519 | 65143
 NOAA19 | 2AGPROF      | KOREA  | 21362 | 45981
 NPP    | 2AGPROF      | KOREA  | 11729 | 32139
 TRMM   | 1C21         | KORA   | 92858 | 93836
 TRMM   | 1C21         | KOREA  | 92796 | 98987
 TRMM   | 2A12         | KORA   | 92857 | 93836
 TRMM   | 2A12         | KOREA  | 92796 | 99096
 TRMM   | 2A23         | KORA   | 92858 | 93836
 TRMM   | 2A23         | KOREA  | 92796 | 98987
 TRMM   | 2A25         | KORA   | 92858 | 93836
 TRMM   | 2A25         | KOREA  | 92796 | 98987
 TRMM   | 2AGPROF      | KORA   | 92766 | 93821
 TRMM   | 2AGPROF      | KOREA  | 92353 | 99096
 TRMM   | 2B31         | KORA   | 92858 | 93836
 TRMM   | 2B31         | KOREA  | 92796 | 98987

-- check the versions of KORA subsets to make sure we don't need any of them. 
-- V07 is TRMM, but the above result shows we have KOREA for the KORA orbits.
gpmgv=> select distinct(version) from orbit_subset_product where subset='KORA';
 version 
---------
 V01E
 V07
 V01B
 V01D
 V01A
 V01F
(6 rows)

-- now delete the KORA rows
gpmgv=> delete from orbit_subset_product where subset='KORA';
DELETE 1843

-- find the earliest orbit with GPM-era filenames, cataloged with sat_id=TRMM and version=V07
gpmgv=> select min(orbit) from orbit_subset_product where sat_id='TRMM' and version = 'V07';
  min  
-------
 92786
(1 row)

-- get a summary of TRMM products following the beginning of the GPM-era.  These are either tagged
-- as version '7' or 'V07'

gpmgv=> select sat_id,product_type,subset,version,count(*) from orbit_subset_product where orbit>92785 and version like '%7' group by 1,2,3,4 order by 2,1,3,4;
 sat_id | product_type |   subset   | version | count 
--------+--------------+------------+---------+-------
 PR     | 1C21         | GPM_KMA    | 7       |    45
 PR     | 1C21         | sub-GPMGV1 | 7       |    75
 TRMM   | 1C21         | CONUS      | V07     |  1890
 TRMM   | 1C21         | DARW       | V07     |   313
 TRMM   | 1C21         | KOREA      | V07     |   907
 TRMM   | 1C21         | KWAJ       | V07     |   300
 TMI    | 2A12         | sub-GPMGV1 | 7       |    75
 TRMM   | 2A12         | CONUS      | V07     |  2994
 TRMM   | 2A12         | DARW       | V07     |   741
 TRMM   | 2A12         | KOREA      | V07     |  1607
 TRMM   | 2A12         | KWAJ       | V07     |   706
 PR     | 2A23         | GPM_KMA    | 7       |    45
 PR     | 2A23         | sub-GPMGV1 | 7       |    75
 TRMM   | 2A23         | CONUS      | V07     |  1890
 TRMM   | 2A23         | DARW       | V07     |   313
 TRMM   | 2A23         | KOREA      | V07     |   907
 TRMM   | 2A23         | KWAJ       | V07     |   300
 PR     | 2A25         | GPM_KMA    | 7       |    45
 PR     | 2A25         | sub-GPMGV1 | 7       |    75
 TRMM   | 2A25         | CONUS      | V07     |  1890
 TRMM   | 2A25         | DARW       | V07     |   313
 TRMM   | 2A25         | KOREA      | V07     |   907
 TRMM   | 2A25         | KWAJ       | V07     |   300
 PR     | 2B31         | GPM_KMA    | 7       |    45
 PR     | 2B31         | sub-GPMGV1 | 7       |    75
 TRMM   | 2B31         | CONUS      | V07     |  1890
 TRMM   | 2B31         | DARW       | V07     |   313
 TRMM   | 2B31         | KOREA      | V07     |   907
 TRMM   | 2B31         | KWAJ       | V07     |   300
(29 rows)

-- Noting that GPM_KMA (KOREA) is the Korean subset ID for legacy version 7 (GPM-era version V07), and
-- sub-GPMGV1 (CONUS) is the continental US subset ID for legacy version 7 (GPM-era version V07),
-- find the duplicate legacy products tagged with the satellite ID of 'PR'

-- First, for the CONUS, grab a sample of 20 duplicate products:

gpmgv=> select a.orbit, a.product_type as prod, a.sat_id as prsat, a.filename as prname, b.sat_id as trmmsat, b.filename as trmmname from orbit_subset_product a, orbit_subset_product b where a.sat_id='PR' and b.sat_id='TRMM' and a.orbit=b.orbit and a.product_type=b.product_type and a.subset='sub-GPMGV1' and b.subset='CONUS' and a.orbit>92785 and a.product_type in ('1C21','2A12', '2A23','2A25','2B31') order by 1,2 limit 20;
 orbit | prod | prsat |                 prname                  | trmmsat |                              trmmname                               
-------+------+-------+-----------------------------------------+---------+---------------------------------------------------------------------
 92789 | 1C21 | PR    | 1C21.20140301.92789.7.sub-GPMGV1.hdf.gz | TRMM    | 1C-CS-CONUS.TRMM.PR.1C21.20140301-S061444-E061931.092789.7.HDF.gz
 92789 | 2A23 | PR    | 2A23.20140301.92789.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A23.20140301-S061444-E061931.092789.7.HDF.gz
 92789 | 2A25 | PR    | 2A25.20140301.92789.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A25.20140301-S061444-E061931.092789.7.HDF.gz
 92789 | 2B31 | PR    | 2B31.20140301.92789.7.sub-GPMGV1.hdf.gz | TRMM    | 2B-CS-CONUS.TRMM.COMB.2B31.20140301-S061444-E061931.092789.7.HDF.gz
 92790 | 1C21 | PR    | 1C21.20140301.92790.7.sub-GPMGV1.hdf.gz | TRMM    | 1C-CS-CONUS.TRMM.PR.1C21.20140301-S074708-E075725.092790.7.HDF.gz
 92790 | 2A23 | PR    | 2A23.20140301.92790.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A23.20140301-S074708-E075725.092790.7.HDF.gz
 92790 | 2A25 | PR    | 2A25.20140301.92790.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A25.20140301-S074708-E075725.092790.7.HDF.gz
 92790 | 2B31 | PR    | 2B31.20140301.92790.7.sub-GPMGV1.hdf.gz | TRMM    | 2B-CS-CONUS.TRMM.COMB.2B31.20140301-S074708-E075725.092790.7.HDF.gz
 92791 | 1C21 | PR    | 1C21.20140301.92791.7.sub-GPMGV1.hdf.gz | TRMM    | 1C-CS-CONUS.TRMM.PR.1C21.20140301-S092039-E093506.092791.7.HDF.gz
 92791 | 2A23 | PR    | 2A23.20140301.92791.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A23.20140301-S092039-E093506.092791.7.HDF.gz
 92791 | 2A25 | PR    | 2A25.20140301.92791.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A25.20140301-S092039-E093506.092791.7.HDF.gz
 92791 | 2B31 | PR    | 2B31.20140301.92791.7.sub-GPMGV1.hdf.gz | TRMM    | 2B-CS-CONUS.TRMM.COMB.2B31.20140301-S092039-E093506.092791.7.HDF.gz
 92792 | 1C21 | PR    | 1C21.20140301.92792.7.sub-GPMGV1.hdf.gz | TRMM    | 1C-CS-CONUS.TRMM.PR.1C21.20140301-S105909-E111312.092792.7.HDF.gz
 92792 | 2A23 | PR    | 2A23.20140301.92792.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A23.20140301-S105909-E111312.092792.7.HDF.gz
 92792 | 2A25 | PR    | 2A25.20140301.92792.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A25.20140301-S105909-E111312.092792.7.HDF.gz
 92792 | 2B31 | PR    | 2B31.20140301.92792.7.sub-GPMGV1.hdf.gz | TRMM    | 2B-CS-CONUS.TRMM.COMB.2B31.20140301-S105909-E111312.092792.7.HDF.gz
 92793 | 1C21 | PR    | 1C21.20140301.92793.7.sub-GPMGV1.hdf.gz | TRMM    | 1C-CS-CONUS.TRMM.PR.1C21.20140301-S123657-E124936.092793.7.HDF.gz
 92793 | 2A23 | PR    | 2A23.20140301.92793.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A23.20140301-S123657-E124936.092793.7.HDF.gz
 92793 | 2A25 | PR    | 2A25.20140301.92793.7.sub-GPMGV1.hdf.gz | TRMM    | 2A-CS-CONUS.TRMM.PR.2A25.20140301-S123657-E124936.092793.7.HDF.gz
 92793 | 2B31 | PR    | 2B31.20140301.92793.7.sub-GPMGV1.hdf.gz | TRMM    | 2B-CS-CONUS.TRMM.COMB.2B31.20140301-S123657-E124936.092793.7.HDF.gz
(20 rows)

-- Now let's get a listing of all the duplicate legacy sub-GPMGV1 products and store to a temp table:

gpmgv=> select a.filename as prname into temp prduptemp from orbit_subset_product a, orbit_subset_product b where a.sat_id='PR' and b.sat_id='TRMM' and a.orbit=b.orbit and a.product_type=b.product_type and a.subset='sub-GPMGV1' and b.subset='CONUS' and a.orbit>92785 and a.product_type in ('1C21','2A12', '2A23','2A25','2B31');
SELECT
gpmgv=> select count(*) from prduptemp;
 count 
-------
   300
(1 row)

-- Copy the rows for all the products to be deleted into a new table:
gpmgv=> select a.* into deleted_orb_sub_prod from orbit_subset_product a, prduptemp b where a.filename=b.prname;
SELECT
gpmgv=> select count(*) from deleted_orb_sub_prod;
 count 
-------
   300
(1 row)

-- delete the entries for the 'duplicate' products
gpmgv=> delete from orbit_subset_product where filename in (select prname from prduptemp);
DELETE 300

-- Now repeat the above for duplicates between GPM_KMA and KOREA
drop table prduptemp;

select a.orbit, a.product_type as prod, a.sat_id as prsat, a.filename as prname, b.sat_id as trmmsat, b.filename as trmmname from orbit_subset_product a, orbit_subset_product b where a.sat_id='PR' and b.sat_id='TRMM' and a.orbit=b.orbit and a.product_type=b.product_type and a.subset='GPM_KMA' and b.subset='KOREA' and a.orbit>92785 and a.product_type in ('1C21','2A12', '2A23','2A25','2B31') order by 1,2 limit 20;
 orbit | prod | prsat |                prname                | trmmsat |                              trmmname                               
-------+------+-------+--------------------------------------+---------+---------------------------------------------------------------------
 92797 | 1C21 | PR    | 1C21.20140301.92797.7.GPM_KMA.hdf.gz | TRMM    | 1C-CS-KOREA.TRMM.PR.1C21.20140301-S184230-E184516.092797.7.HDF.gz
 92797 | 2A23 | PR    | 2A23.20140301.92797.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A23.20140301-S184230-E184516.092797.7.HDF.gz
 92797 | 2A25 | PR    | 2A25.20140301.92797.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A25.20140301-S184230-E184516.092797.7.HDF.gz
 92797 | 2B31 | PR    | 2B31.20140301.92797.7.GPM_KMA.hdf.gz | TRMM    | 2B-CS-KOREA.TRMM.COMB.2B31.20140301-S184230-E184516.092797.7.HDF.gz
 92798 | 1C21 | PR    | 1C21.20140301.92798.7.GPM_KMA.hdf.gz | TRMM    | 1C-CS-KOREA.TRMM.PR.1C21.20140301-S202012-E202259.092798.7.HDF.gz
 92798 | 2A23 | PR    | 2A23.20140301.92798.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A23.20140301-S202012-E202259.092798.7.HDF.gz
 92798 | 2A25 | PR    | 2A25.20140301.92798.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A25.20140301-S202012-E202259.092798.7.HDF.gz
 92798 | 2B31 | PR    | 2B31.20140301.92798.7.GPM_KMA.hdf.gz | TRMM    | 2B-CS-KOREA.TRMM.COMB.2B31.20140301-S202012-E202259.092798.7.HDF.gz
 92812 | 1C21 | PR    | 1C21.20140302.92812.7.GPM_KMA.hdf.gz | TRMM    | 1C-CS-KOREA.TRMM.PR.1C21.20140302-S174648-E174939.092812.7.HDF.gz
 92812 | 2A23 | PR    | 2A23.20140302.92812.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A23.20140302-S174648-E174939.092812.7.HDF.gz
 92812 | 2A25 | PR    | 2A25.20140302.92812.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A25.20140302-S174648-E174939.092812.7.HDF.gz
 92812 | 2B31 | PR    | 2B31.20140302.92812.7.GPM_KMA.hdf.gz | TRMM    | 2B-CS-KOREA.TRMM.COMB.2B31.20140302-S174648-E174939.092812.7.HDF.gz
 92813 | 1C21 | PR    | 1C21.20140302.92813.7.GPM_KMA.hdf.gz | TRMM    | 1C-CS-KOREA.TRMM.PR.1C21.20140302-S192436-E192718.092813.7.HDF.gz
 92813 | 2A23 | PR    | 2A23.20140302.92813.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A23.20140302-S192436-E192718.092813.7.HDF.gz
 92813 | 2A25 | PR    | 2A25.20140302.92813.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A25.20140302-S192436-E192718.092813.7.HDF.gz
 92813 | 2B31 | PR    | 2B31.20140302.92813.7.GPM_KMA.hdf.gz | TRMM    | 2B-CS-KOREA.TRMM.COMB.2B31.20140302-S192436-E192718.092813.7.HDF.gz
 92814 | 1C21 | PR    | 1C21.20140302.92814.7.GPM_KMA.hdf.gz | TRMM    | 1C-CS-KOREA.TRMM.PR.1C21.20140302-S210215-E210511.092814.7.HDF.gz
 92814 | 2A23 | PR    | 2A23.20140302.92814.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A23.20140302-S210215-E210511.092814.7.HDF.gz
 92814 | 2A25 | PR    | 2A25.20140302.92814.7.GPM_KMA.hdf.gz | TRMM    | 2A-CS-KOREA.TRMM.PR.2A25.20140302-S210215-E210511.092814.7.HDF.gz
 92814 | 2B31 | PR    | 2B31.20140302.92814.7.GPM_KMA.hdf.gz | TRMM    | 2B-CS-KOREA.TRMM.COMB.2B31.20140302-S210215-E210511.092814.7.HDF.gz
(20 rows)

gpmgv=> select a.filename as prname into temp prduptemp from orbit_subset_product a, orbit_subset_product b where a.sat_id='PR' and b.sat_id='TRMM' and a.orbit=b.orbit and a.product_type=b.product_type and a.subset='GPM_KMA' and b.subset='KOREA' and a.orbit>92785 and a.product_type in ('1C21','2A12', '2A23','2A25','2B31');
SELECT
gpmgv=> select count(*) from prduptemp;
 count 
-------
   180
(1 row)

-- Copy the rows for all the products to be deleted into the new table.
-- Note that we created the deleted_orb_sub_prod table in the CONUS steps, now we have to INSERT new rows into it:

gpmgv=> INSERT INTO deleted_orb_sub_prod SELECT a.* from orbit_subset_product a, prduptemp b where a.filename=b.prname;
INSERT 0 180
gpmgv=> select count(*) from deleted_orb_sub_prod;
 count 
-------
   480
(1 row)

-- delete the entries for the 'duplicate' products
gpmgv=> delete from orbit_subset_product where filename in (select prname from prduptemp);
DELETE 180

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

-- 1/16/17  Morris/GPM GV - change sat_id entries of 'PR' to 'TRMM' in tables rainy100inside100,
-- orbit_subset_product, overpass_event

gpmgv=> UPDATE rainy100inside100 set sat_id='TRMM' where sat_id='PR';
UPDATE 10555
gpmgv=> update orbit_subset_product  set sat_id='TRMM' where sat_id='PR';
UPDATE 158573
gpmgv=> update overpass_event set sat_id='TRMM' where sat_id='PR';
UPDATE 138195

-- grant gvoper permissions for miscellaneous/ancillary
-- tables so that backup can proceed witout errors - Morris, 7/5/18

GRANT ALL ON maxmodelorbit TO gvoper;
GRANT ALL ON sweep_elev_list TO gvoper;
GRANT ALL ON sweep_elev_list_list_id_seq TO gvoper;
GRANT ALL ON deleted_orb_sub_prod TO gvoper;
GRANT ALL ON newinstrument TO gvoper;
GRANT ALL ON event_meta_numeric_copy TO gvoper;
GRANT ALL ON geo_match_product_dups TO gvoper;
GRANT ALL ON surface_type TO gvoper;
GRANT ALL ON rain_by_orbit_swath TO gvoper;
GRANT ALL ON modelresort TO gvoper;
GRANT ALL ON metaorbitstemp TO gvoper;
GRANT ALL ON km_le_100_w_rain10 TO gvoper;
GRANT ALL ON gvradartimeupd TO gvoper;
GRANT ALL ON gvradartimeupd TO gvoper;
GRANT ALL ON gvradarnewtimes TO gvoper;
GRANT ALL ON eventnum_fileidnum TO gvoper;
GRANT ALL ON dualpol_active TO gvoper;

-- drop my various 'diff' tables/views for same reason as above
DROP VIEW  dbzdiff_stats_merged        ;
DROP VIEW  dbzdiff_stats_mergednewbb   ;
DROP TABLE  zdiff_stats_2aku_v4_s2ku   ;
DROP TABLE  zdiff_stats_2aku_v5_s2ku   ;
DROP TABLE  zdiff_stats_dpr_v4         ;
DROP TABLE  zdiff_stats_dpr_v4_s2ku    ;
DROP TABLE  zdiff_stats_dpr_v5         ;
DROP TABLE  zdiff_stats_dpr_v5_s2ku    ;
DROP TABLE  dbzdiff_stats_default      ;
DROP TABLE  dbzdiff_stats_defaultnewbb ;
DROP TABLE  dbzdiff_stats_prrawcor     ;
DROP TABLE  dbzdiff_stats_prrawcornewbb;
DROP TABLE  dbzdiff_stats_s2ku         ;
DROP TABLE  dbzdiff_stats_s2kunewbb    ;

-- 7/6/18 - redefine VIEW collatedPRv8products to collate TRMM version 8 2APR products
-- stored under sat_id 'TRMM' to overpass events now cataloged under sat_id 'TRMM'

DROP VIEW collatedPRv8products;

create view collatedPRv8products as
 SELECT a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, i.version, i.filename as file2apr
   FROM eventsatsubrad_vw a
   LEFT JOIN orbit_subset_product i ON a.orbit = i.orbit AND a.subset = i.subset AND a.sat_id = i.sat_id AND i.sat_id = 'TRMM' AND i.product_type = '2APR';

GRANT ALL ON TABLE collatedPRv8products TO gvoper;
GRANT SELECT ON TABLE collatedPRv8products TO public;

