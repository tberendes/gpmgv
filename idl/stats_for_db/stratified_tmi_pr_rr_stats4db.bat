.reset

@zr_coeff_kma.inc
zrab=zrabs3

name_add='V7_ZRx2'
pctAbvThresh=50
;ncsitepath='/data/gpmgv/netcdf/geo_match/GRtoPR.R'
FILEMATCHES='/data/gpmgv/tmp/TMI2PRv7.txt'
cappi_height=1.5
verbose=1
s2ku=1

stratified_tmi_pr_rr_stats4db, PCT_ABV_THRESH=pctAbvThresh,  $
                               S2KU=s2ku,                    $
                               NAME_ADD=name_add,            $
                               NCSITEPATH=ncsitepath,        $
                               FILEMATCHES=filematches,      $
                               OUTPATH=outpath,              $
                               BBWIDTH=bbwidth,              $
                               ZRAB=zrab,                    $
                               CAPPI_HEIGHT=cappi_height,    $
                               STRICT=strict,                $
                               GZADJUST=gzadjust,            $
                               VERBOSE=verbose
