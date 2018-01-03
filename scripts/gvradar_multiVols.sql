select a.radar_id,a.filename,b.filename from gvradar a, gvradar b where a.product=b.product and a.product ='images' and a.radar_id=b.radar_id and a.filename like '%_CZ_%.00.gif' and b.filename like '%_CZ_%.00.gif' and a.nominal > b.nominal and a.nominal-b.nominal < interval '12 minutes' limit 10;

select * from gvradarvolume prime where 1 < (select count(*) from gvradarvolume sub where sub.filename=prime.filename);
select radar_id, count(*) from gvradar a, gvradarvolume b where substring(a.filename from 1 for 20)=substring(b.filename from 1 for 20)  and b.start_time='1970-01-01 00:00:00+00' group by 1;
select * from gvradar a, gvradarvolume b where substring(a.filename from 1 for 20)=substring(b.filename from 1 for 20) limit 10; 

gpmgv=# select radar_id, count(*) from gvradar a, gvradarvolume b where substring(a.filename from 1 for 20)=substring(b.filename from 1 for 20)  and b.start_time!='1970-01-01 00:00:00+00' group by 1 order by 1;
 radar_id | count
----------+-------
 KAMX     |    71
 KBRO     |    71
 KBYX     |    68
 KCRP     |    77
 KGRK     |    41
 KHGX     |    89
 KJAX     |   100
 KLCH     |    94
 KMLB     |    79
 KTBW     |    78
 KTLH     |    98
(11 rows)

gpmgv=# select radar_id, count(*) from gvradar a, gvradarvolume b where substring(a.filename from 1 for 20)=substring(b.filename from 1 for 20)  and b.start_time='1970-01-01 00:00:00+00' group by 1 order by 1;
 radar_id | count
----------+-------
 KBMX     |    51
 KCLX     |   146
 KDGX     |   126
 KEVX     |    98
 KFWS     |   138
 KJGX     |   140
 KLIX     |    96
 KMOB     |    33
 KSHV     |   133
(9 rows)
