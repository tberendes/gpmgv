.reset

datatype='2ADPR'
swath='NS'
VERSION2DO='ITE114'
VERSION2MATCH='V04A'
nameAdd=datatype + '_' + swath + '_' + VERSION2MATCH +'match'
SCATTERPLOT=1
PLOT_OBJ_ARRAY=1
;altfield='RR'
BATCH_SAVE=1
PCT_ABV_THRESH=100
s2ku=1
MAX_BLOCK=10
;ray_range=[12,36]
;et_range=[5.0,19.99999]
;dpr_dm_thresh=2.5
;DPR_Z_ADJUST = -1.5
;GR_Z_ADJUST='/tmp/somefile'
FIRST_ORBIT=[2977,15668]

; destination directory for SAVE file containing the mean profile variables. Comment
; out line if not outputting mean Z profiles:
;PROFILE_SAVE='/data/tmp/stats_for_db/AGL_Profiles.' + nameAdd + '.DPR_'+swath+'.sav'

OUTPATH='/tmp'    ; destination directory for scatter plot PNG files

z_rain_dsd_profile_scatter_all, INSTRUMENT='DPR', SCANTYPE=swath, RAY_RANGE=ray_range, $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, $
   PCT_ABV_THRESH=PCT_ABV_THRESH, S2KU=s2ku, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/'+datatype+'/'+swath+'/'+VERSION2DO+'/1_21/', $
   FILEP='GRtoDPR.K*_newDm.nc.gz', VERSION2MATCH=version2match, $
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH=OUTPATH, BB_RELATIVE=0, $
   DPR_DM_THRESH=dpr_dm_thresh, MAX_BLOCK=MAX_BLOCK, ET_RANGE=et_range, $
   DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, BATCH_SAVE=BATCH_SAVE, $
   PLOT_OBJ_ARRAY=plot_obj_array, PROFILE_SAVE=PROFILE_SAVE

;=======================================================================

; IGNORE EVERYTHING BELOW THIS LINE UNLESS YOU SET UP THE PROFILE_SAVE
; PARAMETER TO RUN THE MEAN Z PROFILES.  IF YOU DID SET UP FOR PROFILES,
; THEN THESE COMMANDS LET YOU ANNOTATE AND PROPERLY CONFIGURE THE PLOTS.
; -- MUST WAIT UNTIL 2ND PROFILE PLOT (OBJECT GRAPHIC) COMPLETES BEFORE
;    RUNNING THESE COMMANDS, AND CAN ONLY BE RUN IF YOU DIDN'T TYPE 'C'
;    (CLOSE PLOT WINDOW) AT THE PROMPT.

If KEYWORD_SET(Z_MEAS) then ztype='Zmeas' else ztype = 'Zcor'
If KEYWORD_SET(S2KU) then adj='Ku-Adj.' else adj='Unadj.'
IF KEYWORD_SET(BB_RELATIVE) then reltxt = 'BB-relative' else reltxt = 'AGL'

; move the profiles out of the way of the legend
PLOT_obj_array[0].xrange=[20.,50.]

IF VERSION2DO EQ 'ITE114' THEN PLOT_obj_array[0].title='2A-DPR '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CITE114, '+swath+' scan, '+reltxt+', CONUS, V04A Match'

IF VERSION2DO EQ 'V04A' THEN PLOT_obj_array[0].title='2A-DPR '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CV04A, '+swath+' scan, '+reltxt+', CONUS, ITE114 Match'

; AFTER YOU ARE DONE WITH THE PLOT AND HAVE SAVED IT TO A FILE, CLOSE IT.
PLOT_OBJ_ARRAY[0].CLOSE
