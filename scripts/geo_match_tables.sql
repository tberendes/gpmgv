CREATE TABLE geo_match_criteria
(
  criteria_id VARCHAR(32) PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  db_table VARCHAR(32)
);

insert into geo_match_criteria values ('rainy100inside100', '100 rain certain gridpoints inside 100 km', 'rainy100inside100');

CREATE TABLE geo_match_parameters
(
  parameter_set INTEGER PRIMARY KEY,
  range_max FLOAT DEFAULT 100.0,
  pr_dbz_min FLOAT DEFAULT 18.0,
  gr_dbz_min FLOAT DEFAULT 15.0,
  rain_min FLOAT DEFAULT 0.01,
  time_window INTERVAL DEFAULT '540 seconds',
  time_offset INTERVAL DEFAULT '0 seconds',
  spatial_precip VARCHAR(32) REFERENCES geo_match_criteria(criteria_id)
);

insert into geo_match_parameters(parameter_set, spatial_precip) values(0, 'rainy100inside100');

CREATE TABLE geo_match_product
(
  radar_id VARCHAR(15),
  orbit INTEGER,
  pathname VARCHAR(255) UNIQUE NOT NULL,
  pr_version INTEGER DEFAULT 6,
  parameter_set INTEGER references geo_match_parameters,
  geo_match_version FLOAT,
  num_gr_volumes INTEGER DEFAULT 1,
  PRIMARY KEY (radar_id, orbit, pr_version, parameter_set, geo_match_version)
);

GRANT SELECT, INSERT ON geo_match_criteria to PUBLIC;
GRANT SELECT, INSERT ON geo_match_parameters to PUBLIC;
GRANT SELECT, INSERT ON geo_match_product to PUBLIC;
GRANT DELETE ON geo_match_criteria to gvoper;
GRANT DELETE ON geo_match_parameters to gvoper;
GRANT DELETE ON geo_match_product to gvoper;

