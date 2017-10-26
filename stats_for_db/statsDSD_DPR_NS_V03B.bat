;sitelist=['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', 'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', 'KMLB', 'KMOB', 'KMXX', 'KSHV', 'KTBW', 'KTLH']

;first_orbit=6446
;exclude=1
;IF KEYWORD_SET(exclude) THEN nameAdd='NOT_SE_US_150706' ELSE nameAdd='IN_SE_US_150706'

.reset
nameAdd='K_Sites_V04A_Pct70'
SCATTERPLOT=1
bins4scat=2
convbelowscat=1
PLOT_OBJ_ARRAY=1
swath='NS'
altfield='D0'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', $
   FILEP='GRtoDPR.K*.1_21*.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/GPM_rain_event_bb_km_Uniq.txt', $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, $
   CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array
, $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.sav'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array, $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPRNS.s2ku.sav'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.sav'

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_21', FILEP='GRtoDPR.K*.1_21.15dbzGRDPR.nc.gz',$
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=1, $
   ALT_BB_FILE='/data/tmp/stats_for_db/GPM_rain_event_bb_km.txt', $
   PROFILE_SAVE='/data/tmp/stats_for_db/BBrelProfiles.' + nameAdd + '.DPRNS.s2ku.sav'

first_orbit=98981

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='PR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=0, NAME_ADD='from_20150331', $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1/2015/GRtoPR.*',$
   SITELIST=sitelist, OUTPATH='/tmp', BB_RELATIVE=0, $
   PROFILE_SAVE='/data/tmp/stats_for_db/Profiles.150708.PR.sav', FIRST_ORBIT=first_orbit

stats_z_rain_dsd_to_db_profile_scatter, INSTRUMENT='PR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, DO_STDDEV=1, $
   PCT_ABV_THRESH=70, S2KU=1, NAME_ADD='from_20150331', $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1/2015/GRtoPR.*',$
   SITELIST=sitelist, OUTPATH='/tmp', BB_RELATIVE=0, $
   PROFILE_SAVE='/data/tmp/stats_for_db/Profiles.150708.PR.sav', FIRST_ORBIT=first_orbit
