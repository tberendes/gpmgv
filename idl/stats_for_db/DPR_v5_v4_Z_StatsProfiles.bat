.reset
MATCHUP_TYPE='DPR'
swath='NS'
pctAbvThresh=90
pctStr = STRING(pctAbvThresh, FORMAT='(I0)')+'%'
gv_convective=0
gv_stratiform=0
S2KU=1
ALTFIELD='ZC'

VERSION2DO='V05A'  &  VERSION2MATCH=['V04A']     ; COMMENT-OUT ONE OR THE OTHER OF THESE 2 LINES
;VERSION2DO='V04A'  &  VERSION2MATCH=['V05A']

NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/'+swath+'/'+VERSION2DO+'/1_21/'
NAME_ADD='AllSites_'+VERSION2DO+'_'+VERSION2MATCH[0]+'match_DPR'+swath
FILEPATTERN='GRtoDPR.*.1_21.nc.gz'
;SITELIST=['KHGX']
;EXCLUDE=0
OUTPATH='/tmp'
BB_RELATIVE=0
DO_STDDEV=1   
PROFILE_SAVE='/tmp'
ALT_BB_FILE='/data/tmp/GPM_rain_event_bb_km_Uniq.txt'
;FIRST_ORBIT=[190,8561]
;SCATTERPLOT=1
bins4scat=2
convbelowscat=1
;PLOT_OBJ_ARRAY=0
;et_range=[5.0,9.99999]
;DPR_Z_ADJUST = 2.9
;GR_Z_ADJUST='/tmp/what.what'  ; don't have a file of site bias corrections
max_blockage=10

; OPTIONAL PLOT TITLE SETUP IF PLOTTING PROFILES (i.e., PROFILE_SAVE directory is defined):

If KEYWORD_SET(Z_MEAS) then ztype='Zmeas' else ztype = 'Zcor'
If KEYWORD_SET(S2KU) then adj='Ku-Adj.' else adj='Unadj.'
IF KEYWORD_SET(BB_RELATIVE) then reltxt = 'BB-relative' else reltxt = 'AGL'
; THIS IS ALL ONE COMMAND LINE:
protitle = '2ADPR '+Ztype+' & '+adj+' GR Mean Z Profiles, '+pctStr+' Abv. Thresh.!C'+VERSION2DO+', '+swath+' scan, '+reltxt+', All Sites, '+VERSION2MATCH+' Match'

; RUN THE PROCEDURE - THIS IS ALL ONE COMMAND LINE

stats_by_dist_to_dbfile_dpr_pr_geo_match, MATCHUP_TYPE=matchup_type, KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform, S2KU=s2ku, NAME_ADD=name_add, NCSITEPATH=ncsitepath, FILEPATTERN=filepattern, SITELIST=sitelist, EXCLUDE=exclude, OUTPATH=outpath, ALTFIELD=altfield, BB_RELATIVE=bb_relative, DO_STDDEV=do_stddev, PROFILE_SAVE=profile_save, ALT_BB_FILE=alt_bb_file, FIRST_ORBIT=first_orbit, SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array, RAY_RANGE=ray_range, MAX_BLOCKAGE=max_blockage, ET_RANGE=et_range, DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, VERSION2MATCH=version2match

; ADD ANNOTATIONS IF PLOTTING PROFILES

PLOT_obj_array[0].title=protitle
PLOT_obj_array[0].xrange=[20.,50.]

; TO CLOSE THE OBJECT GRAPHIC WINDOWS AFTER ANNOTATING AND SAVING:
PLOT_obj_array[0].close
PLOT_obj_array[1].close   ; IF SCATTER PLOT IS PRESENT
