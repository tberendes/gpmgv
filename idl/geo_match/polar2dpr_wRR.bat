;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

;PRO_DIR = getenv("IDL_PRO_DIR")
;cd, PRO_DIR
;cd , '..'
;DATESTAMP = GETENV("RUNDATE")
FILES4NC = '/data/gpmgv/tmp/DPR_files_sites4geoMatch.110331.txt'
.compile polar2dpr.pro
polar2dpr, FILES4NC, 100, /SCORES, GPM_ROOT='/data/gpmgv/GPMtest', $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', /PLOT_PPIS, $
           NC_DIR='/tmp', DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.'
