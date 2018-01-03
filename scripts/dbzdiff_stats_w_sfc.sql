gpmgv=# \d dbzdiff_stats_w_sfc
       Table "public.dbzdiff_stats_w_sfc"
   Column   |         Type          | Modifiers
------------+-----------------------+-----------
 landtype   | character varying(10) | not null
 gvtype     | character(4)          | not null
 regime     | character varying(10) | not null
 radar_id   | character varying(15) | not null
 orbit      | integer               | not null
 height     | double precision      | not null
 meandiff   | double precision      |
 diffstddev | double precision      |
 prmax      | double precision      |
 gvmax      | double precision      |
 prmean     | double precision      |
 gvmean     | double precision      |
 numpts     | integer               |
Indexes:
    "dbzdiff_stats_w_sfc_pkey" primary key, btree (landtype, gvtype, regime, radar_id, orbit, height)

-- "Best" bias regime (stratiform above BB), broken out by site and GV type:
select gvtype, radar_id, landtype, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff from dbzdiff_stats_w_sfc where regime='S_above' and numpts>5 group by 1,2,3 order by 2,1,3;
