;sitelist=['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', 'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', 'KMLB', 'KMOB', 'KMXX', 'KSHV', 'KTBW', 'KTLH']

;first_orbit=6446
;exclude=1
;IF KEYWORD_SET(exclude) THEN nameAdd='NOT_SE_US_150706' ELSE nameAdd='IN_SE_US_150706'

.reset
nameAdd='K_Sites15dbzPct70'
SCATTERPLOT=1
bins4scat=2
convbelowscat=0
PLOT_OBJ_ARRAY=1
swath='NS'
KuKa='Ku'
altfield='Nw'
first_orbit=4330
 version2match='V03D'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPRGMI', KUKA=KuKa, SCANTYPE=swath, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V04A/1_3', $
   FILEP='GRtoDPRGMI.KAMX*.1_3.*nc.gz', VERSION2MATCH=version2match, $
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, $
   PLOT_OBJ_ARRAY=plot_obj_array
, $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.sav'




stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR',KUKA=KuKa, SCANTYPE=swath,  $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array, $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.s2ku.sav'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', KUKA=KuKa, SCANTYPE=swath, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.sav'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', KUKA=KuKa, SCANTYPE=swath, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.s2ku.sav'

first_orbit=98981

