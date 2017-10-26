insert into event_meta_numeric
select t.* from metadata_temp t where not exists
 (select * from event_meta_numeric p
  where p.event_num = t.event_num and p.metadata_id = t.metadata_id);

-- don't need these data_type checks, metadata_temp only holds numeric data
insert into event_meta_numeric
select t.* from metadata_temp t, metadata_parameter i
where t.metadata_id = i.metadata_id and i.data_type in
('INTEGER','FLOAT') and not exists
 (select * from event_meta_numeric p
  where p.event_num = t.event_num and p.metadata_id = t.metadata_id);
