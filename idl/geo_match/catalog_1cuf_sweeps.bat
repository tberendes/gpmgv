;+
; Copyright © 2012, United States Government as represented by the
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
FILES4ELEV = GETENV("CONTROLFILE")
.compile catalog_1cuf_sweeps.pro
catalog_1cuf_sweeps, FILES4ELEV, '/data/gpmgv/gv_radar/finalQC_in' ;, /LIST
