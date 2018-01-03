--
-- Create empty temp table from orbit_subset_product
--
select * into temp orbsubprod_temp from orbit_subset_product limit 1;
delete from orbsubprod_temp;
--
-- Load metadata for what the script thinks are 'new' files into
-- temp table
--
--\copy orbsubprod_temp from '/data/tmp/catalogPRdbtemp.unl' WITH DELIMITER '|'
\copy orbsubprod_temp from '/data/gpmgv/prsubsets/catalogPRdbtemp.unl' WITH DELIMITER '|'
select count(*) from orbsubprod_temp;
--
-- Find any 'new' files that may have already been cataloged, according to their
-- Primary Key attributes, and store these duplicate items in true temporary
-- table orbsubprod_dups
--
select b.filename into temp orbsubprod_dups
  from orbit_subset_product a, orbsubprod_temp b 
 where a.sat_id=b.sat_id and a.orbit=b.orbit
   and a.product_type=b.product_type and a.subset=b.subset
   and a.version=b.version;
select count(*) from orbsubprod_dups;
--
-- Find any duplicate filenames between the temp table and the permanent table
insert into orbsubprod_dups
 select a.filename from orbit_subset_product a, orbsubprod_temp b 
 where a.filename=b.filename;
--
-- Load metadata for truly-new filenames into permanent table orbit_subset_product
--
insert into orbit_subset_product
 select * from orbsubprod_temp 
  where filename not in (select distinct filename from orbsubprod_dups);
--
-- LIST OF ANY DUPLICATE FILES THAT WERE ERRONEOUSLY IDENTIFIED AS "NEW":
--
select distinct filename from orbsubprod_dups order by 1;
--
-- Clean up
--
drop table orbsubprod_dups;
drop table orbsubprod_temp;
