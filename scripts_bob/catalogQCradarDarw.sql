--
-- Load metadata for what the script thinks are 'new' files into
-- existing table gvradartemp
--
\copy gvradartemp from '/data/tmp/finalQC_DarwMeta.unl' WITH DELIMITER '|'
--
-- Find any 'new' files that may have already been cataloged, store these
-- duplicate filenames in true temporary table gvradardups
--
select a.filename into temp gvradardups
  from gvradar a, gvradartemp b 
 where a.filename=b.filename;
--
-- Load metadata for truly-new filenames into permanent table gvradar
--
insert into gvradar 
 select * from gvradartemp 
  where filename not in (select filename from gvradardups);
--
-- LIST OF ANY DUPLICATE FILES THAT WERE ERRONEOUSLY IDENTIFIED AS "NEW":
--
select * from gvradardups;
--
-- Clean up
--
drop table gvradardups;
delete from gvradartemp;
