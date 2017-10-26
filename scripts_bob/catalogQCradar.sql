--
-- Load metadata for what the script thinks are 'new' files into
-- existing table gvradartemp
--
\copy gvradartemp from '/data/tmp/finalQC_KxxxMeta.unl' WITH DELIMITER '|'
--
select product, count(*) from gvradartemp group by 1 order by 1;
--
-- Tag any 'new' files that are already cataloged, store these
-- duplicate filenames and true "new" data in temporary table gvradardups
--
select b.*, a.filename as dupname into temp gvradardups
  from gvradartemp b left outer join gvradar a on a.filename=b.filename;
--
-- Load metadata for truly-new filenames into permanent table gvradar
--
insert into gvradar ( product, radar_id, nominal, filepath, filename )
 select product, radar_id, nominal, filepath, filename from gvradardups
  where dupname is null;
--
-- PROPOSED 'NEW' FILES THAT ARE ALREADY PRESENT IN DATABASE:
--
select product, count(*) from gvradardups where dupname is not null
 group by 1 order by 1;
--
-- Clean up
--
drop table gvradardups;
delete from gvradartemp;
