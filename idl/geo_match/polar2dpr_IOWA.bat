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

FILES4NC = '/data/tmp/DPR_files_sites4geoMatch.2ADPR.NS.V03B.140620.iowa.txt'
;restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
.compile polar2dpr.pro
polar2dpr, FILES4NC, 150, SCORES=0, GPM_ROOT='/data/gpmgv/orbit_subset', $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=1, $
           NC_DIR='/data/gpmgv/netcdf/geo_match', $
           DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.',nc_name_add='150km'
