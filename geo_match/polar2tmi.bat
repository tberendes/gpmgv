;+
; Copyright © 2011, United States Government as represented by the
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
;.compile polar2tmi2b.pro
polar2tmi, FILES4NC, 100, PR_ROOT='/data/gpmgv/prsubsets', DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/data/gpmgv/netcdf/geo_match', /plot_ppis
