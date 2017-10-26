CREATE VIEW collatedgvproducts AS
SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, 
a.radar_id || '/' || b.filepath || '/' || b.filename AS file2a55, 
a.radar_id || '/' || c.filepath || '/' || c.filename AS file2a54, 
a.radar_id || '/' || f.filepath || '/' || f.filename AS file2a53, 
a.radar_id || '/' || d.filepath || '/' || d.filename AS file1cuf, 
a.radar_id || '/' || e.filepath || '/' || e.filename AS file1c51 
FROM collatecolswsub a 
LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id = b.radar_id AND b.product = '2A55' 
LEFT JOIN gvradar c ON a.nominal = c.nominal AND a.radar_id = c.radar_id AND c.product = '2A54' 
LEFT JOIN gvradar f ON a.nominal = f.nominal AND a.radar_id = f.radar_id AND f.product = '2A53' 
LEFT JOIN gvradar d ON a.overpass_time between d.nominal-interval '5 minutes' and d.nominal+interval '5 minutes'
          AND a.radar_id = d.radar_id AND d.product = '1CUF' 
LEFT JOIN gvradar e ON a.nominal = e.nominal AND a.radar_id = e.radar_id AND e.product = '1C51';

REVOKE ALL ON TABLE collatedgvproducts FROM PUBLIC;
GRANT SELECT ON TABLE collatedgvproducts TO PUBLIC;

CREATE VIEW collate_2a12_1cuf as SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, t.version, t.filename AS file2a12, COALESCE(a.radar_id || '/' || g.filepath || '/' || g.filename, 'no_1CUF_file') AS file1cuf FROM collatecolswsub a LEFT JOIN orbit_subset_product t ON a.orbit = t.orbit AND a.subset = t.subset AND t.product_type = '2A12' LEFT JOIN gvradar g ON a.overpass_time between g.nominal-interval '5 minutes' and g.nominal+interval '5 minutes' AND a.radar_id = g.radar_id AND g.product like '1CUF%';
