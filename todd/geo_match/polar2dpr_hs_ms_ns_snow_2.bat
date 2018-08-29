;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dpr_hs_ms_ns_snow_2.bat
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
print, 'IDL_PRO_DIR ', PRO_DIR
cd, PRO_DIR
;cd , '..'

ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
help, ITE_OR_OPERATIONAL, gpm_root
exit

FILES4NC = GETENV("CONTROLFILE")
;restore, '/home/tberendes/git/gpmgv/todd/geo_match/polar2dpr_hs_ms_ns_snow.sav'
.compile polar2dpr_hs_ms_ns_snow.pro
polar2dpr_hs_ms_ns_snow, FILES4NC, 100, SCORES=0, GPM_ROOT=gpm_root, $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
           NC_DIR='/data/gpmgv/netcdf/grmatch', DIR2ADPR='/.', DIR_BLOCK='/data/gpmgv/blockage', $
           DPR_DBZ_MIN=15.0, DBZ_MIN=15.0, NC_NAME_ADD='snow'
 ;          DPR_DBZ_MIN=15.0, DBZ_MIN=15.0, NC_NAME_ADD='15dbzGRDPR_newDm'
 
resolve_all
save, /routines, file='/home/tberendes/git/gpmgv/todd/geo_match/polar2dpr_hs_ms_ns_snow.sav'
