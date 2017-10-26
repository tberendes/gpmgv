.reset
INSTRUMENT='DPR'
swath='NS'
pctAbvThresh=70
gv_convective=0
gv_stratiform=0
Z_MEAS=0
ALTFIELD='ZM'
;NAME_ADD='V03B_KHGX_'+swath
NAME_ADD='ITE057_KHGX_'+swath
;NCSITEPATH='/USERS/krmorri1/data/netcdf/geo_match/GPM/2AKu/'+swath+'/V03B/1_21/'
NCSITEPATH='/USERS/krmorri1/data/netcdf/geo_match/GPM/2AKu/'+swath+'/ITE057/1_21/'
FILEPATTERN='GRtoDPR.KHGX*'
SITELIST=['KHGX']
EXCLUDE=0
OUTPATH='/tmp'
DO_STDDEV=1   
PROFILE_SAVE='/tmp'
;ALT_BB_FILE='/data/tmp/GPM_rain_event_bb_km_Uniq.txt'
FIRST_ORBIT=[190,8561]
SCATTERPLOT=1
bins4scat=2
convbelowscat=1
BB_RELATIVE=1
S2KU=1
PLOT_OBJ_ARRAY=1
VERSION2MATCH=['V03B']
;VERSION2MATCH=['ITE057']

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT=instrument, KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform, S2KU=s2ku, Z_MEAS=z_meas, NAME_ADD=name_add, NCSITEPATH=ncsitepath, FILEPATTERN=filepattern, SITELIST=sitelist, EXCLUDE=exclude, OUTPATH=outpath, ALTFIELD=altfield, BB_RELATIVE=bb_relative, DO_STDDEV=do_stddev, PROFILE_SAVE=profile_save, ALT_BB_FILE=alt_bb_file, FIRST_ORBIT=first_orbit, SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, CONVBELOWSCAT=convbelowscat, PLOT_OBJ_ARRAY=plot_obj_array, RAY_RANGE=ray_range, MAX_BLOCKAGE=max_blockage_in, VERSION2MATCH=version2match

If Z_MEAS then ztype='Zmeas' else ztype = 'Zcor'
If S2KU then adj='Ku-Adj.' else adj='Unadj.'
IF BB_RELATIVE then reltxt = 'BB-relative' else reltxt = 'AGL'
PLOT_obj_array[0].title='2A-Ku '+Ztype+' & '+adj+' GR Mean Z Profiles, 70% Abv. Thresh.!CITE057, '+swath+' scan, '+reltxt+', KHGX, V03B Match'
;PLOT_obj_array[0].title='2A-Ku '+Ztype+' & '+adj+' GR Mean Z Profiles, 70% Abv. Thresh.!CV03B, '+swath+' scan, '+reltxt+', KHGX, ITE057 Match'

PLOT_obj_array[0].xrange=[20.,50.]
PLOT_obj_array[0].close & PLOT_obj_array[1].close
