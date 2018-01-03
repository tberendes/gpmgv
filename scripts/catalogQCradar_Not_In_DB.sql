--
-- Load metadata for what the script thinks are 'new' files into
-- existing table gvradartemp
--
\copy gvradartemp from '/data/tmp/finalQC_KxxxMeta.unl' WITH DELIMITER '|'
select product, count(*) from gvradartemp group by 1 order by 1;
--
-- Find any 'new' files that may have already been cataloged, store these
-- duplicate filenames in true temporary table gvradardups
--
select a.filename into temp gvradardups
  from gvradar a, gvradartemp b 
 where a.filename=b.filename;
--
-- Load metadata for truly-new filenames into permanent table gvradar
-- - modified to explicitly list the table columns, pending addition of
--   a new SERIAL column to the 'gvradar' table - 01/26/2011
--
insert into gvradar ( product, radar_id, nominal, filepath, filename )
 select * from gvradartemp 
  where filename not in (select filename from gvradardups);

--select distinct filename, count(*) from newgvtoload group by 1 order by 2,1;
--
-- LIST OF ANY DUPLICATE FILES THAT WERE ERRONEOUSLY IDENTIFIED AS "NEW":
--
select count(*) from gvradardups;
--
-- Clean up
--
drop table gvradardups;
delete from gvradartemp;
