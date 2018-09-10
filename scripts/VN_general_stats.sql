-- latest event case currently defined in the rainy100inside100 table?

select * from rainy100inside100 where sat_id = 'GPM' order by overpass_time desc limit 1;
select * from rainy100inside100 where sat_id = 'PR' order by overpass_time desc limit 1;

-- total site overpasses in VN area prior to given date, for 'available' 88Ds

select count(*) from overpass_event where overpass_time between '2006-07-23 00:00:00-00' and '2011-02-16 23:59:59-00' and radar_id not in ('RMOR','DARW', 'RGSN','KWAJ','KMXX');

-- total rainy cases identified in rainy100inside100, for 'available' 88Ds

select count(*) from rainy100inside100 where radar_id not in ('RMOR','DARW', 'RGSN','KWAJ','KMXX');

-- find 100in100 overpasses having matching 2A55/2A54 radar data (from TRMM GV)
-- DO NOT EXECUTE, KILLER QUERY using collatedproductsWsub

--select count(*) from collatedproductsWsub a, rainy100inside100 b where a.radar_id=b.radar_id and a.orbit=b.orbit and a.file2a55 is not null and a.file2a54 is not null and a.radar_id not in ('RMOR','DARW', 'RGSN','KWAJ');

-- find 100in100 overpasses having matching 1CUF radar data (from TRMM GV)
-- have to exclude duplicate subset matches for KMLB by specifying subset

select count(*) from collatedgvproducts a, rainy100inside100 b where b.overpass_time between '2006-07-23 00:00:00-00' and '2012-08-31 23:59:59-00' and a.radar_id=b.radar_id and a.orbit=b.orbit and a.file1cuf is not null and a.radar_id not in ('RMOR','DARW', 'RGSN','KWAJ') and a.subset='sub-GPMGV1';

-- # GPM overpasses by 88D CONUS site
select radar_id, count(*) from overpass_event where sat_id='GPM' and radar_id <'KZZZ'  and radar_id not in ('DARW','NPOL','CHILL','KING','KWAJ') group by 1 order by 1;

-- # GPM site overpasses by month for routine sites
select date_trunc('month',overpass_time at time zone 'UTC') , count(*) from overpass_event where sat_id='GPM' and radar_id <'KZZZ'  and radar_id not like 'R%' and radar_id not in ('DARW','NPOL','CHILL','KING') group by 1 order by 1;
     date_trunc      | count 
---------------------+-------
 2014-03-01 00:00:00 |  1151
 2014-04-01 00:00:00 |  1161
 2014-05-01 00:00:00 |  1204
 2014-06-01 00:00:00 |  1183
 2014-07-01 00:00:00 |  1188
 2014-08-01 00:00:00 |  1214
 2014-09-01 00:00:00 |  1175
 2014-10-01 00:00:00 |  1197
 2014-11-01 00:00:00 |  1200
 2014-12-01 00:00:00 |  1259
 2015-01-01 00:00:00 |  1209
 2015-02-01 00:00:00 |  1121
 2015-03-01 00:00:00 |  1224
 2015-04-01 00:00:00 |   782
(14 rows)

-- GPM site RAINY overpasses with matching 1CUF data, monthly totals by subset area
-- does not actually exclude events with missing 1CUF?

select date_trunc('month', c.overpass_time at time zone 'UTC') as ovrptime, count(*) from rainy100inside100 r, collate_satsubprod_1cuf c where c.sat_id='GPM' and c.event_num=r.event_num and c.subset ='AKradars' and c.product_type = '2AKu' and c.version = 'V03B' AND C.FILE1CUF NOT LIKE '%rhi%' group by 1 order by 1;
      ovrptime       | count 
---------------------+-------
 2014-03-01 00:00:00 |     3
 2014-04-01 00:00:00 |     4
 2014-05-01 00:00:00 |     3
 2014-06-01 00:00:00 |     9
 2014-07-01 00:00:00 |    11
 2014-08-01 00:00:00 |    20
 2014-09-01 00:00:00 |    11
 2014-10-01 00:00:00 |    12
 2014-11-01 00:00:00 |     9
 2014-12-01 00:00:00 |    17
 2015-01-01 00:00:00 |     4
 2015-02-01 00:00:00 |    10
 2015-03-01 00:00:00 |    12
 2015-04-01 00:00:00 |    13
(14 rows)

select date_trunc('month', c.overpass_time at time zone 'UTC') as ovrptime, count(*) from rainy100inside100 r, collate_satsubprod_1cuf c where c.sat_id='GPM' and c.event_num=r.event_num and c.subset ='CONUS' and c.product_type = '2AKu' and c.version = 'V03B' AND C.FILE1CUF NOT LIKE '%rhi%' group by 1 order by 1;
      ovrptime       | count 
---------------------+-------
 2014-03-01 00:00:00 |    68
 2014-04-01 00:00:00 |   115
 2014-05-01 00:00:00 |   155
 2014-06-01 00:00:00 |   204
 2014-07-01 00:00:00 |   123
 2014-08-01 00:00:00 |   172
 2014-09-01 00:00:00 |   127
 2014-10-01 00:00:00 |    94
 2014-11-01 00:00:00 |   110
 2014-12-01 00:00:00 |   112
 2015-01-01 00:00:00 |   114
 2015-02-01 00:00:00 |    84
 2015-03-01 00:00:00 |   149
 2015-04-01 00:00:00 |   100
(14 rows)

-- new view to just collate overpass events with their matching. non-missing, 1CUF file
-- no information on presence of the GPM subset product(s) for the orbit
CREATE VIEW collate_sat_radar_overpass_1cuf AS select a.sat_id, a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, a.event_num, a.nearest_distance, (((a.radar_id::text || '/'::text) || g.filepath::text) || '/'::text) || g.filename::text AS file1cuf, fileidnum from  eventsatsubrad_vw a JOIN gvradar g ON a.overpass_time >= (g.nominal - '00:05:00'::interval) AND a.overpass_time <= (g.nominal + '00:05:00'::interval) AND a.radar_id::text = g.radar_id::text AND g.product::text ~~ '1CUF%'::text;

-- GPM CONUS overpasses with matching 1CUF files
select date_trunc('month', overpass_time at time zone 'UTC') as month, count(*) as n_matched from collate_sat_radar_overpass_1cuf where sat_id='GPM' and subset='CONUS' group by 1 order by 1;
        month        | n_matched 
---------------------+-----------
 2014-03-01 00:00:00 |       601
 2014-04-01 00:00:00 |       715
 2014-05-01 00:00:00 |       749
 2014-06-01 00:00:00 |       754
 2014-07-01 00:00:00 |       169
 2014-08-01 00:00:00 |       561
 2014-09-01 00:00:00 |       716
 2014-10-01 00:00:00 |       700
 2014-11-01 00:00:00 |       747
 2014-12-01 00:00:00 |       425
 2015-01-01 00:00:00 |       772
 2015-02-01 00:00:00 |       695
 2015-03-01 00:00:00 |       765
 2015-04-01 00:00:00 |       386
(14 rows)

select date_trunc('month', c.overpass_time at time zone 'UTC') as month, count(*) as n_matched from collate_sat_radar_overpass_1cuf c,  rainy100inside100 r where c.sat_id='GPM' and c.event_num=r.event_num and c.subset in ('CONUS','AKradars') group by 1 order by 1;
        month        | n_matched 
---------------------+-----------
 2014-03-01 00:00:00 |        45
 2014-04-01 00:00:00 |       100
 2014-05-01 00:00:00 |       139
 2014-06-01 00:00:00 |       192
 2014-07-01 00:00:00 |        18
 2014-08-01 00:00:00 |       101
 2014-09-01 00:00:00 |       116
 2014-10-01 00:00:00 |        79
 2014-11-01 00:00:00 |        99
 2014-12-01 00:00:00 |        44
 2015-01-01 00:00:00 |        98
 2015-02-01 00:00:00 |        79
 2015-03-01 00:00:00 |       130
 2015-04-01 00:00:00 |        83
(14 rows)

-- # TRMM site overpasses by month for routine sites
select date_trunc('month',overpass_time at time zone 'UTC') , count(*) from overpass_event where sat_id='PR' and radar_id <'KZZZ'  and radar_id not like 'R%' and radar_id not in ('DARW','NPOL','CHILL','KING') group by 1 order by 1;
     date_trunc      | count 
---------------------+-------
 2006-08-01 00:00:00 |   991
 2006-09-01 00:00:00 |   984
 2006-10-01 00:00:00 |  1080
 2006-11-01 00:00:00 |  1046
 2006-12-01 00:00:00 |  1094
 2007-01-01 00:00:00 |  1080
 2007-02-01 00:00:00 |   965
 .
 .
 .
etc.


-- rainy TRMM overpasses with GR
select date_trunc('month', c.overpass_time at time zone 'UTC') as month, count(*) as n_matched from collate_sat_radar_overpass_1cuf c,  rainy100inside100 r where c.sat_id='PR' and c.event_num=r.event_num group by 1 order by 1;
        month        | n_matched 
---------------------+-----------
 2006-01-01 00:00:00 |         1
 2006-03-01 00:00:00 |         2
 2006-06-01 00:00:00 |         1
 2006-07-01 00:00:00 |         4
 2006-08-01 00:00:00 |       166
 2006-09-01 00:00:00 |       191
 2006-10-01 00:00:00 |       153
 2006-11-01 00:00:00 |        74
 .
 .
 .
etc.

-- number and percent of rainy GPM overpasses with UF data for CONUS 88D sites
select radar_id, MIN(DATE(overpass_time)) as start_data, count(*) as npasses into temp ufpasses from collate_sat_radar_overpass_1cuf where sat_id='GPM' and subset in ('CONUS', 'AKradars', 'Guam', 'Hawaii', 'SanJuanPR') group by 1 order by 1;

select a.radar_id, count(*) as nrain, MAX(DATE(a.overpass_time)) as last_rainy into temp rainpasses from collate_sat_radar_overpass_1cuf a, rainy100inside100 r where a.sat_id='GPM' and a.subset in ('CONUS', 'AKradars', 'Guam', 'Hawaii', 'SanJuanPR') and a.event_num=r.event_num group by 1 order by 1;

select a.radar_id, nrain, npasses, round(((nrain*100.0)/npasses)+0.5) as percent_rain, start_data, last_rainy from rainpasses a, ufpasses b where a.radar_id=b.radar_id and npasses > 20;
 radar_id | nrain | npasses | percent_rain | start_data | last_rainy 
----------+-------+---------+--------------+------------+------------
 KABR     |    52 |     455 |           12 | 2014-03-02 | 2016-08-18
 KAKQ     |    60 |     383 |           16 | 2014-03-02 | 2016-09-03
 KAMX     |    67 |     324 |           21 | 2014-03-03 | 2016-09-06
 KAPX     |    57 |     464 |           13 | 2014-03-01 | 2016-07-29
 KARX     |    55 |     430 |           13 | 2014-03-03 | 2016-09-09
 KBMX     |    58 |     363 |           16 | 2014-03-02 | 2016-07-30
 KBOX     |    55 |     414 |           14 | 2014-03-03 | 2016-07-31
 KBRO     |    30 |     335 |            9 | 2014-03-01 | 2016-09-04
 KBUF     |    59 |     422 |           14 | 2014-03-05 | 2016-09-07
 KBYX     |    49 |     336 |           15 | 2014-03-03 | 2016-09-06
 KCCX     |    65 |     409 |           16 | 2014-03-02 | 2016-08-31
 .
 .
 .
etc.

-- GPM-specific UF and rainy stats run on 8/6/2018

-- total UF files by subset

gpmgv=> select subset, count(*) as n_matched from collate_sat_radar_overpass_1cuf where sat_id='GPM'  group by 1 order by 1;
    subset    | n_matched 
--------------+-----------
 AKradars     |      4268
 BrazilRadars |      1742
 Brisbane     |        61
 CONUS        |     39643
 DARW         |        18
 Guam         |       362
 Hawaii       |       919
 KWAJ         |       591
 SanJuanPR    |       347
(9 rows)

-- as above, but for rain events only

gpmgv=> select subset, count(*) as n_matched from collate_sat_radar_overpass_1cuf a, rainy100inside100 b where a.event_num=b.event_num and a.sat_id='GPM'  group by 1 order by 1;
    subset    | n_matched 
--------------+-----------
 AKradars     |       851
 BrazilRadars |       256
 Brisbane     |         8
 CONUS        |      5837
 DARW         |         7
 Guam         |        86
 Hawaii       |        58
 KWAJ         |       166
 SanJuanPR    |        73
(9 rows)

-- total rainy events with UF files for GPM

gpmgv=> select count(*) from collate_sat_radar_overpass_1cuf a, rainy100inside100 b where a.event_num=b.event_num and a.sat_id='GPM';
 count 
-------
  7342
(1 row)

-- total overpass events with UF files for GPM

gpmgv=> select count(*) as n_matched from collate_sat_radar_overpass_1cuf where sat_id='GPM';
 n_matched 
-----------
     47951
(1 row)

