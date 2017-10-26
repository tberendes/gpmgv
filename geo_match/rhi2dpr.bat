;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
;cd , '..'

FILES4NC = GETENV("CONTROLFILE")
;restore, '/home/morris/swdev/idl/dev/geo_match/rhi2dpr.sav'
.compile rhi2dpr.pro
rhi2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT='/data/gpmgv/orbit_subset', DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_RHIS=0, NC_DIR='/data/gpmgv/netcdf/geo_match', DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.' , NC_NAME_ADD='00_20'
