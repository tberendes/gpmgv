.reset

;first_orbit=6446
datatype='2ADPR'
swath='NS'
VERSION2DO='V04A'
VERSION2MATCH='ITE113'
nameAdd=datatype + '_' + swath + '_' + VERSION2MATCH +'match'+'_Dm_GT_2_5'
s2ku=1
SCATTERPLOT=1
;bins4scat=2
;convbelowscat=0
PLOT_OBJ_ARRAY=1
altfield='PIADMP'
BATCH_SAVE=1
;et_range=[10.0,19.99999]
;DPR_Z_ADJUST = -1.5
;GR_Z_ADJUST='/tmp/somefile'

z_rain_dsd_profile_scatter_all_bigdm_only, INSTRUMENT='DPR', SCANTYPE=swath, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, $
   PCT_ABV_THRESH=100, S2KU=s2ku, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/'+datatype+'/'+swath+'/'+VERSION2DO+'/1_21/', $
   FILEP='GRtoDPR.KHGX*.1_21.15dbzGRDPR_newDm.nc.gz', VERSION2MATCH=version2match, $
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   MAX_BLOCK=10, ET_RANGE=et_range, DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, BATCH_SAVE=BATCH_SAVE, PLOT_OBJ_ARRAY=plot_obj_array

, $
   PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.sav'

If KEYWORD_SET(Z_MEAS) then ztype='Zmeas' else ztype = 'Zcor'
If KEYWORD_SET(S2KU) then adj='Ku-Adj.' else adj='Unadj.'
IF KEYWORD_SET(BB_RELATIVE) then reltxt = 'BB-relative' else reltxt = 'AGL'

PLOT_obj_array[0].xrange=[30.,50.]

IF VERSION2DO EQ 'ITE113' THEN PLOT_obj_array[0].title='2A-Ku '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CITE113, '+swath+' scan, '+reltxt+', CONUS, V04A Match'

IF VERSION2DO EQ 'V04A' THEN PLOT_obj_array[0].title='2A-Ku '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CV04A, '+swath+' scan, '+reltxt+', CONUS, ITE113 Match'

