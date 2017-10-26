.reset

ELEV2SHOW=1
;NCPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V03B/1_2/2014'
;PRPATH='/data/gpmgv/orbit_subset/GPM'
NCPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V4ITE/1_2/2015'
PRPATH='/data/gpmgv/orbit_subset/GPM'
UFPATH='/data/gpmgv/gv_radar/finalQC_in'
NO_PROMPT=0
SITEfilter='NPOL_WA'
USE_DB=0
SHOW_ORIG=1
PCTABVTHRESH=0
BBBYRAY=0
PLOTBBSEP=0
BBWIDTH=0.5
HIDE_RNTYPE=1
CREF=1
VERBOSE=0
DPR_OR_PR='DPR'
LABEL_BY_RAYNUM=1
RHI_MODE=1
RECALL_NCPATH=0
ALT_BB_HGT=4.3
PAUSE=1.0
;GIF_PATH=''
;AZIMUTH=330.0

dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, NO_PROMPT=no_prompt, NCPATH=ncpath,   PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, SHOW_ORIG=show_orig, PCT_ABV_THRESH=pctAbvThresh, BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, RHI_MODE=rhi_mode, VERBOSE=verbose, RECALL_NCPATH=recall_ncpath ;, AZIMUTH=azimuth

