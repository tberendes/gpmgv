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
;cd , '..'
GRIBPATH = GETENV("GRIB_DIR")
SNDPATH = GETENV("NC_DIR")
FILES4NC = GETENV("CONTROLFILE")
restore, 'get_model_sounding.sav'
get_model_sounding, FILES4NC, GRIBPATH, SNDPATH, $
  rot='/data/gpmgv/GRIB/static/nam_218_20120323_0600_006.sav' ;, /VERBOSE
