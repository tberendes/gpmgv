CREATE TABLE lineage
(
-- P=parent, C=child, N=none
relationship CHAR(1) PRIMARY KEY,
description VARCHAR(6) NOT NULL
);

CREATE TABLE instrument
(
instrument_id VARCHAR(15) PRIMARY KEY,
instrument_type VARCHAR(31),
instrument_name VARCHAR(31),
owner VARCHAR(15),
parent_child CHAR(1) NOT NULL DEFAULT 'N'
    REFERENCES lineage (relationship),
produces_data CHAR(1) NOT NULL DEFAULT 'Y',
fixed_or_moving CHAR(1) NOT NULL DEFAULT 'F',
coverage_type VARCHAR(15),
replaced_by_id VARCHAR(15)
);

CREATE TABLE overpass_event 
(
event_num SERIAL PRIMARY KEY,
sat_id VARCHAR(15) REFERENCES instrument (instrument_id),
orbit INTEGER NOT NULL,
radar_id VARCHAR(15) REFERENCES instrument (instrument_id),
overpass_time TIMESTAMP WITH TIME ZONE NOT NULL,
nearest_distance INTEGER NOT NULL,
UNIQUE (sat_id, radar_id, orbit)
);

CREATE TABLE instrument_hierarchy
(
parent_instrument_id VARCHAR(15) REFERENCES instrument (instrument_id),
child_instrument_id VARCHAR(15) REFERENCES instrument (instrument_id),
PRIMARY KEY (parent_instrument_id, child_instrument_id)
);

REVOKE ALL ON lineage FROM PUBLIC;
REVOKE ALL ON instrument FROM PUBLIC;
REVOKE ALL ON overpass_event FROM PUBLIC;
REVOKE ALL ON instrument_hierarchy FROM PUBLIC;

GRANT ALL ON lineage TO morris;
GRANT ALL ON instrument TO morris;
GRANT ALL ON overpass_event TO morris;
GRANT ALL ON instrument_hierarchy TO morris;

GRANT SELECT ON lineage TO PUBLIC;
GRANT SELECT ON instrument TO PUBLIC;
GRANT SELECT ON overpass_event TO PUBLIC;
GRANT SELECT ON instrument_hierarchy TO PUBLIC;
