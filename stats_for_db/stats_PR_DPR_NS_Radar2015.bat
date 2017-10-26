nameAdd='AllSites150810'

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_1', FILEP='GRtoDPR.*.1_1.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.sav'

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_1', FILEP='GRtoDPR.*.1_1.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.s2ku.sav'

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_1', FILEP='GRtoDPR.*.1_1.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.sav'

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_1', FILEP='GRtoDPR.*.1_1.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.s2ku.sav'



sitelist=['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', 'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', 'KMLB', 'KMOB', 'KMXX', 'KSHV', 'KTBW', 'KTLH']

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='PR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD='from_20140101', $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1/2014/', FILEP='GRtoPR.*',$
   SITELIST=sitelist, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=0, $
   PROFILE_SAVE='/data/tmp/stats_for_db/Profiles.2014.PR.sav', FIRST_ORBIT=first_orbit

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT='PR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD='from_20140101', $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1/2014/', FILEP='GRtoPR.*',$
   SITELIST=sitelist, OUTPATH='/data/tmp/stats_for_db', BB_RELATIVE=0, $
   PROFILE_SAVE='/data/tmp/stats_for_db/Profiles.2014.PR.sav', FIRST_ORBIT=first_orbit
