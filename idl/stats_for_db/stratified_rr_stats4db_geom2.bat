@zr_coeff_kma.inc
zrab=zrabs3

name_add='ZR3_GRZadjByPR'
pctAbvThresh=90
ncsitepath='/data/netcdf/geo_match/GRtoPR.R'
cappi_height=1.5
gzadjust='/data/tmp/KMA_SITE_BIAS_COEFF.sav'
;verbose=1

stratified_rr_stats4db_geom2, PCT_ABV_THRESH=pctAbvThresh,  $
                              GV_CONVECTIVE=gv_convective,  $
                              GV_STRATIFORM=gv_stratiform,  $
                              S2KU=s2ku,                    $
                              NAME_ADD=name_add,            $
                              NCSITEPATH=ncsitepath,        $
                              OUTPATH=outpath,              $
                              BBWIDTH=bbwidth,              $
                              ZRAB=zrab,                    $
                              CAPPI_HEIGHT=cappi_height,    $
                              STRICT=strict,                $
                              GRZADJUST=gzadjust,           $
                              VERBOSE=verbose
