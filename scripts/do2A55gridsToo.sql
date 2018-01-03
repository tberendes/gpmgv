select a.orbit, a.radar_id||'/'||b.filepath||'/'||a.file2a55 as filepath2A55,
       a.file2a25, a.file1c21 
  from collatedzproducts a, gvradar b 
 where a.file2a55 = b.filename;