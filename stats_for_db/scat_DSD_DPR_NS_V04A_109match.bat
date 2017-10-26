;sitelist=['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', 'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', 'KMLB', 'KMOB', 'KMXX', 'KSHV', 'KTBW', 'KTLH']

;first_orbit=6446
;exclude=1
;IF KEYWORD_SET(exclude) THEN nameAdd='NOT_SE_US_150706' ELSE nameAdd='IN_SE_US_150706'

.reset
nameAdd='2AKu_V4match'
SCATTERPLOT=1
;bins4scat=2
;convbelowscat=0
PLOT_OBJ_ARRAY=1
swath='NS'
;altfield='DMANY'
BATCH_SAVE=1
VERSION2MATCH='V04A'
;et_range=[10.0,19.99999]
;DPR_Z_ADJUST = -1.5
;GR_Z_ADJUST='/tmp/somefile'

z_rain_dsd_profile_scatter_all, INSTRUMENT='DPR', SCANTYPE=swath, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, $
   PCT_ABV_THRESH=100, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2AKu/NS/ITE113/1_21', $
   FILEP='GRtoDPR.K*.1_21.15dbzGRDPR_newDm.nc.gz', VERSION2MATCH=version2match, $
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   MAX_BLOCK=10, ET_RANGE=et_range, DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, BATCH_SAVE=BATCH_SAVE, PLOT_OBJ_ARRAY=plot_obj_array

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
