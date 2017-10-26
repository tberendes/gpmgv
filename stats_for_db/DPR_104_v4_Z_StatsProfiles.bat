.reset
MATCHUP_TYPE='DPR'
swath='NS'
pctAbvThresh=100
gv_convective=0
gv_stratiform=0
S2KU=1
ALTFIELD='ZC'
NAME_ADD='KFWS_V04A_104match_Ku'+swath
;NAME_ADD='KFWS_ITE104_V4match_Ku'+swath
NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2AKu/'+swath+'/V04A/1_21/'
;NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2AKu/'+swath+'/ITE104/1_21/'
;VERSION2MATCH=['V04A']
;VERSION2MATCH=['ITE104']
FILEPATTERN='GRtoDPR.*.15dbzGRDPR.*'
SITELIST=['KHGX']
;EXCLUDE=0
OUTPATH='/tmp'
BB_RELATIVE=0
DO_STDDEV=1   
PROFILE_SAVE='/tmp'
;ALT_BB_FILE='/data/tmp/GPM_rain_event_bb_km_Uniq.txt'
;FIRST_ORBIT=[190,8561]
SCATTERPLOT=0
bins4scat=2
convbelowscat=0
PLOT_OBJ_ARRAY=0
If KEYWORD_SET(Z_MEAS) then ztype='Zmeas' else ztype = 'Zcor'
If KEYWORD_SET(S2KU) then adj='Ku-Adj.' else adj='Unadj.'
IF KEYWORD_SET(BB_RELATIVE) then reltxt = 'BB-relative' else reltxt = 'AGL'
et_range=[5.0,9.99999]
DPR_Z_ADJUST = 2.9
GR_Z_ADJUST='/tmp/what.what'

stats_by_dist_to_dbfile_dpr_pr_geo_match, MATCHUP_TYPE=matchup_type, KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform, S2KU=s2ku, NAME_ADD=name_add, NCSITEPATH=ncsitepath, FILEPATTERN=filepattern, SITELIST=sitelist, EXCLUDE=exclude, OUTPATH=outpath, ALTFIELD=altfield, BB_RELATIVE=bb_relative, DO_STDDEV=do_stddev, PROFILE_SAVE=profile_save, ALT_BB_FILE=alt_bb_file, FIRST_ORBIT=first_orbit, SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array, RAY_RANGE=ray_range, MAX_BLOCKAGE=max_blockage_in, ET_RANGE=et_range, DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, VERSION2MATCH=version2match

PLOT_obj_array[0].title='2A-DPR '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CITE104, '+swath+' scan, '+reltxt+', KFWS, V04A Match'

PLOT_obj_array[0].title='2A-DPR '+Ztype+' & '+adj+' GR Mean Z Profiles, 100% Abv. Thresh.!CV04A, '+swath+' scan, '+reltxt+', KFWS, ITE104 Match'

PLOT_obj_array[0].xrange=[15.,45.]
PLOT_obj_array.close
