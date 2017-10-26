
CREATE VIEW collatedprproductswsub AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM collatecolswsub a LEFT OUTER JOIN orbit_subset_product d ON a.orbit = d.orbit AND a.subset = d.subset AND d.product_type = '1C21' LEFT OUTER JOIN orbit_subset_product e ON a.orbit = e.orbit AND a.subset = e.subset AND d.version = e.version AND e.product_type = '2A23' LEFT OUTER JOIN orbit_subset_product f ON a.orbit = f.orbit AND a.subset = f.subset AND d.version = f.version AND f.product_type = '2A25' LEFT OUTER JOIN orbit_subset_product h ON a.orbit = h.orbit AND a.subset = h.subset AND d.version = h.version AND h.product_type = '2B31';
--this is slower than the above
CREATE VIEW collatedprproductswsub2 AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, d.version, d.filename AS file1c21, e.filename AS file2a23, f.filename AS file2a25, h.filename AS file2b31 FROM collatecolswsub a LEFT OUTER JOIN orbit_subset_product d USING(orbit, subset) LEFT OUTER JOIN orbit_subset_product e USING(orbit, subset, version) LEFT OUTER JOIN orbit_subset_product f USING(orbit, subset, version) LEFT OUTER JOIN orbit_subset_product h USING(orbit, subset, version) WHERE d.product_type = '1C21' AND e.product_type = '2A23' AND f.product_type = '2A25' AND h.product_type = '2B31';

-- one-product-type GV collator
CREATE VIEW collatedgvproducttype AS
    SELECT a.orbit, a.radar_id, a.overpass_time, a.nominal, a.subset, b.product, a.radar_id || '/' || b.filepath || '/' || b.filename AS gvpathname FROM collatecolswsub a LEFT JOIN gvradar b ON a.nominal = b.nominal AND a.radar_id = b.radar_id;