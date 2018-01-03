select a.orbit, a.cycle at time zone 'UTC' as cycle, a.filename as soundingsfile, coalesce(b.filename, 'No6hForecast') as precip6file, coalesce(c.filename, 'No3hForecast') as precip3file from modelgrids a left join modelgrids b on a.orbit=b.orbit and (a.cycle+a.projection)=(b.cycle+b.projection) and b.Projection = '06:00:00' left outer join modelgrids c on b.cycle=c.cycle and a.orbit=c.orbit and c.projection = '03:00:00' where a.Projection='00:00:00' order by orbit desc, cycle desc limit 10;

create table modelsoundings(
model character varying(15) default 'NAMANL',
cycle timestamp with time zone,
radar_id character varying(15),
filename character varying(63) not null unique,
primary key (cycle, radar_id, model),
FOREIGN KEY (radar_id) REFERENCES instrument(instrument_id)
);

select count(distinct instrument_id), a.cycle at time zone 'UTC' as cycle, a.filename as sndfile, coalesce(b.filename, 'No6hForecast') as pcp6file, coalesce(c.filename, 'No3hForecast') as pcp3file from overpass_event o join fixed_instrument_location f on o.radar_id=f.instrument_id join modelgrids a on a.orbit=o.orbit left join modelgrids b on a.orbit=b.orbit and (a.cycle+a.projection)=(b.cycle+b.projection) and b.Projection = '06:00:00' left outer join modelgrids c on b.cycle=c.cycle and a.orbit=c.orbit and c.projection = '03:00:00' left outer join modelsoundings s on o.radar_id=s.radar_id and a.cycle=s.cycle and s.model='NAMANL' where a.Projection='00:00:00' and o.radar_id>'KAA' and o.radar_id<'KWAJ' and o.radar_id!='KMXX' and s.filename is null group by 2,3,4,5 order by 2 desc limit 5;
