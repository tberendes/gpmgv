--
-- Load metadata for what the script thinks are 'new' files into
-- existing table gvradartemp
--
\copy gvradartemp from '/data/gpmgv/tmp/defaultQC_KxxxMeta.unl' WITH DELIMITER '|'
--
select count(*) from gvradartemp;
--
-- Tag any 'new' files that may have already been cataloged, store the
-- data for 'new' and 'duplicate' filenames in true temporary table gvradardups
--
select b.*, a.filename as dupname into temp gvradardups
  from gvradartemp b left outer join rawradar a on a.filename=b.filename;
--
-- Load metadata for truly-new filenames into permanent table rawradar
--
insert into rawradar ( product, radar_id, nominal, filepath, filename )
 select product, radar_id, nominal, filepath, filename from gvradardups
  where dupname is null;
--
-- PROPOSED 'NEW' FILES THAT ARE ALREADY PRESENT IN DATABASE:
--
select count(*) from gvradardups where dupname is not null;
--
-- Clean up
--
drop table gvradardups;
delete from gvradartemp;
