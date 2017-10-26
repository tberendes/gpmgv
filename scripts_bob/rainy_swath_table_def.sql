CREATE TABLE rain_by_orbit_swath(
orbit INTEGER,
version INTEGER,
subset VARCHAR(15),
strat_ocean integer,
strat_land INTEGER,
strat_coast INTEGER,
strat_unknown INTEGER,
strat_total INTEGER,
conv_ocean INTEGER,
conv_land INTEGER,
conv_coast INTEGER,
conv_unknown INTEGER,
conv_total INTEGER,
PRIMARY KEY (orbit, version, subset)
);
