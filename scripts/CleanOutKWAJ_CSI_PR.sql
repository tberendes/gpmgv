-- runs under psql, called from CleanOutKWAJ_CSI_PR.sh, change only the date in the list-of-orbits SELECT

-- Here is the query to be run manually to find the latest date for which PR processing is complete
-- for KWAJ, assuming doMissingMetadata_wSub.sh has been run.  Do NOT uncomment it:

--select date(a.overpass_time at time zone 'UTC') as latest_date, a.* from overpass_event a, event_meta_numeric b where a.event_num=b.event_num and a.radar_id='KWAJ' and b.metadata_id = 250999 order by event_num desc limit 10;

------------------------------------------------------------------------------------

-- BEGINNING OF QUERIES FOR EXECUTION UNDER CleanOutKWAJ_CSI_PR.sh:

-- drop existing table kwaj_pr_to_rm
drop table kwaj_pr_to_rm;

-- get a list of orbits for which we have KWAJ PR subsets
 -- EDIT THE DATE BASED ON THE 'latest date' MANUAL QUERY RESULT
select distinct orbit, subset into temp temp1 from orbit_subset_product where subset='KWAJ' and filedate < '2014-01-20' order by 1;

-- join this with collatecolswsub to find those KWAJ subsets/orbits
--   with and without matching overpass events (table has null value for 2nd
--   orbit column if no overpass event -- csi_orbit is orbit from query above)
select b.orbit as csi_orbit, b.subset as csi_subset, a.* into temp kwaj_collated from temp1 b left join collatecolswsub a on  a.subset=b.subset and a.orbit=b.orbit;

-- store a list of KWAJ orbit_subset_product files and orbits without matching
--   overpass_event entries in table kwaj_pr_to_rm.  The script will walk
--   through this list and delete the PR subset files so indicated
select product_type||'/'||filename as prfiledir, csi_orbit, sat_id, a.csi_subset, product_type into kwaj_pr_to_rm from kwaj_collated a, orbit_subset_product b where a.csi_orbit=b.orbit and a.csi_subset=b.subset and a.orbit is null;

-- need an SQL command to delete the matching rows from orbit_subset_product
--   table after their files have been deleted

--delete from orbit_subset_product where exists (select * from kwaj_pr_to_rm where kwaj_pr_to_rm.csi_orbit=orbit_subset_product.orbit and kwaj_pr_to_rm.sat_id = orbit_subset_product.sat_id and kwaj_pr_to_rm.product_type = orbit_subset_product.product_type and kwaj_pr_to_rm.csi_subset = orbit_subset_product.subset);
