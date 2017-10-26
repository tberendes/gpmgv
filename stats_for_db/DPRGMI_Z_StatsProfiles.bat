.reset
INSTRUMENT='DPRGMI'
KUKA='Ku'
swath='MS'
pctAbvThresh=70
gv_convective=0
gv_stratiform=0
S2KU=1
;NAME_ADD='V03CD_CONUS_'+swath
NAME_ADD='ITE052_CONUS_'+swath
;NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V03*/1_2/'
NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V4ITE/1_2/'
FILEPATTERN='GRtoDPRGMI.K*'
SITELIST=['KMLB','KWAJ']
EXCLUDE=1
OUTPATH='/tmp'
BB_RELATIVE=1
DO_STDDEV=1   
PROFILE_SAVE='/tmp'
ALT_BB_FILE='/data/tmp/GPM_rain_event_bb_km_Uniq.txt'
FIRST_ORBIT=[190,8561]
SCATTERPLOT=0
PLOT_OBJ_ARRAY=1
VERSION2MATCH=['V03C','V03D']
;VERSION2MATCH='V4ITE'

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT=instrument, KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform, S2KU=s2ku, NAME_ADD=name_add, NCSITEPATH=ncsitepath, FILEPATTERN=filepattern, SITELIST=sitelist, EXCLUDE=exclude, OUTPATH=outpath, ALTFIELD=altfield, BB_RELATIVE=bb_relative, DO_STDDEV=do_stddev, PROFILE_SAVE=profile_save, ALT_BB_FILE=alt_bb_file, FIRST_ORBIT=first_orbit, SCATTERPLOT=scatterplot, PLOT_OBJ_ARRAY=plot_obj_array, RAY_RANGE=ray_range, MAX_BLOCKAGE=max_blockage_in, VERSION2MATCH=version2match

PLOT_obj_array.title='2B-DPRGMI & Ku-Adj. GR Mean Z Profiles!CITE052, '+swath+' scan, BB-relative, CONUS, V03C/D Match'
;PLOT_obj_array.title='2B-DPRGMI & Ku-Adj. GR Mean Z Profiles!CV03C/D, '+swath+' scan, BB-relative, CONUS, ITE052 Match'

PLOT_obj_array.xrange=[20.,50.]
PLOT_obj_array.close
