-- view handles the situation where sometimes KWAJ UF files for two consecutive
-- volume scans with the same nominal hour are in the database - takes earlier one
CREATE VIEW collatedGVproducts_kwajcal2 AS
SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, MIN((((a.radar_id || '/') || d.filepath) || '/') || d.filename) AS file1cuf
   FROM collatecolswsub a
   LEFT JOIN gvradar d ON a.nominal = d.nominal AND a.radar_id = d.radar_id AND d.product like '1CUF%'
   GROUP BY 1,2,3,4,5;
