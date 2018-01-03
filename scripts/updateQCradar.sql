--
-- Load metadata for what the script thinks are 'new' files into
-- existing table gvradartemp
--
\copy gvradartemp from '/data/gpmgv/tmp/finalQC_KxxxMeta.unl' WITH DELIMITER '|'
--
-- Find any 'new' files that may have already been cataloged, store these
-- duplicate filenames in true temporary table gvradardups
--
select a.filename, b.nominal into temp gvradardups
  from gvradar a, gvradartemp b 
 where a.filename=b.filename;
--
-- Update metadata for duplicate filenames in permanent table gvradar
--
update gvradar set nominal = gvradardups.nominal FROM gvradardups
 where gvradar.filename = gvradardups.filename;
--
-- LIST OF ALL DUPLICATE FILES:
--
select * from gvradardups;
--
-- Clean up
--
drop table gvradardups;
delete from gvradartemp;
