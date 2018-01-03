;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
cd , '..'
;DATESTAMP = GETENV("RUNDATE")
FILES4NC = GETENV("CONTROLFILE")
;.compile polar2pr.pro
restore, '/home/morris/swdev/idl/dev/geo_match/polar2pr.sav'
polar2pr, FILES4NC, 100, /SCORES, PR_ROOT='/data/gpmgv/orbit_subset', $
          DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
          NC_DIR='/data/gpmgv/netcdf/geo_match', $
          DIR1C='/.', DIR23='/.', DIR2A='/.', DIR2B='/.'
