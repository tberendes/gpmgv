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
;DATESTAMP = GETENV("RUNDATE")
FILES4NC = GETENV("CONTROLFILE")
restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
FILES4NC = '/data/gpmgv/tmp/DPR_files_sites4geoMatch.140701.txt'
t0=systime(1)
polar2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT='/data/gpmgv/orbit_subset', $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
           NC_DIR='/data/gpmgv/netcdf/geo_match_GPMtest', DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.', $
           NC_NAME='tryNEW1'
t1=systime(1)
print, "Elapsed: ", t1-t0
