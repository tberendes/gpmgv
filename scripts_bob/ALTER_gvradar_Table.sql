-- adds a SERIAL column to the existing 'gvradar' table and sets serial values

begin;
create sequence gvradar_fileidnum_seq;
alter table gvradar add fileidnum bigint UNIQUE;
alter table gvradar alter column fileidnum set default nextval('gvradar_fileidnum_seq');
update gvradar set fileidnum = nextval('gvradar_fileidnum_seq');
alter table gvradar alter column fileidnum set NOT NULL;
commit;
