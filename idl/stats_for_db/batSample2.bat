.reset
nameAdd='2AKu_V4match'
SCATTERPLOT=1
;bins4scat=2
;convbelowscat=0
PLOT_OBJ_ARRAY=1
swath='NS'
altfield='DM'
BATCH_SAVE=0
VERSION2MATCH='V04A'
;et_range=[10.0,19.99999]
;DPR_Z_ADJUST = -1.5
;GR_Z_ADJUST='/tmp/somefile'

z_rain_dsd_profile_scatter_all, INSTRUMENT='DPR', $
   GV_CONVECTIVE=0, GV_STRATIFORM=0, ALTFIELD=altfield, $
   PCT_ABV_THRESH=100, S2KU=1, NAME_ADD=nameAdd, FIRST_ORBIT=first_orbit, $
   NCSITEPATH='/data/gpmgv/netcdf/geo_match/GPM/2AKu/NS/ITE109/1_21', $
   FILEP='GRtoDPR.KAMX*.1_21.15dbzGRDPR_newDm.nc.gz', VERSION2MATCH=version2match, $
   SITELIST=sitelist, EXCLUDE=exclude, OUTPATH='/tmp', BB_RELATIVE=0, $
   MAX_BLOCK=10, ET_RANGE=et_range, DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
   SCATTERPLOT=scatterplot, BINS4SCAT=bins4scat, BATCH_SAVE=BATCH_SAVE, PLOT_OBJ_ARRAY=plot_obj_array

