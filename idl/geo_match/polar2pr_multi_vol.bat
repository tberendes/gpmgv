;+
; Copyright © 2010, United States Government as represented by the
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
polar2pr_multi_vol, FILES4NC, 100, DIRGV='/data/gv_radar/MELB_UF', NC_NAME_ADD='AllGRpoints'
