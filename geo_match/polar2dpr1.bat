;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dpr.bat
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
;cd , '..'

FILES4NC = GETENV("CONTROLFILE")
restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
;.compile polar2dpr.pro
polar2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT='/data/emdata/orbit_subset', $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
           NC_DIR='/data/gpmgv/netcdf/geo_match', DECLUTTER=1, $
           DPR_DBZ_MIN=15.0, DBZ_MIN=15.0, NC_NAME_ADD='15dBZ', $
           DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.', DIR_BLOCK='/data/gpmgv/blockage'
