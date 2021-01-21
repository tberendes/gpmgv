-- fill a temp table with all rainy overpass info

select a.sat_id, a.radar_id, a.orbit, a.event_num, a.overpass_time, b.value/19.61 as pct_overlap, (c.value/b.value)*100 as pct_overlap_conv, (d.value/b.value)*100 as pct_overlap_strat, e.value as num_overlap_Rain_certain into temp rainy100by100temp
from overpass_event a
    JOIN event_meta_numeric b ON a.event_num = b.event_num AND b.metadata_id = 250199
    JOIN event_meta_numeric c ON a.event_num = c.event_num AND c.metadata_id = 230102
    JOIN event_meta_numeric d ON a.event_num = d.event_num AND d.metadata_id = 230101
    JOIN event_meta_numeric e ON a.event_num = e.event_num AND e.metadata_id = 251105 and e.value >= 20 order by 4;

-- select all cases that aren't already in the permanent table, save in 2nd temp table:

select * into temp rain100new_temp from rainy100by100temp where not exists (select * from rainy100inside100 where rainy100by100temp.event_num=rainy100inside100.event_num) order by 4;

-- load the new cases into the permanent table

insert into rainy100inside100 select * from rain100new_temp;
